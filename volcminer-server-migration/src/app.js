import fs from "node:fs";
import path from "node:path";
import { HttpError, jsonResponse, notFound, parseJsonBody, sendError } from "./utils/http.js";

const ACTIVE_TASK_STATES = new Set(["queued", "running", "waiting", "waiting-stop", "delayed"]);
const DEFAULT_SCHEDULED_CYCLE_LENGTH = 4;
const GLOBAL_SCAN_CYCLE_INDEX = DEFAULT_SCHEDULED_CYCLE_LENGTH - 1;
const WEB_APP_CACHE_CONTROL = "no-cache";
const STATIC_ASSET_CACHE_CONTROL = "public, max-age=86400";
const SUMMARY_CACHE_TTL_MS = 2500;
const STATIC_MIME_TYPES = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "application/javascript; charset=utf-8"],
  [".mjs", "application/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".jpg", "image/jpeg"],
  [".jpeg", "image/jpeg"],
  [".gif", "image/gif"],
  [".ico", "image/x-icon"],
  [".svg", "image/svg+xml"],
  [".webp", "image/webp"],
  [".wasm", "application/wasm"],
  [".map", "application/json; charset=utf-8"],
  [".txt", "text/plain; charset=utf-8"],
  [".woff", "font/woff"],
  [".woff2", "font/woff2"]
]);

const responseCache = new Map();

function readCachedResponse(key) {
  const entry = responseCache.get(key);
  if (!entry) {
    return null;
  }
  if (entry.expiresAt <= Date.now()) {
    responseCache.delete(key);
    return null;
  }
  return entry.value;
}

function writeCachedResponse(key, value, ttlMs = SUMMARY_CACHE_TTL_MS) {
  responseCache.set(key, {
    expiresAt: Date.now() + Math.max(0, Number(ttlMs) || 0),
    value
  });
  return value;
}

function getCachedResponse(key, producer, ttlMs = SUMMARY_CACHE_TTL_MS) {
  const cached = readCachedResponse(key);
  if (cached != null) {
    return cached;
  }
  const value = producer();
  return writeCachedResponse(key, value, ttlMs);
}

function invalidateResponseCache() {
  responseCache.clear();
}

function segmentFromIp(ip) {
  const parts = String(ip ?? "").split(".");
  return parts.length >= 3 ? parts.slice(0, 3).join(".") : "unknown";
}

function resolveMinerIp(miner) {
  return (
    miner?.overview?.network?.ip ??
    miner?.rawStatus?.ipaddress ??
    miner?.targetIp ??
    null
  );
}

function minerSummary(miner) {
  const resolvedIp = resolveMinerIp(miner);
  return {
    id: miner.id,
    name: miner.name,
    ip: resolvedIp,
    baseUrl: miner.baseUrl ?? null,
    site: miner.site,
    tags: miner.tags,
    status: miner.status,
    lifecycle: miner.lifecycle ?? null,
    metrics: miner.metrics,
    diagnosis: miner.diagnosis ?? null,
    abnormalGroup: miner.abnormalGroup ?? null,
    abnormalType: miner.abnormalType ?? null,
    isRepeatedOffline: miner.lifecycle?.isRepeatedOffline === true,
    repeatedOfflineMarkedAt: miner.lifecycle?.repeatedOfflineMarkedAt ?? null,
    alertCount: miner.alerts.length,
    segment: segmentFromIp(resolvedIp)
  };
}

function buildMinerCounts(miners) {
  let minerCount = 0;
  let onlineCount = 0;
  let unresponsiveCount = 0;
  let offlineCount = 0;
  let pendingRetireCount = 0;
  let diagnosisCount = 0;
  let repeatedOfflineCount = 0;

  for (const miner of Array.isArray(miners) ? miners : []) {
    minerCount += 1;
    const lifecycleState = String(miner?.lifecycle?.state ?? "").trim();
    const status = String(miner?.status ?? "").trim();
    if (miner?.lifecycle?.isRepeatedOffline === true) {
      repeatedOfflineCount += 1;
    }
    if (lifecycleState === "pending-retire") {
      pendingRetireCount += 1;
      continue;
    }
    if (lifecycleState === "unresponsive" || status === "unresponsive") {
      unresponsiveCount += 1;
      continue;
    }
    if (lifecycleState === "offline" || status === "offline") {
      offlineCount += 1;
      continue;
    }
    if (miner?.metrics?.online === true || status === "online") {
      onlineCount += 1;
    }
    if (miner?.diagnosis != null) {
      diagnosisCount += 1;
    }
  }

  return {
    minerCount,
    onlineCount,
    unresponsiveCount,
    offlineCount,
    pendingRetireCount,
    diagnosisCount,
    repeatedOfflineCount
  };
}

