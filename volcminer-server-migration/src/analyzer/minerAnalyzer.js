import { buildAbnormalDiagnosis } from "./abnormalDiagnosis.js";

function toNumber(value, fallback = 0) {
  if (typeof value === "string") {
    const normalized = value.replace(/,/g, "").trim();
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function extractTargetIp(baseUrl) {
  if (typeof baseUrl !== "string" || !baseUrl.trim()) {
    return null;
  }

  try {
    return new URL(baseUrl).hostname || null;
  } catch {
    return null;
  }
}

function escapeProblematicField(text, fieldName) {
  const fieldMarker = `"${fieldName}"`;
  const fieldIndex = text.indexOf(fieldMarker);
  if (fieldIndex === -1) {
    return text;
  }

  const colonIndex = text.indexOf(":", fieldIndex);
  const firstQuoteIndex = text.indexOf('"', colonIndex + 1);
  if (colonIndex === -1 || firstQuoteIndex === -1) {
    return text;
  }

  let closingQuoteIndex = -1;
  for (const token of [']",', '"]}', '"] ,', '"] }', '"]\n', '"]\r\n']) {
    const idx = text.indexOf(token, firstQuoteIndex + 1);
    if (idx !== -1 && (closingQuoteIndex === -1 || idx < closingQuoteIndex)) {
      closingQuoteIndex = idx + 1;
    }
  }

  if (closingQuoteIndex === -1) {
    return text;
  }

  const rawValue = text.slice(firstQuoteIndex + 1, closingQuoteIndex);
  const escapedValue = JSON.stringify(rawValue);
  return `${text.slice(0, colonIndex + 1)} ${escapedValue}${text.slice(closingQuoteIndex + 1)}`;
}

function normalizeLooseJson(text) {
  const withEscapedArrays = ["pool_dtls", "chains"].reduce(
    (current, fieldName) => escapeProblematicField(current, fieldName),
    String(text)
  );

  return withEscapedArrays
    .replace(/([{,]\s*)"([^"\\]+)"\s*:/g, '$1"$2":')
    .replace(/:\s*"((?:[^"\\]|\\.)*)"(?=\s*[,}])/g, ': "$1"');
}

function parseLooseObjectString(value, fallback) {
  if (value && typeof value === "object") {
    return value;
  }

  if (typeof value !== "string" || !value.trim()) {
    return fallback;
  }

  const trimmed = value.trim();
  if (!(trimmed.startsWith("{") || trimmed.startsWith("["))) {
    return fallback;
  }

  try {
    return JSON.parse(trimmed);
  } catch {
    try {
      return JSON.parse(normalizeLooseJson(trimmed));
    } catch {
      return fallback;
    }
  }
}

function parseElapsedSeconds(value) {
  if (typeof value === "number") {
    return value;
  }

  if (typeof value !== "string" || !value.trim()) {
    return 0;
  }

  let total = 0;
  const matches = value.matchAll(/(\d+)\s*([dhms])/gi);
  for (const match of matches) {
    const amount = Number(match[1]);
    const unit = match[2].toLowerCase();
    if (unit === "d") total += amount * 86400;
    if (unit === "h") total += amount * 3600;
    if (unit === "m") total += amount * 60;
    if (unit === "s") total += amount;
  }

  return total;
}

function parseMaybeJsonString(value, fallback) {
  if (Array.isArray(value) || (value && typeof value === "object")) {
    return value;
  }

  if (typeof value !== "string" || !value.trim()) {
    return fallback;
  }

  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function getLooseStringField(text, key, fallback = null) {
  if (typeof text !== "string") {
    return fallback;
  }

  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = text.match(new RegExp(`"${escapedKey}"\\s*:\\s*"([^"]*)"`, "i"));
  return match ? match[1] : fallback;
}

function extractLooseFans(text) {
  if (typeof text !== "string") {
    return [];
  }

  return Array.from(text.matchAll(/"(fan\d+)"\s*:\s*"([^"]*)"/gi)).map((match) => ({
    name: match[1],
    rpm: toNumber(match[2], 0)
  }));
}

function extractLooseBoards(text) {
  if (typeof text !== "string") {
    return [];
  }

  return Array.from(
    text.matchAll(
      /"index"\s*:\s*"(\d+)".*?"temp"\s*:\s*"([^"]*)".*?"chain_rate"\s*:\s*"([^"]*)".*?"freq"\s*:\s*"([^"]*)"/gsi
    )
  ).map((match) => ({
    board: toNumber(match[1], 0),
    temperatureC: toNumber(match[2], 0),
    hashrateRt: toNumber(match[3], 0),
    hashrateAvg: toNumber(match[3], 0),
    frequency: match[4] ?? null
  }));
}

