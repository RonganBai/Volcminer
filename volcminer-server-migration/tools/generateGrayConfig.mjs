import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const inputPath = process.argv[2]
  ? path.resolve(process.cwd(), process.argv[2])
  : path.join(projectRoot, "config", "miners-gray-template.csv");
const outputPath = process.argv[3]
  ? path.resolve(process.cwd(), process.argv[3])
  : path.join(projectRoot, "config", "miners-gray.generated.json");

function parseCsv(contents) {
  const rows = [];
  let current = "";
  let row = [];
  let inQuotes = false;

  for (let index = 0; index < contents.length; index += 1) {
    const char = contents[index];
    const next = contents[index + 1];

    if (char === '"') {
      if (inQuotes && next === '"') {
        current += '"';
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char === "," && !inQuotes) {
      row.push(current);
      current = "";
      continue;
    }

    if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") {
        index += 1;
      }
      row.push(current);
      current = "";
      if (row.some((cell) => cell.trim() !== "")) {
        rows.push(row);
      }
      row = [];
      continue;
    }

    current += char;
  }

  if (current !== "" || row.length > 0) {
    row.push(current);
    if (row.some((cell) => cell.trim() !== "")) {
      rows.push(row);
    }
  }

  return rows;
}

function parseBoolean(value, fallback = true) {
  if (value == null || value === "") {
    return fallback;
  }

  return ["1", "true", "yes", "on"].includes(String(value).trim().toLowerCase());
}

function parseTags(value) {
  return String(value ?? "")
    .split(/[|,]/)
    .map((tag) => tag.trim())
    .filter(Boolean);
}

function buildMiner(row, index) {
  const id = row.id?.trim() || `miner-gray-${String(index + 1).padStart(3, "0")}`;
  const name = row.name?.trim() || id;
  const ip = row.ip?.trim();

  if (!ip) {
    throw new Error(`Row ${index + 2} is missing ip`);
  }

  return {
    id,
    name,
    source: "volcminer-http",
    profile: "volcminer-webui",
    enabled: parseBoolean(row.enabled, true),
    site: row.site?.trim() || "gray",
    tags: parseTags(row.tags || "gray|real"),
    baseUrl: /^https?:\/\//i.test(ip) ? ip : `http://${ip}`,
    timeoutMs: Number(row.timeoutMs) || 8000,
    auth: {
      type: row.authType?.trim() || "digest",
      username: row.username?.trim() || "root",
      password: row.password?.trim() || ""
    },
    endpoints: {
      status: row.statusEndpoint?.trim() || "/cgi-bin/get_miner_statusV1.cgi",
      overview: row.overviewEndpoint?.trim() || "/cgi-bin/get_system_infoV1.cgi",
      monitor: row.monitorEndpoint?.trim() || "/cgi-bin/monitor.cgi"
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

const csv = fs.readFileSync(inputPath, "utf8");
const [headerRow, ...valueRows] = parseCsv(csv);

if (!headerRow || headerRow.length === 0) {
  throw new Error(`CSV header missing: ${inputPath}`);
}

const headers = headerRow.map((value) => value.trim());
const miners = valueRows.map((values, index) => {
  const row = Object.fromEntries(headers.map((header, columnIndex) => [header, values[columnIndex] ?? ""]));
  return buildMiner(row, index);
});

const output = {
  generatedAt: new Date().toISOString(),
  minerCount: miners.length,
  miners
};

fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`, "utf8");
console.log(`Generated ${miners.length} miners to ${outputPath}`);