function pickLatestAcceptedSnapshotSummary(history) {
  const entries = Array.isArray(history) ? history : [];
  return (
    entries.find((entry) => entry?.accepted !== false && Number(entry.minerCount ?? 0) > 0) ??
    entries.find((entry) => entry?.accepted !== false) ??
    null
  );
}

function resolveSummaryCounts(snapshot, history) {
  const current = buildMinerCounts(snapshot.miners);
  const latestAccepted = pickLatestAcceptedSnapshotSummary(history);
  const currentLooksEmpty = !Array.isArray(snapshot.miners) || snapshot.miners.length === 0;

  if (!currentLooksEmpty) {
    return current;
  }

  if (!latestAccepted) {
    return current;
  }

  return {
    minerCount: Number(latestAccepted.minerCount ?? current.minerCount ?? 0),
    onlineCount: Number(latestAccepted.onlineCount ?? current.onlineCount ?? 0),
    unresponsiveCount: Number(
      latestAccepted.unresponsiveCount ?? current.unresponsiveCount ?? 0
    ),
    offlineCount: Number(latestAccepted.offlineCount ?? current.offlineCount ?? 0),
    pendingRetireCount: Number(
      latestAccepted.pendingRetireCount ?? current.pendingRetireCount ?? 0
    ),
    diagnosisCount: Number(latestAccepted.diagnosisCount ?? current.diagnosisCount ?? 0),
    repeatedOfflineCount: Number(
      latestAccepted.repeatedOfflineCount ?? current.repeatedOfflineCount ?? 0
    )
  };
}

function buildSegmentResults(snapshot) {
  const groups = new Map();

  for (const miner of snapshot.miners) {
    const segment = segmentFromIp(resolveMinerIp(miner));
    const current = groups.get(segment) ?? {
      segment,
      minerCount: 0,
      onlineCount: 0,
      offlineCount: 0,
      alertCount: 0,
      totalHashrate: 0,
      lastScanFinishedAt: snapshot.scheduler?.lastScanFinishedAt ?? snapshot.generatedAt
    };

    current.minerCount += 1;
    current.onlineCount += miner.metrics.online ? 1 : 0;
    current.offlineCount += miner.metrics.online ? 0 : 1;
    current.alertCount += miner.alerts.length;
    current.totalHashrate += Number(miner.metrics.hashrateRt ?? 0);
    groups.set(segment, current);
  }

  return [...groups.values()].sort((left, right) => left.segment.localeCompare(right.segment));
}

function buildMinerDetails(snapshot, miner) {
  const resolvedIp = resolveMinerIp(miner);
  return {
    id: miner.id,
    name: miner.name,
    ip: resolvedIp,
    baseUrl: miner.baseUrl ?? null,
    segment: segmentFromIp(resolvedIp),
    site: miner.site,
    tags: miner.tags,
    status: miner.status,
    lifecycle: miner.lifecycle ?? null,
    metrics: miner.metrics,
    diagnosis: miner.diagnosis ?? null,
    abnormalGroup: miner.abnormalGroup ?? null,
    abnormalType: miner.abnormalType ?? null,
    isRepeatedOffline: miner.lifecycle?.isRepeatedOffline === true,
    repeatedOfflineMarkedAt: miner.lifecycle?.repeatedOfflineMarkedAt ?? null,
    alertCount: miner.alerts.length,
    rawStatus: miner.rawStatus,
    chains: Array.isArray(miner.metrics?.chains) ? miner.metrics.chains : [],
    alerts: miner.alerts,
    error: miner.error ?? null,
    overview: miner.overview,
    monitor: miner.monitor,
    history: snapshot.history[miner.id] ?? []
  };
}

function findKnownMiner(registry, identifier) {
  const normalizedIdentifier = String(identifier ?? "").trim();
  if (!normalizedIdentifier) {
    return null;
  }

  return registry
    .loadMiners()
    .find((miner) => String(miner.id) === normalizedIdentifier || resolveConfigMinerIp(miner) === normalizedIdentifier) ?? null;
}

function resolveConfigMinerIp(miner) {
  try {
    return miner?.baseUrl ? new URL(miner.baseUrl).hostname ?? null : null;
  } catch {
    return null;
  }
}

