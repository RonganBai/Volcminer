import { logger } from "../utils/logger.js";
import { isNonMinerError } from "../utils/minerFingerprint.js";

const MAX_BATCH_CONCURRENCY = 128;
const MAX_BATCH_SIZE = 256;
const PROGRESS_EMIT_INTERVAL_MS = 250;
const MINER_RUNTIME_HISTORY_LIMIT = 40;
const PENDING_RETIRE_TAG = "\u5f85\u4e0b\u67b6";

function delayToEventLoop() {
  return new Promise((resolve) => setImmediate(resolve));
}

function isAbortError(error) {
  return error?.code === "ABORT_ERR" || /aborted/i.test(String(error?.message ?? ""));
}

function isTimeoutLikeError(error) {
  const message = String(error?.message ?? "");
  return (
    error?.code === "ETIMEDOUT" ||
    /timed?\s*out/i.test(message) ||
    /curl:\s*\(28\)/i.test(message) ||
    /max-time/i.test(message)
  );
}

function resolveSnapshotMinerKey(miner) {
  return (
    miner?.overview?.network?.ip ??
    miner?.rawStatus?.ipaddress ??
    miner?.targetIp ??
    miner?.id ??
    null
  );
}

function mergeSnapshotMiners(previousMiners, currentMiners) {
  const merged = new Map();

  for (const miner of Array.isArray(previousMiners) ? previousMiners : []) {
    const key = resolveSnapshotMinerKey(miner);
    if (key) {
      merged.set(key, miner);
    }
  }

  for (const miner of Array.isArray(currentMiners) ? currentMiners : []) {
    const key = resolveSnapshotMinerKey(miner);
    if (key) {
      merged.set(key, miner);
    }
  }

  return [...merged.values()];
}

function mean(values) {
  if (!Array.isArray(values) || values.length === 0) {
    return 0;
  }

  return values.reduce((sum, value) => sum + Number(value ?? 0), 0) / values.length;
}

function median(values) {
  const nums = (Array.isArray(values) ? values : [])
    .map((value) => Number(value ?? 0))
    .filter((value) => Number.isFinite(value) && value > 0)
    .sort((left, right) => left - right);

  if (nums.length === 0) {
    return 0;
  }

  const mid = Math.floor(nums.length / 2);
  return nums.length % 2 === 0 ? mean([nums[mid - 1], nums[mid]]) : nums[mid];
}

function summarizeSnapshot(snapshot, meta = {}) {
  const counts = summarizeSnapshotCounts(snapshot.miners);
  return {
    generatedAt: snapshot.generatedAt ?? new Date().toISOString(),
    minerCount: Array.isArray(snapshot.miners) ? snapshot.miners.length : 0,
    alertCount: Array.isArray(snapshot.alerts) ? snapshot.alerts.length : 0,
    onlineCount: counts.onlineCount,
    unresponsiveCount: counts.unresponsiveCount,
    offlineCount: counts.offlineCount,
    pendingRetireCount: counts.pendingRetireCount,
    diagnosisCount: counts.diagnosisCount,
    repeatedOfflineCount: counts.repeatedOfflineCount,
    segmentCount: Array.isArray(meta.segments) ? meta.segments.length : 0,
    successCount: Number(meta.successCount ?? 0),
    failedCount: Number(meta.failedCount ?? 0),
    nonMinerCount: Number(meta.nonMinerCount ?? 0),
    trigger: meta.trigger ?? null,
    mode: meta.mode ?? null,
    accepted: meta.accepted !== false,
    warningReason: meta.warningReason ?? null,
    baselineCount: Number(meta.baselineCount ?? 0),
    observedCount: Number(meta.observedCount ?? 0)
  };
}

function summarizeSnapshotCounts(miners) {
  let onlineCount = 0;
  let unresponsiveCount = 0;
  let offlineCount = 0;
  let pendingRetireCount = 0;
  let diagnosisCount = 0;
  let repeatedOfflineCount = 0;

  for (const miner of Array.isArray(miners) ? miners : []) {
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
    onlineCount,
    unresponsiveCount,
    offlineCount,
    pendingRetireCount,
    diagnosisCount,
    repeatedOfflineCount
  };
}

function shouldPreserveSnapshot({ baselineCount, observedCount }) {
  const baseline = Number(baselineCount ?? 0);
  const observed = Number(observedCount ?? 0);

  if (baseline < 1000) {
    return false;
  }

  const floor = Math.max(100, Math.floor(baseline * 0.2));
  return observed < floor;
}