function extractLoosePools(text) {
  if (typeof text !== "string") {
    return [];
  }

  return Array.from(
    text.matchAll(
      /"url"\s*:\s*"([^"]*)".*?"user"\s*:\s*"([^"]*)".*?"status"\s*:\s*"([^"]*)".*?"priority"\s*:\s*"([^"]*)".*?"accepted"\s*:\s*"([^"]*)".*?"rejected"\s*:\s*"([^"]*)"/gsi
    )
  ).map((match) => ({
    url: match[1] ?? null,
    worker: match[2] ?? null,
    status: match[3] ?? null,
    priority: toNumber(match[4], 0),
    accepted: toNumber(match[5], 0),
    rejected: toNumber(match[6], 0)
  }));
}

function extractFans(statusPayload, statusText = "") {
  if (Array.isArray(statusPayload.fans)) {
    return statusPayload.fans;
  }

  const fan = statusPayload.fan;
  if (!fan || typeof fan !== "object") {
    return extractLooseFans(statusText);
  }

  return Object.entries(fan).map(([name, rpm]) => ({
    name,
    rpm: toNumber(rpm)
  }));
}

function extractBoards(statusPayload, statusText = "") {
  if (Array.isArray(statusPayload.boards)) {
    return statusPayload.boards;
  }

  const chains = parseMaybeJsonString(statusPayload.chains, []);
  if (!Array.isArray(chains) || chains.length === 0) {
    return extractLooseBoards(statusText);
  }

  return chains.map((chain, index) => {
    const parsedBoard = toNumber(chain.index, 0);
    return ({
    board: parsedBoard > 0 ? parsedBoard : index + 1,
    temperatureC: toNumber(chain.temp, 0),
    hashrateRt: toNumber(chain.chain_rate, 0),
    hashrateAvg: toNumber(chain.chain_rate, 0),
    chipCount: toNumber(chain.chain_acn, 0),
    frequency: chain.freq ?? null,
    hardwareErrors: toNumber(chain.hw, 0),
    chainAcs: chain.chain_acs ?? null
  })});
}

function extractPools(statusPayload, statusText = "") {
  if (Array.isArray(statusPayload.pools)) {
    return statusPayload.pools;
  }

  const poolDetails = statusPayload.pools?.pool_dtls;
  const parsed = parseMaybeJsonString(poolDetails, []);
  if (!Array.isArray(parsed) || parsed.length === 0) {
    return extractLoosePools(statusText);
  }

  return parsed.map((pool) => ({
    url: pool.url ?? null,
    worker: pool.user ?? null,
    status: pool.status ?? null,
    priority: toNumber(pool.priority, 0),
    accepted: toNumber(pool.accepted, 0),
    rejected: toNumber(pool.rejected, 0)
  }));
}

function getByPath(source, key, fallback = null) {
  if (!source || typeof source !== "object") {
    return fallback;
  }

  if (!key) {
    return fallback;
  }

  if (Object.prototype.hasOwnProperty.call(source, key)) {
    return source[key];
  }

  const parts = String(key).split(".");
  let current = source;
  for (const part of parts) {
    if (current && typeof current === "object" && Object.prototype.hasOwnProperty.call(current, part)) {
      current = current[part];
    } else {
      return fallback;
    }
  }

  return current;
}

function maxTemperature(boards) {
  if (!Array.isArray(boards) || boards.length === 0) {
    return null;
  }

  return boards.reduce((max, board) => {
    const temp = toNumber(board.temperatureC, 0);
    return temp > max ? temp : max;
  }, 0);
}

function averageFanRpm(fans) {
  if (!Array.isArray(fans) || fans.length === 0) {
    return null;
  }

  const total = fans.reduce((sum, fan) => sum + toNumber(fan.rpm, 0), 0);
  return Math.round(total / fans.length);
}

function buildAlerts(miner, metrics, rules) {
  const alerts = [];
  const offlineAgeMs = metrics.lastSeenAt ? Date.now() - new Date(metrics.lastSeenAt).getTime() : Infinity;

  if (!metrics.online || offlineAgeMs > rules.alertOfflineAfterMs) {
    alerts.push({
      minerId: miner.id,
      severity: "critical",
      code: "OFFLINE",
      message: `${miner.name} is offline or stale`,
      value: offlineAgeMs
    });
  }

  if (
    metrics.hashrateAvg > 0 &&
    metrics.hashrateRt > 0 &&
    metrics.hashrateRt < metrics.hashrateAvg * rules.alertHashrateDropRatio
  ) {
    alerts.push({
      minerId: miner.id,
      severity: "warning",
      code: "HASHRATE_DROP",
      message: `${miner.name} realtime hashrate is below expected baseline`,
      value: metrics.hashrateRt
    });
  }

  if (metrics.maxTemperatureC !== null && metrics.maxTemperatureC >= rules.alertTemperatureC) {
    alerts.push({
      minerId: miner.id,
      severity: "critical",
      code: "HIGH_TEMP",
      message: `${miner.name} reached ${metrics.maxTemperatureC}C`,
      value: metrics.maxTemperatureC
    });
  }

  return alerts;
}