function uniqueStrings(values) {
  return [...new Set((Array.isArray(values) ? values : []).map((value) => String(value ?? "").trim()).filter(Boolean))];
}

function buildBatchActionMessage(actionLabel, succeeded, failed) {
  if (failed.length === 0) {
    return `${actionLabel} completed for ${succeeded.length} miner(s).`;
  }

  if (succeeded.length === 0) {
    return `${actionLabel} failed for ${failed.length} miner(s).`;
  }

  return `${actionLabel} completed for ${succeeded.length} miner(s); ${failed.length} failed.`;
}

function getContentType(filePath) {
  const extension = filePath.slice(filePath.lastIndexOf(".")).toLowerCase();
  return STATIC_MIME_TYPES.get(extension) ?? "application/octet-stream";
}

function isWithinRoot(root, candidate) {
  const normalizedRoot = root.endsWith(path.sep) ? root : `${root}${path.sep}`;
  return candidate === root || candidate.startsWith(normalizedRoot);
}

function resolveWebFilePath(webRoot, pathname) {
  const decodedPath = decodeURIComponent(pathname || "/");
  const relativePath = decodedPath.replace(/^\/+/, "");
  const normalizedRelative = path.normalize(relativePath);
  const candidate = path.resolve(webRoot, normalizedRelative);
  if (!isWithinRoot(webRoot, candidate)) {
    return null;
  }
  return candidate;
}

async function serveWebAsset(res, filePath, cacheControl) {
  const data = await fs.promises.readFile(filePath);
  res.writeHead(200, {
    "Content-Type": getContentType(filePath),
    "Content-Length": data.length,
    "Cache-Control": cacheControl
  });
  if (res.req?.method === "HEAD") {
    res.end();
    return;
  }
  res.end(data);
}

async function tryServeWebApp(req, res, pathname, config) {
  if (!["GET", "HEAD"].includes(req.method ?? "") || pathname.startsWith("/api/")) {
    return false;
  }

  const webRoot = config.webDistPath;
  const indexPath = path.join(webRoot, "index.html");
  if (!fs.existsSync(indexPath)) {
    return false;
  }

  const candidate = resolveWebFilePath(webRoot, pathname);
  if (!candidate) {
    return false;
  }

  const exists = fs.existsSync(candidate) && fs.statSync(candidate).isFile();
  if (exists) {
    await serveWebAsset(res, candidate, STATIC_ASSET_CACHE_CONTROL);
    return true;
  }

  const hasExtension = path.extname(pathname) !== "";
  if (!hasExtension || pathname === "/") {
    await serveWebAsset(res, indexPath, WEB_APP_CACHE_CONTROL);
    return true;
  }

  if (!exists && path.extname(pathname) === "") {
    await serveWebAsset(res, indexPath, WEB_APP_CACHE_CONTROL);
    return true;
  }

  return false;
}

async function runBatchWithConcurrency(items, limit, worker) {
  const normalizedLimit = Math.max(1, Number(limit) || 1);
  let index = 0;

  async function loop() {
    while (index < items.length) {
      const currentIndex = index;
      index += 1;
      await worker(items[currentIndex], currentIndex);
    }
  }

  const concurrency = Math.min(normalizedLimit, items.length);
  await Promise.all(Array.from({ length: concurrency }, () => loop()));
}

function applyClearAutoTuneBatchResult(snapshot, batchResults, at) {
  if (!Array.isArray(batchResults) || batchResults.length === 0) {
    return snapshot;
  }

  const runtimeById = { ...snapshot.minerRuntime };
  const miners = snapshot.miners.map((miner) => {
    const matchingResult = batchResults.find(
      (result) =>
        result.id === miner.id ||
        result.ip === resolveMinerIp(miner)
    );

    if (!matchingResult) {
      return miner;
    }

    const previousRuntime = runtimeById[miner.id] ?? miner.lifecycle ?? {};
    const nextRuntime = {
      ...previousRuntime,
      lastClearAutoTuneAt: at,
      lastClearAutoTuneOutcome: matchingResult.success ? "sent" : `failed: ${matchingResult.reason}`,
      updatedAt: at,
      history: [
        ...(Array.isArray(previousRuntime.history) ? previousRuntime.history : []),
        {
          at,
          state: previousRuntime.state ?? miner.lifecycle?.state ?? "online",
          type: "clear-auto-tune-manual",
          reason: matchingResult.success
            ? "Triggered by batch clear auto tune request"
            : `Batch clear auto tune failed: ${matchingResult.reason}`
        }
      ].slice(-40)
    };
    runtimeById[miner.id] = nextRuntime;
    return {
      ...miner,
      lifecycle: nextRuntime
    };
  });

  return {
    ...snapshot,
    miners,
    minerRuntime: runtimeById
  };
}