function appendRuntimeEvent(runtime, event) {
  const history = Array.isArray(runtime.history) ? runtime.history : [];
  runtime.history = [...history, event].slice(-MINER_RUNTIME_HISTORY_LIMIT);
}

function withPendingRetireTag(tags, enabled) {
  const values = Array.isArray(tags) ? tags.map((tag) => String(tag)) : [];
  const filtered = values.filter((tag) => tag !== PENDING_RETIRE_TAG);
  return enabled ? [...filtered, PENDING_RETIRE_TAG] : filtered;
}

function parseTime(value) {
  const timestamp = value ? new Date(value).getTime() : NaN;
  return Number.isFinite(timestamp) ? timestamp : null;
}

function normalizeRepeatedOffline(runtime, now, repeatedOfflineWindowMs) {
  const windowStartedAtMs = parseTime(runtime.repeatOfflineWindowStartedAt);
  const nowMs = parseTime(now) ?? Date.now();

  if (!windowStartedAtMs) {
    runtime.repeatOfflineWindowStartedAt = null;
    runtime.repeatOfflineTransitionCount = 0;
    runtime.lastOfflineTransitionAt = null;
    runtime.isRepeatedOffline = false;
    runtime.repeatedOfflineMarkedAt = null;
    return runtime;
  }

  if (nowMs - windowStartedAtMs < repeatedOfflineWindowMs) {
    runtime.repeatOfflineTransitionCount = Number(runtime.repeatOfflineTransitionCount ?? 0);
    runtime.isRepeatedOffline = runtime.isRepeatedOffline === true;
    runtime.lastOfflineTransitionAt = runtime.lastOfflineTransitionAt ?? null;
    runtime.repeatedOfflineMarkedAt = runtime.repeatedOfflineMarkedAt ?? null;
    return runtime;
  }

  runtime.repeatOfflineWindowStartedAt = null;
  runtime.repeatOfflineTransitionCount = 0;
  runtime.lastOfflineTransitionAt = null;
  runtime.isRepeatedOffline = false;
  runtime.repeatedOfflineMarkedAt = null;
  return runtime;
}

function createRuntime(previousRuntime = {}, now, repeatedOfflineWindowMs) {
  const runtime = {
    state: previousRuntime.state ?? "online",
    consecutiveTimeouts: Number(previousRuntime.consecutiveTimeouts ?? 0),
    firstTimeoutAt: previousRuntime.firstTimeoutAt ?? null,
    lastTimeoutAt: previousRuntime.lastTimeoutAt ?? null,
    lastResponsiveAt: previousRuntime.lastResponsiveAt ?? null,
    offlineSince: previousRuntime.offlineSince ?? null,
    pendingRetireSince: previousRuntime.pendingRetireSince ?? null,
    lastClearAutoTuneAt: previousRuntime.lastClearAutoTuneAt ?? null,
    lastClearAutoTuneOutcome: previousRuntime.lastClearAutoTuneOutcome ?? null,
    clearAutoTuneEpisodeAt: previousRuntime.clearAutoTuneEpisodeAt ?? null,
    repeatOfflineWindowStartedAt: previousRuntime.repeatOfflineWindowStartedAt ?? null,
    repeatOfflineTransitionCount: Number(previousRuntime.repeatOfflineTransitionCount ?? 0),
    lastOfflineTransitionAt: previousRuntime.lastOfflineTransitionAt ?? null,
    isRepeatedOffline: previousRuntime.isRepeatedOffline === true,
    repeatedOfflineMarkedAt: previousRuntime.repeatedOfflineMarkedAt ?? null,
    history: Array.isArray(previousRuntime.history) ? previousRuntime.history : [],
    updatedAt: now
  };
  return normalizeRepeatedOffline(runtime, now, repeatedOfflineWindowMs);
}

function isOfflineLikeState(state) {
  return state === "offline" || state === "pending-retire";
}