export class MinerAnalyzer {
  constructor(rules) {
    this.rules = rules;
  }

  analyzeMiner(miner, raw, status, history = []) {
    const statusRaw = raw?.status ?? {};
    const statusPayload = parseLooseObjectString(statusRaw, statusRaw ?? {});
    const statusText = typeof statusRaw === "string" ? statusRaw : "";
    const overview = parseLooseObjectString(raw?.overview, raw?.overview ?? {});
    const monitor = raw?.monitor ?? {};
    const overviewMap = miner.responseMapping?.overview ?? {};
    const online = status === "ok" && statusPayload.online !== false;
    const lastSeenAt = new Date().toISOString();
    const boards = extractBoards(statusPayload, statusText);
    const fans = extractFans(statusPayload, statusText);
    const pools = extractPools(statusPayload, statusText);

    const metrics = {
      online,
      hashrateRt: toNumber(
        statusPayload.hashrateRt ?? statusPayload.ghs5s ?? getLooseStringField(statusText, "ghs5s"),
        0
      ),
      hashrateAvg: toNumber(
        statusPayload.hashrateAvg ?? statusPayload.ghsav ?? getLooseStringField(statusText, "ghsav"),
        0
      ),
      accepted: toNumber(
        statusPayload.accepted ??
          statusPayload.pools?.total?.t_accepted ??
          getLooseStringField(statusText, "t_accepted"),
        0
      ),
      rejected: toNumber(
        statusPayload.rejected ??
          statusPayload.pools?.total?.t_rejected ??
          getLooseStringField(statusText, "t_rejected"),
        0
      ),
      hardwareErrors: toNumber(
        statusPayload.hardwareErrors ??
          statusPayload.pools?.hw?.h_hw ??
          getLooseStringField(statusText, "h_hw"),
        0
      ),
      uptimeSeconds: toNumber(
        statusPayload.uptimeSeconds,
        parseElapsedSeconds(statusPayload.elapsed ?? getLooseStringField(statusText, "elapsed"))
      ),
      maxTemperatureC: maxTemperature(boards),
      averageFanRpm: averageFanRpm(fans),
      poolCount: pools.length,
      boardCount: boards.length,
      lastSeenAt,
      power: toNumber(statusPayload.power ?? getLooseStringField(statusText, "power"), 0),
      voltage: toNumber(statusPayload.voltage ?? getLooseStringField(statusText, "voltage"), 0),
      current: toNumber(statusPayload.current ?? getLooseStringField(statusText, "current"), 0),
      ambientTemp: toNumber(
        statusPayload.ambient_temp ?? getLooseStringField(statusText, "ambient_temp"),
        0
      ),
      runningMode: statusPayload.running_mode ?? getLooseStringField(statusText, "running_mode"),
      chains: boards.map((board) => ({
        index: board.board,
        chain_rate: board.hashrateRt,
        temp: board.temperatureC,
        freq: board.frequency ?? "--",
        hw: board.hardwareErrors ?? 0,
        chain_acn: board.chipCount ?? 0,
        chain_acs: board.chainAcs ?? ""
      }))
    };

    const alerts = buildAlerts(miner, metrics, this.rules);
    const { diagnosis, abnormalGroup, abnormalType } = buildAbnormalDiagnosis({
      id: miner.id,
      name: miner.name,
      metrics,
      rawStatus: statusPayload,
      monitor: {
        text: monitor.text ?? null
      },
      kernelLog: {
        text: raw?.kernelLog?.text ?? null
      }
    }, history);

    return {
      id: miner.id,
      name: miner.name,
      site: miner.site,
      tags: miner.tags,
      source: miner.source,
      targetIp: extractTargetIp(miner.baseUrl),
      status,
      metrics,
      alerts,
      diagnosis,
      abnormalGroup,
      abnormalType,
      rawStatus: statusPayload,
      kernelLog: {
        text: raw?.kernelLog?.text ?? null
      },
      overview: {
        minerType: getByPath(overview, overviewMap.minerType ?? "minerType", overview.minertype ?? null),
        hostname: getByPath(overview, overviewMap.hostname ?? "hostname", null),
        systemMode: getByPath(overview, overviewMap.systemMode ?? "systemMode", overview.system_mode ?? null),
        hardwareVersion: getByPath(
          overview,
          overviewMap.hardwareVersion ?? "hardwareVersion",
          overview.bb_hwv ?? null
        ),
        kernelVersion: getByPath(
          overview,
          overviewMap.kernelVersion ?? "kernelVersion",
          overview.system_kernel_version ?? null
        ),
        filesystemVersion: getByPath(
          overview,
          overviewMap.filesystemVersion ?? "filesystemVersion",
          overview.system_filesystem_version ?? null
        ),
        cgminerVersion: getByPath(
          overview,
          overviewMap.cgminerVersion ?? "cgminerVersion",
          overview.cgminer_version ?? null
        ),
        loadAverage: getByPath(
          overview,
          overviewMap.loadAverage ?? "loadAverage",
          overview.loadaverage ?? null
        ),
        memory: {
          totalKb: toNumber(
            getByPath(overview, overviewMap.memTotalKb ?? "memTotalKb", overview.mem_total ?? 0)
          ),
          usedKb: toNumber(
            getByPath(overview, overviewMap.memUsedKb ?? "memUsedKb", overview.mem_used ?? 0)
          ),
          freeKb: toNumber(
            getByPath(overview, overviewMap.memFreeKb ?? "memFreeKb", overview.mem_free ?? 0)
          ),
          cachedKb: toNumber(
            getByPath(overview, overviewMap.memCachedKb ?? "memCachedKb", overview.mem_cached ?? 0)
          ),
          buffersKb: toNumber(
            getByPath(overview, overviewMap.memBuffersKb ?? "memBuffersKb", overview.mem_buffers ?? 0)
          )
        },
        network: {
          type: getByPath(
            overview,
            overviewMap.networkType ?? "network.type",
            overview.nettype ?? overview.network?.type ?? null
          ),
          ip: getByPath(
            overview,
            overviewMap.ip ?? "network.ip",
            overview.ipaddress ?? overview.network?.ip ?? null
          ),
          netmask: getByPath(
            overview,
            overviewMap.netmask ?? "network.netmask",
            overview.netmask ?? overview.network?.netmask ?? null
          )
        },
        machineTime: getByPath(
          overview,
          overviewMap.machineTime ?? "machineTime",
          overview.machine_time ?? null
        )
      },
      monitor: {
        text: monitor.text ?? null
      }
    };
  }

