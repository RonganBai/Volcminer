import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  const contents = fs.readFileSync(filePath, "utf8");
  const entries = {};

  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    const value = trimmed.slice(separatorIndex + 1).trim();
    entries[key] = value;
  }

  return entries;
}

function toBoolean(value, fallback) {
  if (value === undefined) {
    return fallback;
  }

  return ["1", "true", "yes", "on"].includes(String(value).toLowerCase());
}

function toNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

const envPath = path.join(projectRoot, ".env");
const fileEnv = parseEnvFile(envPath);

function env(name, fallback) {
  return process.env[name] ?? fileEnv[name] ?? fallback;
}

export const config = {
  projectRoot,
  host: env("HOST", "0.0.0.0"),
  port: toNumber(env("PORT", "18080"), 18080),
  dataDir: path.resolve(projectRoot, env("DATA_DIR", "./data")),
  minersConfigPath: path.resolve(
    projectRoot,
    env("MINERS_CONFIG", "./config/miners.json")
  ),
  knownMinersPath: path.resolve(
    projectRoot,
    env("KNOWN_MINERS_FILE", "./data/known-miners.json")
  ),
  webDistPath: path.resolve(
    projectRoot,
    env("WEB_DIST_DIR", "./public/web")
  ),
  pollIntervalMs: toNumber(env("POLL_INTERVAL_MS", "900000"), 900000),
  schedulerTickMs: toNumber(env("SCHEDULER_TICK_MS", "30000"), 30000),
  fetchTimeoutMs: toNumber(env("FETCH_TIMEOUT_MS", "5000"), 5000),
  enableBackgroundPolling: toBoolean(env("ENABLE_BACKGROUND_POLLING", "true"), true),
  scanConcurrency: toNumber(env("SCAN_CONCURRENCY", "300"), 300),
  schedulerInitialDelayMs: toNumber(env("SCHEDULER_INITIAL_DELAY_MS", "120000"), 120000),
  skipIfHashSentryActive: toBoolean(env("SKIP_IF_HASHSENTRY_ACTIVE", "true"), true),
  alertTemperatureC: toNumber(env("ALERT_TEMPERATURE_C", "80"), 80),
  alertHashrateDropRatio: toNumber(env("ALERT_HASHRATE_DROP_RATIO", "0.85"), 0.85),
  alertOfflineAfterMs: toNumber(env("ALERT_OFFLINE_AFTER_MS", "60000"), 60000),
  pendingRetireAfterMs: toNumber(env("PENDING_RETIRE_AFTER_MS", "86400000"), 86400000),
  repeatedOfflineWindowMs: toNumber(env("REPEATED_OFFLINE_WINDOW_MS", "86400000"), 86400000),
  repeatedOfflineThreshold: toNumber(env("REPEATED_OFFLINE_THRESHOLD", "3"), 3),
  cpuLoadGuardRatio: toNumber(env("CPU_LOAD_GUARD_RATIO", "1.8"), 1.8),
  minAvailableMemoryMb: toNumber(env("MIN_AVAILABLE_MEMORY_MB", "2048"), 2048),
  maxHashSentryScanProcesses: toNumber(env("MAX_HASHSENTRY_SCAN_PROCESSES", "64"), 64)
};