function isActiveTask(task) {
  return Boolean(task && ACTIVE_TASK_STATES.has(String(task.scanState ?? "")));
}

function buildLatestScheduledTask(snapshot) {
  const scheduler = snapshot.scheduler ?? {};
  const minerCount = Number(scheduler.minerCount ?? snapshot.miners?.length ?? 0);
  const completedCount =
    Number(scheduler.successCount ?? 0) +
    Number(scheduler.failedCount ?? 0);
  const progress = minerCount > 0
    ? Number(Math.min(100, (completedCount / minerCount) * 100).toFixed(1))
    : 0;

  return {
    source: "scheduler",
    scanState: scheduler.scanState ?? "idle",
    progress,
    matchedCount: Number(scheduler.successCount ?? 0),
    failedCount: Number(scheduler.failedCount ?? 0),
    nonMinerCount: 0,
    totalTargets: minerCount,
    lastScanStartedAt: scheduler.lastScanStartedAt ?? null,
    lastScanFinishedAt: scheduler.lastScanFinishedAt ?? null,
    nextScheduledAt: scheduler.nextScheduledAt ?? null,
    warningReason:
      scheduler.lastSnapshotWarningReason ??
      scheduler.lastDelayReason ??
      scheduler.lastSkipReason ??
      scheduler.lastError ??
      null,
    mode: scheduler.lastScheduledMode ?? null,
    delayedByHashSentry: scheduler.delayedByHashSentry ?? false,
    currentConcurrency: Number(scheduler.currentConcurrency ?? 0),
    queueLength: Number(scheduler.queueLength ?? 0),
    resourceSnapshot: scheduler.resourceSnapshot ?? null,
    resourceWarning: false,
    isManualTask: false,
    trigger: scheduler.trigger ?? null
  };
}

function buildSchedulerPayload(snapshot, currentTask, config) {
  const task = isActiveTask(currentTask) ? currentTask : null;
  const latestScheduledTask = buildLatestScheduledTask(snapshot);
  const nextGlobalScanAt = buildNextGlobalScanAt(snapshot, config.pollIntervalMs);
  return {
    generatedAt: snapshot.generatedAt,
    scanState: task?.scanState ?? latestScheduledTask.scanState ?? "idle",
    scanTaskId: task?.scanTaskId ?? null,
    progress: task?.progress ?? 0,
    matchedCount: task?.matchedCount ?? latestScheduledTask.matchedCount ?? 0,
    failedCount: task?.failedCount ?? latestScheduledTask.failedCount ?? 0,
    nonMinerCount: task?.nonMinerCount ?? 0,
    resourceWarning: task?.resourceWarning ?? false,
    warningReason: task?.warningReason ?? null,
    mode: task?.mode ?? null,
    selectedViewCount: task?.selectedViewCount ?? 0,
    selectedSegments: task?.selectedSegments ?? [],
    delayedByHashSentry:
      task?.delayedByHashSentry ?? latestScheduledTask.delayedByHashSentry ?? false,
    lastScanStartedAt:
      task?.lastScanStartedAt ?? latestScheduledTask.lastScanStartedAt ?? null,
    lastScanFinishedAt:
      task?.lastScanFinishedAt ?? latestScheduledTask.lastScanFinishedAt ?? null,
    totalTargets:
      task?.totalTargets ?? latestScheduledTask.totalTargets ?? snapshot.miners.length,
    queueLength: snapshot.scheduler?.queueLength ?? 0,
    currentConcurrency: snapshot.scheduler?.currentConcurrency ?? 0,
    minerCount: snapshot.scheduler?.minerCount ?? snapshot.miners.length,
    successCount: snapshot.scheduler?.successCount ?? 0,
    nextScheduledAt: snapshot.scheduler?.nextScheduledAt ?? null,
    lastDelayReason: task?.lastDelayReason ?? snapshot.scheduler?.lastDelayReason ?? null,
    lastSkipReason: snapshot.scheduler?.lastSkipReason ?? null,
    lastError: task?.lastError ?? snapshot.scheduler?.lastError ?? null,
    resourceSnapshot: task?.resourceSnapshot ?? snapshot.scheduler?.resourceSnapshot ?? null,
    currentTask: task,
    latestScheduledTask,
    nextGlobalScanAt,
    scheduledCycleIndex: snapshot.scheduler?.scheduledCycleIndex ?? null,
    scheduledCycleLength: snapshot.scheduler?.scheduledCycleLength ?? null,
    lastSuccessfulScanAt: snapshot.scheduler?.lastSuccessfulScanAt ?? null
  };
}