  buildDashboard(miners, alerts) {
    let onlineCount = 0;
    let unresponsiveCount = 0;
    let offlineCount = 0;
    let pendingRetireCount = 0;
    let repeatedOfflineCount = 0;

    for (const miner of miners) {
      if (miner.lifecycle?.isRepeatedOffline === true) {
        repeatedOfflineCount += 1;
      }
      const lifecycleState = String(miner.lifecycle?.state ?? "").trim();
      if (lifecycleState === "pending-retire") {
        pendingRetireCount += 1;
        continue;
      }
      if (lifecycleState === "unresponsive") {
        unresponsiveCount += 1;
        continue;
      }
      if (lifecycleState === "offline") {
        offlineCount += 1;
        continue;
      }
      if (miner.metrics.online) {
        onlineCount += 1;
        continue;
      }
      if (miner.status === "error") {
        unresponsiveCount += 1;
        continue;
      }
      offlineCount += 1;
    }

    const totalHashrateRt = miners.reduce((sum, miner) => sum + miner.metrics.hashrateRt, 0);
    const totalHashrateAvg = miners.reduce((sum, miner) => sum + miner.metrics.hashrateAvg, 0);
    const highestTemperature = miners.reduce((max, miner) => {
      const temp = miner.metrics.maxTemperatureC ?? 0;
      return temp > max ? temp : max;
    }, 0);
    const diagnosisCount = miners.reduce(
      (sum, miner) => sum + (miner.diagnosis ? 1 : 0),
      0
    );

    return {
      generatedAt: new Date().toISOString(),
      minerCount: miners.length,
      onlineCount,
      unresponsiveCount,
      offlineCount,
      pendingRetireCount,
      repeatedOfflineCount,
      totalHashrateRt,
      totalHashrateAvg,
      highestTemperature,
      alertCount: alerts.length,
      diagnosisCount
    };
  }

  mergeHistory(previousHistory, miners) {
    const history = { ...previousHistory };

    for (const miner of miners) {
      const points = Array.isArray(history[miner.id]) ? history[miner.id] : [];
      points.push({
        at: miner.metrics.lastSeenAt,
        hashrateRt: miner.metrics.hashrateRt,
        hashrateAvg: miner.metrics.hashrateAvg,
        maxTemperatureC: miner.metrics.maxTemperatureC,
        online: miner.metrics.online,
        diagnosisCode: miner.diagnosis?.code ?? null,
        diagnosisCategory: miner.diagnosis?.category ?? null,
        diagnosisDetectedAt: miner.diagnosis?.detectedAt ?? miner.metrics.lastSeenAt
      });

      history[miner.id] = points.slice(-120);
    }

    return history;
  }
}
