import fs from "node:fs";
import { runCommand } from "../utils/process.js";
import {
  createNonMinerError,
  looksLikeVolcMinerPayload
} from "../utils/minerFingerprint.js";

function normalizeQuotedJson(text) {
  return String(text)
    .replace(/([{,]\s*)"([^"\\]+)"\s*:/g, '$1"$2":')
    .replace(/:\s*"((?:[^"\\]|\\.)*)"(?=\s*[,}])/g, ': "$1"');
}

function extractLooseEnvelopeData(text) {
  const markerIndex = text.indexOf('"data"');
  if (markerIndex === -1) {
    return null;
  }

  const colonIndex = text.indexOf(":", markerIndex);
  if (colonIndex === -1) {
    return null;
  }

  const firstQuoteIndex = text.indexOf('"', colonIndex + 1);
  const lastQuoteIndex = text.lastIndexOf('"');
  if (firstQuoteIndex === -1 || lastQuoteIndex <= firstQuoteIndex) {
    return null;
  }

  return text.slice(firstQuoteIndex + 1, lastQuoteIndex);
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

  const endPatterns = ['"] ,', '"] ,', '"]}', '"] , "', '"] , "', '"] , "', ']",', '"] }', '"]\n', '"]\r\n'];
  let closingQuoteIndex = -1;
  let closingTokenLength = 0;

  for (const token of [']",', '"]}', '"] ,', '"] }', '"]\n', '"]\r\n']) {
    const idx = text.indexOf(token, firstQuoteIndex + 1);
    if (idx !== -1 && (closingQuoteIndex === -1 || idx < closingQuoteIndex)) {
      closingQuoteIndex = idx + 1;
      closingTokenLength = token.length;
    }
  }

  if (closingQuoteIndex === -1) {
    return text;
  }

  const rawValue = text.slice(firstQuoteIndex + 1, closingQuoteIndex);
  const escapedValue = JSON.stringify(rawValue);
  return `${text.slice(0, colonIndex + 1)} ${escapedValue}${text.slice(closingQuoteIndex + 1)}`;
}

function parseEmbeddedJson(value) {
  if (typeof value !== "string") {
    return value;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return value;
  }

  if (!(trimmed.startsWith("{") || trimmed.startsWith("["))) {
    return value;
  }

  try {
    return JSON.parse(trimmed);
  } catch {
    try {
      return JSON.parse(normalizeQuotedJson(trimmed));
    } catch {
      const escapedArrays = ["pool_dtls", "chains"].reduce(
        (current, fieldName) => escapeProblematicField(current, fieldName),
        trimmed
      );

      try {
        return JSON.parse(normalizeQuotedJson(escapedArrays));
      } catch {
        return value;
      }
    }
  }
}

function unwrapEnvelope(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return payload;
  }

  if (!Object.prototype.hasOwnProperty.call(payload, "data")) {
    return payload;
  }

  return parseEmbeddedJson(payload.data);
}

function parseJsonPayload(payload) {
  try {
    return unwrapEnvelope(JSON.parse(payload));
  } catch {
    const extracted = extractLooseEnvelopeData(payload);
    if (extracted !== null) {
      return parseEmbeddedJson(extracted);
    }

    throw new Error("Unable to parse miner payload");
  }
}

function normalizeActionConfig(config, fallbackMethod = "POST") {
  if (!config) {
    return null;
  }

  if (typeof config === "string") {
    return {
      path: config,
      method: fallbackMethod,
      payload: null
    };
  }

  if (typeof config === "object") {
    return {
      path: config.path ?? config.endpoint ?? null,
      method: String(config.method ?? fallbackMethod).toUpperCase(),
      payload: config.payload ?? null
    };
  }

  return null;
}