function recordOfflineTransition(runtime, now, repeatedOfflineWindowMs, repeatedOfflineThreshold) {
  normalizeRepeatedOffline(runtime, now, repeatedOfflineWindowMs);
  const nowMs = parseTime(now) ?? Date.now();
  const firstOfflineMs = parseTime(runtime.repeatOfflineWindowStartedAt);
  const rapidRepeatWindowMs = 60 * 60 * 1000;

  if (!runtime.repeatOfflineWindowStartedAt) {
    runtime.repeatOfflineWindowStartedAt = now;
    runtime.repeatOfflineTransitionCount = 1;
    runtime.lastOfflineTransitionAt = now;
    runtime.isRepeatedOffline = false;
    runtime.repeatedOfflineMarkedAt = null;
    return runtime;
  }

  runtime.repeatOfflineTransitionCount =
    Number(runtime.repeatOfflineTransitionCount ?? 0) + 1;
  runtime.lastOfflineTransitionAt = now;
  if (runtime.repeatOfflineTransitionCount >= repeatedOfflineThreshold) {
    runtime.isRepeatedOffline = true;
    runtime.repeatedOfflineMarkedAt = runtime.repeatedOfflineMarkedAt ?? now;
    return runtime;
  }

  if (
    runtime.repeatOfflineTransitionCount >= 2 &&
    firstOfflineMs != null &&
    nowMs - firstOfflineMs < rapidRepeatWindowMs
  ) {
    runtime.isRepeatedOffline = true;
    runtime.repeatedOfflineMarkedAt = runtime.repeatedOfflineMarkedAt ?? now;
  }
  return runtime;
}

function markMinerRecovered(miner, previousRuntime, now, repeatedOfflineWindowMs) {
  const runtime = createRuntime(previousRuntime, now, repeatedOfflineWindowMs);
  const previousState = runtime.state;

  runtime.state = "online";
  runtime.consecutiveTimeouts = 0;
  runtime.firstTimeoutAt = null;
  runtime.lastTimeoutAt = null;
  runtime.lastResponsiveAt = now;
  runtime.offlineSince = null;
  runtime.pendingRetireSince = null;
  runtime.lastClearAutoTuneOutcome = null;
  runtime.clearAutoTuneEpisodeAt = null;
  runtime.updatedAt = now;

  if (previousState !== "online") {
    appendRuntimeEvent(runtime, {
      at: now,
      state: "online",
      type: "recovered",
      reason: "Miner recovered during known inventory scan"
    });
  }

  miner.status = "ok";
  miner.tags = withPendingRetireTag(miner.tags, false);
  miner.lifecycle = runtime;
  return { miner, runtime };
}

function markMinerTimedOut(
  miner,
  previousRuntime,
  now,
  pendingRetireAfterMs,
  repeatedOfflineWindowMs,
  repeatedOfflineThreshold
) {
  const runtime = createRuntime(previousRuntime, now, repeatedOfflineWindowMs);
  const previousState = runtime.state;

  runtime.consecutiveTimeouts += 1;
  runtime.firstTimeoutAt = runtime.firstTimeoutAt ?? now;
  runtime.lastTimeoutAt = now;
  runtime.updatedAt = now;

  if (runtime.consecutiveTimeouts >= 3) {
    runtime.state = "offline";
    runtime.offlineSince = runtime.offlineSince ?? now;
  } else {
    runtime.state = "unresponsive";
    runtime.offlineSince = null;
  }

  if (
    runtime.state === "offline" &&
    runtime.offlineSince &&
    Date.now() - new Date(runtime.offlineSince).getTime() >= pendingRetireAfterMs
  ) {
    runtime.state = "pending-retire";
    runtime.pendingRetireSince = runtime.pendingRetireSince ?? now;
  }

  if (!isOfflineLikeState(previousState) && isOfflineLikeState(runtime.state)) {
    recordOfflineTransition(runtime, now, repeatedOfflineWindowMs, repeatedOfflineThreshold);
  }

  if (
    runtime.consecutiveTimeouts >= 2 &&
    runtime.firstTimeoutAt &&
    runtime.clearAutoTuneEpisodeAt !== runtime.firstTimeoutAt
  ) {
    runtime.clearAutoTuneEpisodeAt = runtime.firstTimeoutAt;
    runtime.lastClearAutoTuneAt = now;
    runtime.shouldClearAutoTune = true;
  }

  if (previousState !== runtime.state) {
    appendRuntimeEvent(runtime, {
      at: now,
      state: runtime.state,
      type: "transition",
      reason: `Consecutive timeout count reached ${runtime.consecutiveTimeouts}`
    });
  }

  miner.status = runtime.state === "unresponsive" ? "error" : "offline";
  miner.tags = withPendingRetireTag(miner.tags, runtime.state === "pending-retire");
  miner.lifecycle = runtime;
  return { miner, runtime };
}

