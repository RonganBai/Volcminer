import fs from "node:fs";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import { looksLikeVolcMinerPayload } from "../src/utils/minerFingerprint.js";

const execFileAsync = promisify(execFile);
const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const subnetPrefix = process.argv[2] ?? "172.100.1";
const startHost = Number(process.argv[3] ?? "1");
const endHost = Number(process.argv[4] ?? "255");
const username = process.argv[5] ?? "root";
const password = process.argv[6] ?? "ltc@dog";
const concurrency = Math.max(1, Number(process.argv[7] ?? "8"));
const timeoutSeconds = Math.max(2, Number(process.argv[8] ?? "5"));

const csvOutputPath = path.join(projectRoot, "config", "miners-discovered.csv");
const jsonOutputPath = path.join(projectRoot, "config", "miners-discovered.generated.json");

function csvEscape(value) {
  const text = String(value ?? "");
  if (/[",\n]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
}

function toNumber(value, fallback = 0) {
  if (typeof value === "string") {
    const parsed = Number(value.replace(/,/g, "").trim());
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeLooseJson(text) {
  return String(text)
    .replace(/([{,]\s*)"([^"\\]+)"\s*:/g, '$1"$2":')
    .replace(/:\s*"((?:[^"\\]|\\.)*)"(?=\s*[,}])/g, ': "$1"');
}

function extractLooseEnvelopeData(text) {
  const markerIndex = text.indexOf('"data"');
  if (markerIndex === -1) return null;
  const colonIndex = text.indexOf(":", markerIndex);
  const firstQuoteIndex = text.indexOf('"', colonIndex + 1);
  const lastQuoteIndex = text.lastIndexOf('"');
  if (colonIndex === -1 || firstQuoteIndex === -1 || lastQuoteIndex <= firstQuoteIndex) {
    return null;
  }
  return text.slice(firstQuoteIndex + 1, lastQuoteIndex);
}

function escapeProblematicField(text, fieldName) {
  const fieldMarker = `"${fieldName}"`;
  const fieldIndex = text.indexOf(fieldMarker);
  if (fieldIndex === -1) return text;
  const colonIndex = text.indexOf(":", fieldIndex);
  const firstQuoteIndex = text.indexOf('"', colonIndex + 1);
  if (colonIndex === -1 || firstQuoteIndex === -1) return text;

  let closingQuoteIndex = -1;
  for (const token of [']",', '"]}', '"] ,', '"] }', '"]\n', '"]\r\n']) {
    const idx = text.indexOf(token, firstQuoteIndex + 1);
    if (idx !== -1 && (closingQuoteIndex === -1 || idx < closingQuoteIndex)) {
      closingQuoteIndex = idx + 1;
    }
  }

  if (closingQuoteIndex === -1) return text;
  const rawValue = text.slice(firstQuoteIndex + 1, closingQuoteIndex);
  return `${text.slice(0, colonIndex + 1)} ${JSON.stringify(rawValue)}${text.slice(closingQuoteIndex + 1)}`;
}

function parseEmbeddedJson(value) {
  if (typeof value !== "string") return value;
  const trimmed = value.trim();
  if (!trimmed.startsWith("{")) return value;
  try {
    return JSON.parse(trimmed);
  } catch {
    try {
      return JSON.parse(normalizeLooseJson(trimmed));
    } catch {
      const escaped = ["pool_dtls", "chains"].reduce(
        (current, fieldName) => escapeProblematicField(current, fieldName),
        trimmed
      );
      try {
        return JSON.parse(normalizeLooseJson(escaped));
      } catch {
        return value;
      }
    }
  }
}

function parsePayload(payload) {
  try {
    const parsed = JSON.parse(payload);
    if (parsed && typeof parsed === "object" && "data" in parsed) {
      return parseEmbeddedJson(parsed.data);
    }
    return parsed;
  } catch {
    const extracted = extractLooseEnvelopeData(payload);
    if (extracted !== null) {
      return parseEmbeddedJson(extracted);
    }
    throw new Error("Unable to parse miner response");
  }
}

async function curlDigest(url) {
  const args = [
    "--digest",
    "-u",
    `${username}:${password}`,
    "--silent",
    "--show-error",
    "--fail",
    "--max-time",
    String(timeoutSeconds),
    url
  ];
  const { stdout } = await execFileAsync("curl", args, {
    windowsHide: true,
    timeout: (timeoutSeconds + 1) * 1000,
    maxBuffer: 4 * 1024 * 1024
  });
  return stdout;
}

function buildMinerJson(discovered, index) {
  return {
    id: `miner-gray-${String(index + 1).padStart(3, "0")}`,
    name: discovered.hostname || `${discovered.minerType || "VolcMiner"} ${discovered.ip}`,
    source: "volcminer-http",
    profile: "volcminer-webui",
    enabled: true,
    site: "gray",
    tags: ["gray", "auto-discovered", "batch-01"],
    baseUrl: `http://${discovered.ip}`,
    timeoutMs: 8000,
    auth: {
      type: "digest",
      username,
      password
    },
    endpoints: {
      status: "/cgi-bin/get_miner_statusV1.cgi",
      overview: "/cgi-bin/get_system_infoV1.cgi",
      monitor: "/cgi-bin/monitor.cgi"
    },
    headers: {},
    responseMapping: {
      overview: {
        minerType: "minertype",
        hostname: "hostname",
        systemMode: "system_mode",
        hardwareVersion: "bb_hwv",
        kernelVersion: "system_kernel_version",
        filesystemVersion: "system_filesystem_version",
        cgminerVersion: "cgminer_version",
        loadAverage: "loadaverage",
        machineTime: "machine_time",
        networkType: "nettype",
        ip: "ipaddress",
        netmask: "netmask",
        memTotalKb: "mem_total",
        memUsedKb: "mem_used",
        memFreeKb: "mem_free",
        memCachedKb: "mem_cached",
        memBuffersKb: "mem_buffers"
      }
    }
  };
}

async function probeHost(ip) {
  const baseUrl = `http://${ip}`;
  const overviewUrl = `${baseUrl}/cgi-bin/get_system_infoV1.cgi`;
  const statusUrl = `${baseUrl}/cgi-bin/get_miner_statusV1.cgi`;
  try {
    const [overviewRaw, statusRaw] = await Promise.all([
      curlDigest(overviewUrl),
      curlDigest(statusUrl)
    ]);
    const overview = parsePayload(overviewRaw);
    const status = parsePayload(statusRaw);
    const isMiner = looksLikeVolcMinerPayload(overview, status);
    return {
      ip,
      reachable: true,
      isMiner,
      minerType: overview?.minertype ?? "",
      hostname: overview?.hostname ?? "",
      macaddr: overview?.macaddr ?? "",
      nettype: overview?.nettype ?? "",
      ipaddress: overview?.ipaddress ?? ip,
      systemMode: overview?.system_mode ?? "",
      hardwareVersion: overview?.bb_hwv ?? "",
      filesystemVersion: overview?.system_filesystem_version ?? "",
      kernelVersion: overview?.system_kernel_version ?? "",
      cgminerVersion: overview?.cgminer_version ?? "",
      hashrateRt: toNumber(status?.ghs5s, 0),
      hashrateAvg: toNumber(status?.ghsav, 0),
      power: toNumber(status?.power, 0),
      ambientTemp: toNumber(status?.ambient_temp, 0),
      error: isMiner ? "" : "Target did not match VolcMiner fingerprint"
    };
  } catch (error) {
    return {
      ip,
      reachable: false,
      isMiner: false,
      error: error.message
    };
  }
}

async function runWithConcurrency(items, limit, worker) {
  const queue = [...items];
  const results = [];

  async function consume() {
    while (queue.length > 0) {
      const item = queue.shift();
      results.push(await worker(item));
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, consume));
  return results;
}

const hosts = [];
for (let host = startHost; host <= endHost; host += 1) {
  hosts.push(`${subnetPrefix}.${host}`);
}

console.log(`Scanning ${hosts.length} hosts in ${subnetPrefix}.${startHost}-${endHost} with concurrency ${concurrency}`);
const discovered = await runWithConcurrency(hosts, concurrency, probeHost);
const online = discovered.filter((item) => item.reachable && item.isMiner);
const nonMiners = discovered.filter((item) => item.reachable && !item.isMiner);
const offline = discovered.filter((item) => !item.reachable);

const csvHeader = [
  "ip",
  "reachable",
  "minerType",
  "hostname",
  "macaddr",
  "nettype",
  "ipaddress",
  "systemMode",
  "hardwareVersion",
  "filesystemVersion",
  "kernelVersion",
  "cgminerVersion",
  "hashrateRt",
  "hashrateAvg",
  "power",
  "ambientTemp",
  "error"
];

const csvLines = [
  csvHeader.join(","),
  ...discovered.map((row) =>
    csvHeader.map((header) => csvEscape(row[header] ?? "")).join(",")
  )
];

fs.writeFileSync(csvOutputPath, `${csvLines.join("\n")}\n`, "utf8");
fs.writeFileSync(
  jsonOutputPath,
  `${JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      scan: {
        subnetPrefix,
        startHost,
        endHost,
        username,
        concurrency,
      timeoutSeconds
      },
      minerCount: online.length,
      nonMinerCount: nonMiners.length,
      offlineCount: offline.length,
      miners: online.map(buildMinerJson)
    },
    null,
    2
  )}\n`,
  "utf8"
);

console.log(`Reachable miners: ${online.length}`);
console.log(`Filtered non-miner devices: ${nonMiners.length}`);
console.log(`Unreachable hosts: ${offline.length}`);
console.log(`CSV: ${csvOutputPath}`);
console.log(`JSON: ${jsonOutputPath}`);
