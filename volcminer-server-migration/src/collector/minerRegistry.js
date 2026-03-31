import fs from "node:fs";
import path from "node:path";
import { HttpError } from "../utils/http.js";
import { logger } from "../utils/logger.js";

function readJsonFile(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function resolveMinerIp(miner) {
  return (
    miner?.overview?.network?.ip ??
    miner?.rawStatus?.ipaddress ??
    miner?.targetIp ??
    null
  );
}

function extractBaseUrlIp(baseUrl) {
  if (typeof baseUrl !== "string" || !baseUrl.trim()) {
    return null;
  }

  try {
    return new URL(baseUrl).hostname || null;
  } catch {
    return null;
  }
}

function resolveConfigMinerIp(miner) {
  return extractBaseUrlIp(miner?.baseUrl ?? null);
}

function dedupeStrings(values) {
  return [...new Set(values.map((value) => String(value)).filter(Boolean))];
}

function sanitizeTags(values = []) {
  return dedupeStrings(values).filter((tag) => !["scan", "global", "known-list"].includes(tag));
}

export class MinerRegistry {
  constructor(configPath, knownMinersPath = null) {
    this.configPath = configPath;
    this.knownMinersPath = knownMinersPath ?? configPath;
  }

  loadMiners() {
    return this.loadAllMiners().filter((miner) => miner.enabled !== false);
  }

  loadAllMiners() {
    if (!fs.existsSync(this.knownMinersPath)) {
      if (fs.existsSync(this.configPath)) {
        return this.loadConfigMiners();
      }
      throw new HttpError(500, `Miners config not found: ${this.knownMinersPath}`);
    }

    const parsed = readJsonFile(this.knownMinersPath);
    if (!Array.isArray(parsed.miners)) {
      throw new HttpError(500, "Miners config must contain a miners array");
    }

    return parsed.miners.map((miner) => this.normalizeMiner(miner));
  }

  loadRawConfig() {
    if (!fs.existsSync(this.knownMinersPath)) {
      if (fs.existsSync(this.configPath)) {
        return this.loadConfigRawConfig();
      }
      throw new HttpError(500, `Miners config not found: ${this.knownMinersPath}`);
    }

    const parsed = readJsonFile(this.knownMinersPath);
    if (!Array.isArray(parsed.miners)) {
      throw new HttpError(500, "Miners config must contain a miners array");
    }

    return parsed;
  }

  saveRawConfig(config) {
    fs.mkdirSync(path.dirname(this.knownMinersPath), { recursive: true });
    fs.writeFileSync(this.knownMinersPath, JSON.stringify(config, null, 2), "utf8");
  }

  listKnownMiners() {
    return this.loadAllMiners().map((miner) => {
      const ip = resolveConfigMinerIp(miner);
      return {
        id: miner.id,
        name: miner.name,
        ip,
        segment: ip ? String(ip).split(".").slice(0, 3).join(".") : "unknown",
        enabled: miner.enabled !== false
      };
    });
  }

  loadConfigMiners() {
    const parsed = readJsonFile(this.configPath);
    if (!Array.isArray(parsed.miners)) {
      throw new HttpError(500, "Miners config must contain a miners array");
    }

    return parsed.miners.map((miner) => this.normalizeMiner(miner));
  }

  loadConfigRawConfig() {
    const parsed = readJsonFile(this.configPath);
    if (!Array.isArray(parsed.miners)) {
      throw new HttpError(500, "Miners config must contain a miners array");
    }

    return parsed;
  }

  deleteKnownMiner(identifier) {
    const normalizedIdentifier = String(identifier ?? "").trim();
    if (!normalizedIdentifier) {
      throw new HttpError(400, "Known miner id is required");
    }

    const currentConfig = this.loadRawConfig();
    const currentMiners = Array.isArray(currentConfig.miners) ? [...currentConfig.miners] : [];
    const targetIndex = currentMiners.findIndex((miner) => {
      const ip = resolveConfigMinerIp(miner);
      return String(miner?.id ?? "") === normalizedIdentifier || ip === normalizedIdentifier;
    });

    if (targetIndex === -1) {
      throw new HttpError(404, "Known miner not found");
    }

    const removedMiner = this.normalizeMiner(currentMiners[targetIndex]);
    currentMiners.splice(targetIndex, 1);
    this.saveRawConfig({
      ...currentConfig,
      miners: currentMiners
    });

    return {
      id: removedMiner.id,
      name: removedMiner.name,
      ip: resolveConfigMinerIp(removedMiner),
      totalCount: currentMiners.length
    };
  }

  mergeDiscoveredMiners(discoveredMiners, defaults = {}) {
    const currentConfig = this.loadRawConfig();
    const currentMiners = Array.isArray(currentConfig.miners) ? currentConfig.miners : [];
    const normalizedCurrent = currentMiners.map((miner) => this.normalizeMiner(miner));
    const existingByIp = new Map();

    for (let index = 0; index < normalizedCurrent.length; index += 1) {
      const ip = extractBaseUrlIp(normalizedCurrent[index].baseUrl);
      if (ip) {
        existingByIp.set(ip, { index, miner: currentMiners[index], normalized: normalizedCurrent[index] });
      }
    }

    const template =
      normalizedCurrent.find((miner) => miner.source === "volcminer-http") ??
      this.normalizeMiner({
        id: "miner-template-default",
        name: "VolcMiner",
        source: "volcminer-http",
        profile: "volcminer-webui",
        enabled: true,
        site: "scan",
        tags: [],
        baseUrl: "http://127.0.0.1",
        timeoutMs: Number(defaults.timeoutSeconds ?? 5) * 1000,
        auth: {
          type: "digest",
          username: defaults.username ?? "root",
          password: defaults.password ?? "ltc@dog"
        },
        endpoints: {
          status: "/cgi-bin/get_miner_statusV1.cgi",
          overview: "/cgi-bin/get_system_infoV1.cgi",
          monitor: "/cgi-bin/monitor.cgi",
          kernelLog: "/cgi-bin/get_kernel_log.cgi",
          clearAutoTune: "/cgi-bin/clear_refine.cgi"
        },
        headers: {},
        responseMapping: defaults.responseMapping ?? {}
      });

    let addedCount = 0;

    for (const discoveredMiner of Array.isArray(discoveredMiners) ? discoveredMiners : []) {
      const ip = resolveMinerIp(discoveredMiner);
      if (!ip) {
        continue;
      }

      const existing = existingByIp.get(ip);
      if (existing) {
        currentMiners[existing.index] = {
          ...existing.miner,
          enabled: existing.miner.enabled !== false,
          baseUrl: `http://${ip}`
        };
        continue;
      }

      currentMiners.push(this.createKnownMinerEntry(discoveredMiner, template, defaults));
      addedCount += 1;
    }

    if (addedCount > 0) {
      this.saveRawConfig({
        ...currentConfig,
        miners: currentMiners
      });
      logger.info("Known miners merged from full scan", {
        addedCount,
        totalCount: currentMiners.length
      });
    }

    return {
      addedCount,
      totalCount: currentMiners.length
    };
  }

  buildMinersFromViews(views, defaults = {}) {
    const miners = [];
    let index = 1;

    for (const view of Array.isArray(views) ? views : []) {
      const subnetPrefix = String(view.subnetPrefix ?? "").trim();
      const startHost = Number(view.startHost ?? 1);
      const endHost = Number(view.endHost ?? startHost);
      if (!subnetPrefix || !Number.isFinite(startHost) || !Number.isFinite(endHost)) {
        continue;
      }

      for (let host = startHost; host <= endHost; host += 1) {
        const ip = `${subnetPrefix}.${host}`;
        miners.push(
          this.normalizeMiner({
            id: `scan-${subnetPrefix.replace(/\./g, "-")}-${String(index).padStart(4, "0")}`,
            name: `${view.label ?? subnetPrefix} ${host}`,
            source: "volcminer-http",
            profile: "volcminer-webui",
            enabled: true,
            site: view.site ?? "scan",
            tags: ["scan", view.mode ?? "global", subnetPrefix],
            baseUrl: `http://${ip}`,
            timeoutMs: Number(view.timeoutSeconds ?? defaults.timeoutSeconds ?? 5) * 1000,
            auth: {
              type: "digest",
              username: view.username ?? defaults.username ?? "root",
              password: view.password ?? defaults.password ?? "ltc@dog"
            },
            endpoints: {
              status: view.statusEndpoint ?? "/cgi-bin/get_miner_statusV1.cgi",
              overview: view.overviewEndpoint ?? "/cgi-bin/get_system_infoV1.cgi",
              monitor: view.monitorEndpoint ?? "/cgi-bin/monitor.cgi",
              kernelLog: view.kernelLogEndpoint ?? "/cgi-bin/get_kernel_log.cgi",
              clearAutoTune: view.clearAutoTuneEndpoint ?? "/cgi-bin/clear_refine.cgi"
            },
            headers: {},
            responseMapping: defaults.responseMapping
          })
        );
        index += 1;
      }
    }

    return miners;
  }

  normalizeMiner(miner) {
    if (!miner.id || !miner.name || !miner.source) {
      throw new HttpError(500, "Each miner must include id, name, and source");
    }

    return {
      id: String(miner.id),
      name: String(miner.name),
      source: String(miner.source),
      profile: miner.profile ?? "volcminer-webui",
      enabled: miner.enabled !== false,
      site: miner.site ?? null,
      tags: Array.isArray(miner.tags) ? miner.tags.map(String) : [],
      baseUrl: miner.baseUrl ?? null,
      mockFile: miner.mockFile
        ? path.resolve(path.dirname(this.configPath), "..", miner.mockFile)
        : null,
      timeoutMs: Number.isFinite(Number(miner.timeoutMs)) ? Number(miner.timeoutMs) : null,
      headers: miner.headers && typeof miner.headers === "object" ? miner.headers : {},
      auth:
        miner.auth && typeof miner.auth === "object"
          ? {
              type: miner.auth.type ?? "none",
              username: miner.auth.username ?? null,
              password: miner.auth.password ?? null
            }
          : { type: "none", username: null, password: null },
      responseMapping:
        miner.responseMapping && typeof miner.responseMapping === "object"
          ? miner.responseMapping
          : {},
      endpoints: {
        status: miner.endpoints?.status ?? "/cgi-bin/get_miner_statusV1.cgi",
        overview: miner.endpoints?.overview ?? "/cgi-bin/get_system_infoV1.cgi",
        monitor: miner.endpoints?.monitor ?? "/cgi-bin/monitor.cgi",
        kernelLog: miner.endpoints?.kernelLog ?? miner.kernelLogEndpoint ?? "/cgi-bin/get_kernel_log.cgi",
        clearAutoTune:
          miner.endpoints?.clearAutoTune ??
          miner.endpoints?.clearAdaptive ??
          miner.maintenance?.clearAutoTune ??
          miner.clearAutoTuneEndpoint ??
          "/cgi-bin/clear_refine.cgi"
      },
      maintenance:
        miner.maintenance && typeof miner.maintenance === "object"
          ? miner.maintenance
          : {}
    };
  }

  createKnownMinerEntry(discoveredMiner, template, defaults = {}) {
    const ip = resolveMinerIp(discoveredMiner);
    const hostname = String(discoveredMiner?.overview?.hostname ?? "").trim();
    const site =
      discoveredMiner?.site && discoveredMiner.site !== "scan"
        ? discoveredMiner.site
        : template.site ?? "scan";
    const segment = String(ip).split(".").slice(0, 3).join(".");
    const defaultTags = sanitizeTags([
      ...(Array.isArray(template.tags) ? template.tags : []),
      "auto-discovered",
      segment
    ]);

    return {
      id: `miner-known-${String(ip).replace(/\./g, "-")}`,
      name: hostname || `VolcMiner ${ip}`,
      source: "volcminer-http",
      profile: template.profile ?? "volcminer-webui",
      enabled: true,
      site,
      tags: defaultTags,
      baseUrl: `http://${ip}`,
      timeoutMs:
        template.timeoutMs ?? Number(defaults.timeoutSeconds ?? 5) * 1000,
      auth: {
        type: template.auth?.type ?? "digest",
        username: defaults.username ?? template.auth?.username ?? "root",
        password: defaults.password ?? template.auth?.password ?? "ltc@dog"
      },
      endpoints: {
        status: template.endpoints?.status ?? "/cgi-bin/get_miner_statusV1.cgi",
        overview: template.endpoints?.overview ?? "/cgi-bin/get_system_infoV1.cgi",
        monitor: template.endpoints?.monitor ?? "/cgi-bin/monitor.cgi",
        kernelLog: template.endpoints?.kernelLog ?? "/cgi-bin/get_kernel_log.cgi",
        clearAutoTune: template.endpoints?.clearAutoTune ?? "/cgi-bin/clear_refine.cgi"
      },
      headers: template.headers ?? {},
      responseMapping: defaults.responseMapping ?? template.responseMapping ?? {},
      maintenance: template.maintenance ?? {}
    };
  }
}