function toNumber(value, fallback = 0) {
  if (typeof value === "string") {
    const normalized = value.replace(/,/g, "").trim();
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
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

function extractStatusText(statusPayload) {
  if (typeof statusPayload === "string") {
    return statusPayload;
  }

  try {
    return JSON.stringify(statusPayload);
  } catch {
    return "";
  }
}

function getLooseStringField(text, key, fallback = null) {
  if (typeof text !== "string") {
    return fallback;
  }

  const escapedKey = String(key).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = text.match(new RegExp(`"${escapedKey}"\\s*:\\s*"([^"]*)"`, "i"));
  return match ? match[1] : fallback;
}

function extractBoards(statusPayload) {
  const text = extractStatusText(statusPayload);
  const chains = parseMaybeJsonString(
    statusPayload?.chains ?? getLooseStringField(text, "chains", "[]"),
    []
  );
  if (!Array.isArray(chains)) {
    return [];
  }

  return chains.map((chain) => ({
    index: toNumber(chain?.index, 0),
    rate: toNumber(chain?.chain_rate ?? chain?.rate, 0),
    temperatureC: toNumber(chain?.temp, 0)
  }));
}

function extractFans(statusPayload) {
  const fan = statusPayload?.fan;
  if (fan && typeof fan === "object") {
    return Object.values(fan).map((rpm) => toNumber(rpm, 0));
  }

  const text = extractStatusText(statusPayload);
  return Array.from(text.matchAll(/"fan\d+"\s*:\s*"([^"]*)"/gi)).map((match) =>
    toNumber(match[1], 0)
  );
}

function shouldFetchKernelLog(statusPayload, monitorText = "") {
  const text = extractStatusText(statusPayload);
  const currentMh = toNumber(
    statusPayload?.hashrateRt ?? statusPayload?.ghs5s ?? getLooseStringField(text, "ghs5s"),
    0
  );
  const averageMh = toNumber(
    statusPayload?.hashrateAvg ?? statusPayload?.ghsav ?? getLooseStringField(text, "ghsav"),
    0
  );
  const boards = extractBoards(statusPayload);
  const fans = extractFans(statusPayload);
  const maxTemperature = boards.reduce(
    (max, board) => (board.temperatureC > max ? board.temperatureC : max),
    0
  );
  const averageFanRpm =
    fans.length === 0 ? 0 : fans.reduce((sum, rpm) => sum + rpm, 0) / fans.length;
  const combinedText = `${text}\n${String(monitorText ?? "")}`.toLowerCase();

  if (
    currentMh <= 0 ||
    averageMh <= 0 ||
    (currentMh > 0 && currentMh < 15000) ||
    boards.some((board) => board.rate <= 0) ||
    averageFanRpm <= 0 ||
    maxTemperature >= 85
  ) {
    return true;
  }

  return [
    "errormsg",
    "authen start",
    "full speed due to temperature",
    "wrong asic",
    "chain break",
    "chain num error",
    "fan err",
    "fan error",
    "over max temp"
  ].some((pattern) => combinedText.includes(pattern));
}

export class VolcminerClient {
  constructor(defaultTimeoutMs) {
    this.defaultTimeoutMs = defaultTimeoutMs;
  }

  async collect(miner) {
    const signal = miner.abortSignal;
    if (miner.source === "mock") {
      return this.collectMock(miner);
    }

    if (miner.source === "volcminer-http") {
      return this.collectHttp(miner, signal);
    }

    throw new Error(`Unsupported miner source: ${miner.source}`);
  }

  async collectMock(miner) {
    if (!miner.mockFile || !fs.existsSync(miner.mockFile)) {
      throw new Error(`Mock file not found for ${miner.id}`);
    }

    return JSON.parse(fs.readFileSync(miner.mockFile, "utf8"));
  }

  async collectHttp(miner, signal) {
    if (!miner.baseUrl) {
      throw new Error(`Missing baseUrl for ${miner.id}`);
    }

    const status = await this.fetchJson(miner, miner.endpoints.status, signal);
    const overview = await this.fetchJson(miner, miner.endpoints.overview, signal);

    if (!looksLikeVolcMinerPayload(overview, status)) {
      throw createNonMinerError(`Target ${miner.baseUrl} did not return VolcMiner signatures`, {
        baseUrl: miner.baseUrl
      });
    }

    let monitor;
    try {
      monitor = await this.fetchText(miner, miner.endpoints.monitor, signal);
    } catch (error) {
      monitor = String(error?.message ?? "Monitor endpoint failed");
    }

    let kernelLog = null;
    if (miner.endpoints?.kernelLog && shouldFetchKernelLog(status, monitor)) {
      try {
        kernelLog = await this.fetchText(miner, miner.endpoints.kernelLog, signal);
      } catch (error) {
        kernelLog = String(error?.message ?? "Kernel log endpoint failed");
      }
    }

    return {
      status,
      overview,
      monitor: {
        text: monitor
      },
      kernelLog: {
        text: kernelLog
      }
    };
  }

  async clearAutoTune(miner, signal) {
    const action = normalizeActionConfig(
      miner?.maintenance?.clearAutoTune ?? miner?.endpoints?.clearAutoTune,
      "POST"
    );

    if (!action?.path) {
      const error = new Error(`Clear auto tune endpoint not configured for ${miner?.id ?? "unknown"}`);
      error.code = "UNSUPPORTED_ACTION";
      throw error;
    }

    return this.sendAction(miner, action, signal);
  }

  async fetchJson(miner, endpoint, signal) {
    const payload = await this.fetchPayload(miner, endpoint, "json", signal);
    return parseJsonPayload(payload);
  }

  async fetchText(miner, endpoint, signal) {
    return this.fetchPayload(miner, endpoint, "text", signal);
  }

  async fetchPayload(miner, endpoint, responseType, signal) {
    if (miner.auth?.type === "digest") {
      return this.fetchWithDigest(miner, endpoint, signal);
    }

    const controller = new AbortController();
    const timeoutMs = miner.timeoutMs ?? this.defaultTimeoutMs;
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const abortHandler = () => controller.abort();

    try {
      if (signal) {
        if (signal.aborted) {
          const error = new Error("Command aborted");
          error.code = "ABORT_ERR";
          throw error;
        }
        signal.addEventListener("abort", abortHandler, { once: true });
      }

      const url = new URL(endpoint, miner.baseUrl).toString();
      const headers = { ...miner.headers };

      if (miner.auth?.type === "basic" && miner.auth.username) {
        const token = Buffer.from(`${miner.auth.username}:${miner.auth.password ?? ""}`).toString("base64");
        headers.Authorization = `Basic ${token}`;
      }

      const response = await fetch(url, {
        method: "GET",
        headers,
        signal: controller.signal
      });

      if (!response.ok) {
        if ([401, 403, 404].includes(response.status)) {
          throw createNonMinerError(`HTTP ${response.status} when requesting ${url}`, {
            status: response.status,
            url
          });
        }
        throw new Error(`HTTP ${response.status} when requesting ${url}`);
      }

      return responseType === "json" ? response.text() : response.text();
    } finally {
      clearTimeout(timeout);
      if (signal) {
        signal.removeEventListener("abort", abortHandler);
      }
    }
  }

  async sendAction(miner, action, signal) {
    if (miner.auth?.type === "digest") {
      return this.sendDigestAction(miner, action, signal);
    }

    const controller = new AbortController();
    const timeoutMs = miner.timeoutMs ?? this.defaultTimeoutMs;
    const timeout = setTimeout(() => controller.abort(), timeoutMs);
    const abortHandler = () => controller.abort();

    try {
      if (signal) {
        if (signal.aborted) {
          const error = new Error("Command aborted");
          error.code = "ABORT_ERR";
          throw error;
        }
        signal.addEventListener("abort", abortHandler, { once: true });
      }

      const url = new URL(action.path, miner.baseUrl).toString();
      const headers = { ...miner.headers };

      if (miner.auth?.type === "basic" && miner.auth.username) {
        const token = Buffer.from(`${miner.auth.username}:${miner.auth.password ?? ""}`).toString("base64");
        headers.Authorization = `Basic ${token}`;
      }

      let body;
      if (action.payload !== null && action.payload !== undefined) {
        if (typeof action.payload === "string") {
          body = action.payload;
        } else {
          body = JSON.stringify(action.payload);
          headers["Content-Type"] = "application/json";
        }
      } else if (String(action.method ?? "GET").toUpperCase() !== "GET") {
        body = "";
      }

      const response = await fetch(url, {
        method: action.method,
        headers,
        body,
        signal: controller.signal
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status} when requesting ${url}`);
      }

      return response.text();
    } finally {
      clearTimeout(timeout);
      if (signal) {
        signal.removeEventListener("abort", abortHandler);
      }
    }
  }

  async fetchWithDigest(miner, endpoint, signal) {
    const url = new URL(endpoint, miner.baseUrl).toString();
    const timeoutMs = miner.timeoutMs ?? this.defaultTimeoutMs;
    const args = [
      "--digest",
      "-u",
      `${miner.auth.username ?? ""}:${miner.auth.password ?? ""}`,
      "--silent",
      "--show-error",
      "--fail",
      "--max-time",
      String(Math.max(1, Math.ceil(timeoutMs / 1000))),
      url
    ];

    for (const [key, value] of Object.entries(miner.headers ?? {})) {
      args.push("-H", `${key}: ${value}`);
    }

    try {
      const { stdout } = await runCommand("curl", args, { timeoutMs, signal });
      return stdout;
    } catch (error) {
      const details = String(error?.message ?? "");
      if (/401|403|404/.test(details)) {
        throw createNonMinerError(`Digest endpoint rejected target ${url}`, {
          url,
          error: details
        });
      }
      throw error;
    }
  }

  async sendDigestAction(miner, action, signal) {
    const url = new URL(action.path, miner.baseUrl).toString();
    const timeoutMs = miner.timeoutMs ?? this.defaultTimeoutMs;
    const args = [
      "--digest",
      "-u",
      `${miner.auth.username ?? ""}:${miner.auth.password ?? ""}`,
      "--silent",
      "--show-error",
      "--fail",
      "--max-time",
      String(Math.max(1, Math.ceil(timeoutMs / 1000))),
      "-X",
      action.method,
      url
    ];

    if (action.payload !== null && action.payload !== undefined) {
      if (typeof action.payload === "string") {
        args.push("-d", action.payload);
      } else {
        args.push("-H", "Content-Type: application/json", "-d", JSON.stringify(action.payload));
      }
    } else if (String(action.method ?? "GET").toUpperCase() !== "GET") {
      args.push("-d", "");
    }

    for (const [key, value] of Object.entries(miner.headers ?? {})) {
      args.push("-H", `${key}: ${value}`);
    }

    const { stdout } = await runCommand("curl", args, { timeoutMs, signal });
    return stdout;
  }
}