function markMinerErrored(miner, previousRuntime, now, repeatedOfflineWindowMs) {
  const runtime = createRuntime(previousRuntime, now, repeatedOfflineWindowMs);
  const previousState = runtime.state;
  runtime.updatedAt = now;

  if (previousState === "online") {
    runtime.state = "unresponsive";
    appendRuntimeEvent(runtime, {
      at: now,
      state: "unresponsive",
      type: "error",
      reason: "Known miner request failed without timeout"
    });
  }

  miner.status = runtime.state === "pending-retire" || runtime.state === "offline" ? "offline" : "error";
  miner.tags = withPendingRetireTag(miner.tags, runtime.state === "pending-retire");
  miner.lifecycle = runtime;
  return { miner, runtime };
}

export class CollectorService {
  constructor({
    registry,
    client,
    analyzer,
    repository,
    scanConcurrency,
    repeatedOfflineWindowMs = 86400000,
    repeatedOfflineThreshold = 3
  }) {
    this.registry = registry;
    this.client = client;
    this.analyzer = analyzer;
    this.repository = repository;
    this.scanConcurrency = scanConcurrency;
    this.repeatedOfflineWindowMs = repeatedOfflineWindowMs;
    this.repeatedOfflineThreshold = repeatedOfflineThreshold;
    this.refreshInFlight = null;
  }

  async refresh(context = {}) {
    if (this.refreshInFlight) {
      return this.refreshInFlight;
    }

    this.refreshInFlight = this.performRefresh(context).finally(() => {
      this.refreshInFlight = null;
    });

    return this.refreshInFlight;
  }