function buildSummaryPayload(snapshot, currentTask, config, history) {
  const latestScheduledTask = buildLatestScheduledTask(snapshot);
  const nextGlobalScanAt = buildNextGlobalScanAt(snapshot, config.pollIntervalMs);
  const counts = resolveSummaryCounts(snapshot, history);
  const latestAccepted = pickLatestAcceptedSnapshotSummary(history);
  const generatedAt =
    snapshot.generatedAt ??
    latestAccepted?.generatedAt ??
    snapshot.scheduler?.lastSuccessfulScanAt ??
    snapshot.scheduler?.lastScanFinishedAt ??
    null;

  return {
    generatedAt,
    nextGlobalScanAt,
    repeatedOfflineCount: counts.repeatedOfflineCount,
    currentTask: isActiveTask(currentTask) ? currentTask : null,
    latestScheduledTask,
    minerCount: counts.minerCount,
    onlineCount: counts.onlineCount,
    unresponsiveCount: counts.unresponsiveCount,
    offlineCount: counts.offlineCount,
    pendingRetireCount: counts.pendingRetireCount,
    diagnosisCount: counts.diagnosisCount
  };
}

function buildPersistedSnapshotPayload(snapshot, currentTask, registry, config) {
  const repeatedOfflineGroups = buildRepeatedOfflineGroups(snapshot);
  const schedulerPayload = buildSchedulerPayload(snapshot, currentTask, config);
  return {
    generatedAt: snapshot.generatedAt,
    snapshotSource: "persisted",
    miners: snapshot.miners.map(minerSummary),
    knownMiners: registry.listKnownMiners(),
    dashboard: {
      ...(snapshot.dashboard ?? {}),
      nextGlobalScanAt: schedulerPayload.nextGlobalScanAt,
      repeatedOfflineCount: repeatedOfflineGroups.reduce(
        (sum, item) => sum + Number(item.minerCount ?? 0),
        0
      ),
      currentTask: schedulerPayload.currentTask,
      latestScheduledTask: schedulerPayload.latestScheduledTask
    },
    scheduler: schedulerPayload
  };
}

function buildNextGlobalScanAt(snapshot, pollIntervalMs) {
  const scheduler = snapshot.scheduler ?? {};
  const cycleLength = Math.max(
    1,
    Number(scheduler.scheduledCycleLength ?? DEFAULT_SCHEDULED_CYCLE_LENGTH) ||
      DEFAULT_SCHEDULED_CYCLE_LENGTH
  );
  const cycleIndex = Math.max(
    0,
    Math.min(cycleLength - 1, Number(scheduler.scheduledCycleIndex ?? 0) || 0)
  );
  const globalIndex = Math.min(cycleLength - 1, GLOBAL_SCAN_CYCLE_INDEX);
  const nextScheduledAtMs = scheduler.nextScheduledAt
    ? new Date(scheduler.nextScheduledAt).getTime()
    : NaN;
  const nowMs = Date.now();
  const scanState = String(scheduler.scanState ?? "");
  const isCurrentCycleRunning = ["running", "queued", "waiting-stop", "delayed"].includes(scanState);

  if (isCurrentCycleRunning) {
    const stepsUntilGlobal =
      cycleIndex === globalIndex
        ? cycleLength
        : (globalIndex - cycleIndex + cycleLength) % cycleLength;
    return new Date(nowMs + stepsUntilGlobal * pollIntervalMs).toISOString();
  }

  if (!Number.isFinite(nextScheduledAtMs)) {
    return null;
  }

  const stepsUntilGlobal = (globalIndex - cycleIndex + cycleLength) % cycleLength;
  return new Date(nextScheduledAtMs + stepsUntilGlobal * pollIntervalMs).toISOString();
}

function buildRepeatedOfflineGroups(snapshot) {
  const groups = new Map();

  for (const miner of Array.isArray(snapshot.miners) ? snapshot.miners : []) {
    if (miner?.lifecycle?.isRepeatedOffline !== true) {
      continue;
    }

    const segment = segmentFromIp(resolveMinerIp(miner));
    const current = groups.get(segment) ?? {
      segment,
      minerCount: 0
    };
    current.minerCount += 1;
    groups.set(segment, current);
  }

  return [...groups.values()].sort((left, right) => left.segment.localeCompare(right.segment));
}