  async performRefresh(context = {}) {
    const miners = Array.isArray(context.miners) ? context.miners : this.registry.loadMiners();
    const previousSnapshot = this.repository.getSnapshot();
    const previousRuntime = previousSnapshot.minerRuntime ?? {};
    const analyzedMiners = [];
    const nextRuntime = {};
    const alerts = [];
    const startedAt = new Date().toISOString();
    const totalTargets = Number.isFinite(Number(context.totalTargets))
      ? Number(context.totalTargets)
      : miners.length;
    let queueLength = miners.length;
    let currentConcurrency = 0;
    let successCount = 0;
    let failedCount = 0;
    let nonMinerCount = 0;
    let stopped = false;
    let lastProgressEmissionAt = 0;

    const recordFailedTargets = context.recordFailedTargets !== false;
    const trackKnownMinerState = context.trackKnownMinerState === true;
    const pendingRetireAfterMs = Number(this.analyzer.rules.pendingRetireAfterMs ?? 86400000);

    this.repository.updateScheduler({
      scanState: "running",
      lastScanStartedAt: startedAt,
      lastError: null,
      queueLength,
      currentConcurrency,
      minerCount: miners.length,
      successCount,
      failedCount
    });

    const concurrency = Number.isFinite(Number(context.scanConcurrency))
      ? Number(context.scanConcurrency)
      : this.scanConcurrency;
    const batchConcurrency = Math.max(1, Math.min(concurrency, MAX_BATCH_CONCURRENCY));
    const batchSize = Math.max(batchConcurrency, MAX_BATCH_SIZE);

    const emitProgress = (miner, force = false) => {
      const now = Date.now();
      if (!force && now - lastProgressEmissionAt < PROGRESS_EMIT_INTERVAL_MS) {
        return;
      }

      lastProgressEmissionAt = now;
      context.onProgress?.({
        totalTargets,
        completedCount: successCount + failedCount + nonMinerCount,
        matchedCount: successCount,
        failedCount,
        nonMinerCount,
        currentConcurrency,
        queueLength,
        lastMinerId: miner?.id ?? null,
        lastMatchedIp: miner?.baseUrl ?? null
      });
    };

    for (let index = 0; index < miners.length; index += batchSize) {
      if (context.shouldStop?.()) {
        stopped = true;
        break;
      }

      const batch = miners.slice(index, index + batchSize);
      await this.runWithConcurrency(batch, batchConcurrency, async (miner) => {
        if (context.shouldStop?.()) {
          stopped = true;
          return;
        }

        const runtimeMiner = {
          ...miner,
          abortSignal: context.abortSignal
        };

        currentConcurrency += 1;
        queueLength -= 1;
        this.repository.updateScheduler({
          currentConcurrency,
          queueLength,
          minerCount: miners.length,
          successCount,
          failedCount
        });

        try {
          const raw = await this.client.collect(runtimeMiner);
          const analyzed = this.analyzer.analyzeMiner(
            miner,
            raw,
            "ok",
            previousSnapshot.history?.[miner.id] ?? []
          );

          if (trackKnownMinerState) {
            const next = markMinerRecovered(
              analyzed,
              previousRuntime[miner.id],
              analyzed.metrics.lastSeenAt,
              this.repeatedOfflineWindowMs
            );
            nextRuntime[miner.id] = next.runtime;
          }

          analyzedMiners.push(analyzed);
          alerts.push(...analyzed.alerts);
          successCount += 1;
        } catch (error) {
          if (isAbortError(error)) {
            stopped = true;
            return;
          }

          if (isNonMinerError(error) && context.filterNonMinerDevices !== false) {
            nonMinerCount += 1;
            context.onNonMiner?.({
              minerId: miner.id,
              baseUrl: miner.baseUrl,
              reason: error.message
            });
            logger.info("Skipping non-miner device", {
              minerId: miner.id,
              baseUrl: miner.baseUrl,
              error: error.message
            });
            return;
          }

          logger.warn("Miner collection failed", {
            minerId: miner.id,
            error: error.message
          });

          const analyzed = this.analyzer.analyzeMiner(
            miner,
            {
              status: { online: false },
              overview: {},
              monitor: { text: error.message }
            },
            "error",
            previousSnapshot.history?.[miner.id] ?? []
          );

          failedCount += 1;

          if (trackKnownMinerState) {
            const failureAt = analyzed.metrics.lastSeenAt;
            const timeoutFailure = isTimeoutLikeError(error);
            const next = timeoutFailure
              ? markMinerTimedOut(
                  analyzed,
                  previousRuntime[miner.id],
                  failureAt,
                  pendingRetireAfterMs,
                  this.repeatedOfflineWindowMs,
                  this.repeatedOfflineThreshold
                )
              : markMinerErrored(
                  analyzed,
                  previousRuntime[miner.id],
                  failureAt,
                  this.repeatedOfflineWindowMs
                );

            if (next.runtime.shouldClearAutoTune) {
              delete next.runtime.shouldClearAutoTune;
              try {
                await this.client.clearAutoTune(runtimeMiner, context.abortSignal);
                next.runtime.lastClearAutoTuneOutcome = "sent";
                appendRuntimeEvent(next.runtime, {
                  at: failureAt,
                  state: next.runtime.state,
                  type: "clear-auto-tune",
                  reason: "Triggered automatically after second consecutive timeout"
                });
              } catch (clearError) {
                next.runtime.lastClearAutoTuneOutcome =
                  clearError?.code === "UNSUPPORTED_ACTION"
                    ? "skipped-unconfigured"
                    : `failed: ${clearError.message}`;
                appendRuntimeEvent(next.runtime, {
                  at: failureAt,
                  state: next.runtime.state,
                  type: "clear-auto-tune",
                  reason:
                    clearError?.code === "UNSUPPORTED_ACTION"
                      ? "Clear auto tune endpoint not configured"
                      : `Clear auto tune request failed: ${clearError.message}`
                });
                logger.warn("Automatic clear auto tune failed", {
                  minerId: miner.id,
                  error: clearError.message
                });
              }
            }

            nextRuntime[miner.id] = next.runtime;
          }

          if (recordFailedTargets) {
            analyzed.error = error.message;
            analyzedMiners.push(analyzed);
            alerts.push(...analyzed.alerts);
          }
        } finally {
          currentConcurrency -= 1;
          emitProgress(miner);
          this.repository.updateScheduler({
            currentConcurrency,
            queueLength,
            minerCount: miners.length,
            successCount,
            failedCount
          });
        }
      });

      emitProgress(batch[batch.length - 1], true);
      await delayToEventLoop();

      if (context.shouldStop?.() || context.abortSignal?.aborted) {
        stopped = true;
        break;
      }
    }

    emitProgress(miners[miners.length - 1], true);

    const snapshotMiners = context.preserveExistingSnapshot === true
      ? mergeSnapshotMiners(previousSnapshot.miners, analyzedMiners)
      : analyzedMiners;
    const snapshotAlerts = snapshotMiners.flatMap((miner) =>
      Array.isArray(miner.alerts) ? miner.alerts : []
    );
    const history = this.analyzer.mergeHistory(previousSnapshot.history, analyzedMiners);
    const dashboard = this.analyzer.buildDashboard(snapshotMiners, snapshotAlerts);
    const acceptedSnapshotHistory = this.repository.getSnapshotHistory();
    const recentAcceptedCounts = [
      Number(previousSnapshot.miners?.length ?? 0),
      ...acceptedSnapshotHistory
        .filter((entry) => entry?.accepted !== false)
        .map((entry) => Number(entry.minerCount ?? 0))
    ]
      .map((value) => Number(value ?? 0))
      .filter((value) => Number.isFinite(value) && value > 0)
      .slice(0, 3);
    const baselineCount = median(recentAcceptedCounts);
    const observedCount = snapshotMiners.length;
    const expectedKnownListCount =
      context.trackKnownMinerState === true ? miners.length : 0;
    const referenceCount = expectedKnownListCount >= 1000
      ? expectedKnownListCount
      : baselineCount;
    const preserveExistingSnapshot = shouldPreserveSnapshot({
      baselineCount: referenceCount,
      observedCount
    });
    const snapshotWarningReason = preserveExistingSnapshot
      ? `扫描结果异常缩水：本次仅 ${observedCount} 台，历史基线约 ${referenceCount} 台，已沿用上一版快照`
      : null;
    const snapshot = {
      generatedAt: new Date().toISOString(),
      miners: snapshotMiners,
      alerts: snapshotAlerts,
      dashboard,
      history,
      minerRuntime: trackKnownMinerState
        ? {
            ...previousRuntime,
            ...nextRuntime
          }
        : previousSnapshot.minerRuntime ?? {},
      scheduler: {
        ...previousSnapshot.scheduler,
        scanState: stopped ? "stopped" : "completed",
        lastScanStartedAt: startedAt,
        lastScanFinishedAt: new Date().toISOString(),
        lastSuccessfulScanAt: new Date().toISOString(),
        delayedByHashSentry: false,
        currentConcurrency: 0,
        queueLength: 0,
        minerCount: miners.length,
        successCount,
        failedCount,
        lastSkipReason: null,
        lastSnapshotWarningReason: snapshotWarningReason,
        lastSnapshotWarningAt: snapshotWarningReason ? new Date().toISOString() : null,
        lastSnapshotWarningCount: snapshotWarningReason ? observedCount : null,
        lastSnapshotBaselineCount: snapshotWarningReason ? referenceCount : null,
        trigger: context.trigger ?? "manual"
      }
    };

    let knownMinerMerge = null;
    if (context.persistKnownMinerUnion === true) {
      const settings = this.repository.getSettings();
      knownMinerMerge = this.registry.mergeDiscoveredMiners(analyzedMiners, {
        username: settings.defaultUsername,
        password: settings.defaultPassword,
        timeoutSeconds: settings.defaultTimeoutSeconds,
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
      });
    }

    if (preserveExistingSnapshot) {
      this.repository.updateScheduler({
        scanState: "completed",
        lastScanFinishedAt: new Date().toISOString(),
        currentConcurrency: 0,
        queueLength: 0,
        minerCount: observedCount,
        successCount,
        failedCount,
        lastSnapshotWarningReason: snapshotWarningReason,
        lastSnapshotWarningAt: new Date().toISOString(),
        lastSnapshotWarningCount: observedCount,
        lastSnapshotBaselineCount: referenceCount
      });
    } else {
      this.repository.replaceSnapshot(snapshot);
    }

    this.repository.pushSnapshotHistory(
      summarizeSnapshot(snapshot, {
        trigger: context.trigger ?? "manual",
        mode:
          context.trackKnownMinerState === true
            ? "known-list"
            : context.persistKnownMinerUnion === true
              ? "global"
              : null,
        accepted: !preserveExistingSnapshot,
        warningReason: snapshotWarningReason,
        baselineCount: referenceCount,
        observedCount,
        segments
      })
    );

    logger.info("Collector refresh complete", {
      minerCount: analyzedMiners.length,
      alertCount: snapshotAlerts.length,
      successCount,
      failedCount,
      trigger: context.trigger ?? "manual",
      stopped,
      nonMinerCount,
      preserveExistingSnapshot,
      snapshotWarningReason,
      knownMinerMerge
    });

    return {
      ...snapshot,
      acceptedSnapshot: !preserveExistingSnapshot,
      warningReason: snapshotWarningReason,
      baselineCount: referenceCount,
      observedCount,
      stopped,
      totalTargets,
      successCount,
      failedCount,
      nonMinerCount,
      knownMinerMerge
    };
  }

  async runWithConcurrency(items, concurrency, worker) {
    const executing = new Set();

    for (const item of items) {
      const promise = Promise.resolve().then(() => worker(item));
      executing.add(promise);
      promise.finally(() => executing.delete(promise));

      if (executing.size >= concurrency) {
        await Promise.race(executing);
      }
    }

    await Promise.all(executing);
  }
}