function buildRepeatedOfflineMiners(snapshot, segment) {
  return (Array.isArray(snapshot.miners) ? snapshot.miners : [])
    .filter((miner) => miner?.lifecycle?.isRepeatedOffline === true)
    .filter((miner) => segmentFromIp(resolveMinerIp(miner)) === segment)
    .map(minerSummary)
    .sort((left, right) => String(left.ip ?? "").localeCompare(String(right.ip ?? "")));
}

export function createApp({ repository, collectorService, scanTaskService, registry, config }) {
  return async function app(req, res) {
    try {
      const requestOrigin = req.headers.origin;
      if (requestOrigin) {
        res.setHeader("Access-Control-Allow-Origin", requestOrigin);
        res.setHeader("Vary", "Origin");
      } else {
        res.setHeader("Access-Control-Allow-Origin", "*");
      }
      res.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS");
      res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
      res.setHeader("Access-Control-Max-Age", "86400");

      if (req.method.toUpperCase() === "OPTIONS") {
        res.writeHead(204);
        res.end();
        return;
      }

      const url = new URL(req.url, "http://localhost");
      const pathname = url.pathname;
      const method = req.method.toUpperCase();

      if (method === "GET" && pathname === "/health") {
        const snapshot = repository.getSnapshot();
        jsonResponse(res, 200, {
          status: "ok",
          generatedAt: snapshot.generatedAt,
          minerCount: snapshot.miners.length,
          scheduler: snapshot.scheduler
        });
        return;
      }

      if (method === "GET" && pathname === "/api/system/health") {
        const snapshot = repository.getSnapshot();
        const manualTask = repository.getScanState().currentTask;
        jsonResponse(res, 200, {
          status: "ok",
          generatedAt: snapshot.generatedAt,
          scheduler: snapshot.scheduler,
          dashboard: snapshot.dashboard,
          currentTask: isActiveTask(manualTask) ? manualTask : null,
          latestScheduledTask: buildLatestScheduledTask(snapshot),
          nextGlobalScanAt: buildNextGlobalScanAt(snapshot, config.pollIntervalMs)
        });
        return;
      }

      if (method === "GET" && pathname === "/api/system/scheduler") {
        const snapshot = repository.getSnapshot();
        const manualTask = repository.getScanState().currentTask;
        jsonResponse(res, 200, buildSchedulerPayload(snapshot, manualTask, config));
        return;
      }

      if (method === "GET" && pathname === "/api/system/snapshot") {
        const snapshot = repository.getSnapshot();
        const manualTask = repository.getScanState().currentTask;
        const payload = getCachedResponse("system-snapshot", () =>
          buildPersistedSnapshotPayload(snapshot, manualTask, registry, config)
        );
        jsonResponse(res, 200, payload);
        return;
      }

      if (method === "GET" && pathname === "/api/miners") {
        const snapshot = repository.getSnapshot();
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          miners: snapshot.miners.map(minerSummary)
        });
        return;
      }

      if (method === "GET" && pathname === "/api/known-miners") {
        const snapshot = repository.getSnapshot();
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          miners: registry.listKnownMiners()
        });
        return;
      }

      if (method === "GET" && pathname === "/api/dashboard/summary") {
        const snapshot = repository.getSnapshot();
        const manualTask = repository.getScanState().currentTask;
        const history = repository.getSnapshotHistory();
        const payload = getCachedResponse("dashboard-summary", () =>
          buildSummaryPayload(snapshot, manualTask, config, history)
        );
        jsonResponse(res, 200, payload);
        return;
      }

      if (method === "GET" && pathname === "/api/repeated-offline") {
        const snapshot = repository.getSnapshot();
        const segments = buildRepeatedOfflineGroups(snapshot);
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          repeatedOfflineCount: segments.reduce(
            (sum, item) => sum + Number(item.minerCount ?? 0),
            0
          ),
          segments
        });
        return;
      }

      const repeatedOfflineSegmentMatch = pathname.match(/^\/api\/repeated-offline\/segments\/([^/]+)\/miners$/);
      if (method === "GET" && repeatedOfflineSegmentMatch) {
        const segment = decodeURIComponent(repeatedOfflineSegmentMatch[1]);
        const snapshot = repository.getSnapshot();
        const miners = buildRepeatedOfflineMiners(snapshot, segment);
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          segment,
          minerCount: miners.length,
          miners
        });
        return;
      }

      if (method === "GET" && pathname === "/api/alerts") {
        const snapshot = repository.getSnapshot();
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          alerts: snapshot.alerts
        });
        return;
      }

      if (method === "GET" && pathname === "/api/settings") {
        jsonResponse(res, 200, repository.getSettings());
        return;
      }

      if (method === "PUT" && pathname === "/api/settings") {
        const body = await parseJsonBody(req);
        invalidateResponseCache();
        jsonResponse(res, 200, repository.updateSettings(body));
        return;
      }

      if (method === "POST" && pathname === "/api/admin/refresh") {
        const body = await parseJsonBody(req);
        const snapshot = await collectorService.refresh({
          trigger: "manual",
          requestedBy: body.requestedBy ?? "unknown",
          trackKnownMinerState: true
        });
        invalidateResponseCache();
        jsonResponse(res, 200, {
          ok: true,
          requestedBy: body.requestedBy ?? "unknown",
          generatedAt: snapshot.generatedAt,
          minerCount: snapshot.miners.length,
          acceptedSnapshot: snapshot.acceptedSnapshot !== false,
          warningReason: snapshot.warningReason ?? null,
          baselineCount: snapshot.baselineCount ?? null,
          observedCount: snapshot.observedCount ?? null
        });
        return;
      }

      if (method === "POST" && pathname === "/api/scan/start") {
        const body = await parseJsonBody(req);
        const task = await scanTaskService.startTask(body);
        invalidateResponseCache();
        jsonResponse(res, 202, task);
        return;
      }

      if (method === "POST" && pathname === "/api/scan/stop") {
        const task = await scanTaskService.stopTask();
        invalidateResponseCache();
        jsonResponse(res, 200, task);
        return;
      }

      if (method === "GET" && pathname === "/api/scan/current") {
        jsonResponse(res, 200, {
          task: scanTaskService.getCurrentTask(),
          settings: repository.getSettings()
        });
        return;
      }

      if (method === "GET" && pathname === "/api/scan/history") {
        jsonResponse(res, 200, {
          history: scanTaskService.getTaskHistory()
        });
        return;
      }

      if (method === "GET" && pathname === "/api/results/segments") {
        const snapshot = repository.getSnapshot();
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          segments: buildSegmentResults(snapshot),
          currentTask: repository.getScanState().currentTask
        });
        return;
      }

      const segmentMinerMatch = pathname.match(/^\/api\/results\/segments\/([^/]+)\/miners$/);
      if (method === "GET" && segmentMinerMatch) {
        const segment = decodeURIComponent(segmentMinerMatch[1]);
        const snapshot = repository.getSnapshot();
        const miners = scanTaskService.getMinersBySegment(segment);
        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          segment,
          miners: miners.map(minerSummary)
        });
        return;
      }

      const resultMinerMatch = pathname.match(/^\/api\/results\/miners\/([^/]+)$/);
      if (method === "GET" && resultMinerMatch) {
        const minerId = decodeURIComponent(resultMinerMatch[1]);
        const snapshot = repository.getSnapshot();
        const miner = snapshot.miners.find((item) => item.id === minerId);
        if (!miner) {
          throw new HttpError(404, "Miner not found");
        }

        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          miner: buildMinerDetails(snapshot, miner)
        });
        return;
      }

      const minerStatusMatch = pathname.match(/^\/api\/miners\/([^/]+)\/status$/);
      if (method === "GET" && minerStatusMatch) {
        const snapshot = repository.getSnapshot();
        const miner = snapshot.miners.find((item) => item.id === decodeURIComponent(minerStatusMatch[1]));
        if (!miner) {
          throw new HttpError(404, "Miner not found");
        }

        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          miner: buildMinerDetails(snapshot, miner)
        });
        return;
      }

      const minerOverviewMatch = pathname.match(/^\/api\/miners\/([^/]+)\/overview$/);
      if (method === "GET" && minerOverviewMatch) {
        const minerId = decodeURIComponent(minerOverviewMatch[1]);
        const snapshot = repository.getSnapshot();
        const miner = snapshot.miners.find((item) => item.id === minerId);
        if (!miner) {
          throw new HttpError(404, "Miner not found");
        }

        jsonResponse(res, 200, {
          generatedAt: snapshot.generatedAt,
          miner: buildMinerDetails(snapshot, miner)
        });
        return;
      }

      const knownMinerMatch = pathname.match(/^\/api\/known-miners\/([^/]+)$/);
      if (method === "DELETE" && knownMinerMatch) {
        const knownMinerId = decodeURIComponent(knownMinerMatch[1]);
        const removed = registry.deleteKnownMiner(knownMinerId);
        const snapshot = repository.getSnapshot();
        const remainingMiners = snapshot.miners.filter(
          (miner) =>
            miner.id !== removed.id &&
            resolveMinerIp(miner) !== removed.ip
        );
        const remainingAlerts = snapshot.alerts.filter(
          (alert) => alert.minerId !== removed.id
        );
        const remainingHistory = { ...snapshot.history };
        delete remainingHistory[removed.id];
        const remainingRuntime = { ...snapshot.minerRuntime };
        delete remainingRuntime[removed.id];
        const nextDashboard = collectorService.analyzer.buildDashboard(
          remainingMiners,
          remainingAlerts
        );

        repository.replaceSnapshot({
          ...snapshot,
          generatedAt: nextDashboard.generatedAt,
          miners: remainingMiners,
          alerts: remainingAlerts,
          dashboard: nextDashboard,
          history: remainingHistory,
          minerRuntime: remainingRuntime,
          scheduler: snapshot.scheduler
        });
        invalidateResponseCache();

        jsonResponse(res, 200, {
          ok: true,
          removed,
          generatedAt: nextDashboard.generatedAt
        });
        return;
      }

      const knownMinerRefreshMatch = pathname.match(/^\/api\/known-miners\/([^/]+)\/refresh$/);
      if (method === "POST" && knownMinerRefreshMatch) {
        const knownMinerIdentifier = decodeURIComponent(knownMinerRefreshMatch[1]);
        const targetMiner = findKnownMiner(registry, knownMinerIdentifier);
        if (!targetMiner) {
          notFound(res, "Known miner not found");
          return;
        }

        const refreshed = await collectorService.refresh({
          trigger: "manual-single",
          requestedBy: "known-miner-refresh",
          miners: [targetMiner],
          totalTargets: 1,
          preserveExistingSnapshot: true,
          trackKnownMinerState: true,
          recordFailedTargets: true
        });

        const refreshedMiner =
          refreshed.miners.find((miner) => miner.id === targetMiner.id) ??
          refreshed.miners.find((miner) => resolveMinerIp(miner) === resolveConfigMinerIp(targetMiner)) ??
          null;

        if (!refreshedMiner) {
          notFound(res, "Refreshed miner snapshot not found");
          return;
        }
        invalidateResponseCache();

        jsonResponse(res, 200, {
          generatedAt: refreshed.generatedAt ?? null,
          miner: minerSummary(refreshedMiner)
        });
        return;
      }

      if (method === "POST" && pathname === "/api/known-miners/clear-refine") {
        const body = await parseJsonBody(req);
        const requestedIps = uniqueStrings(body?.ips);
        if (requestedIps.length === 0) {
          throw new HttpError(400, "At least one miner IP is required");
        }

        const succeeded = [];
        const failed = [];
        const batchResults = [];

        await runBatchWithConcurrency(requestedIps, 12, async (ip) => {
          const targetMiner = findKnownMiner(registry, ip);
          if (!targetMiner) {
            failed.push({ ip, reason: "Known miner not found" });
            batchResults.push({ ip, id: null, success: false, reason: "Known miner not found" });
            return;
          }

          try {
            await collectorService.client.clearAutoTune(targetMiner);
            succeeded.push(ip);
            batchResults.push({ ip, id: targetMiner.id, success: true, reason: null });
          } catch (error) {
            const reason = String(error?.message ?? "Unknown error");
            failed.push({ ip, reason });
            batchResults.push({ ip, id: targetMiner.id, success: false, reason });
          }
        });

        const now = new Date().toISOString();
        const snapshot = repository.getSnapshot();
        const nextSnapshot = applyClearAutoTuneBatchResult(snapshot, batchResults, now);
        repository.replaceSnapshot(nextSnapshot);
        invalidateResponseCache();

        jsonResponse(res, 200, {
          ok: failed.length === 0,
          message: buildBatchActionMessage("Clear auto tune", succeeded, failed),
          targets: requestedIps,
          requestedCount: requestedIps.length,
          succeeded,
          failed,
          generatedAt: nextSnapshot.generatedAt ?? snapshot.generatedAt ?? now
        });
        return;
      }

      if (await tryServeWebApp(req, res, pathname, config)) {
        return;
      }

      notFound(res);
    } catch (error) {
      sendError(res, error);
    }
  };
}
