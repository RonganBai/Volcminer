import { randomUUID } from "node:crypto";
import { HttpError } from "../utils/http.js";
import { logger } from "../utils/logger.js";

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
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

function summarizeSegments(miners) {
  const groups = new Map();

  for (const miner of miners) {
    const ip = resolveMinerIp(miner) ?? miner.name;
    const segment = segmentFromIp(ip);
    const current = groups.get(segment) ?? {
      segment,
      minerCount: 0,
      onlineCount: 0,
      offlineCount: 0,
      alertCount: 0,
      totalHashrate: 0,
      lastScanFinishedAt: miner.metrics?.lastSeenAt ?? null
    };

    current.minerCount += 1;
    current.onlineCount += miner.metrics?.online ? 1 : 0;
    current.offlineCount += miner.metrics?.online ? 0 : 1;
    current.alertCount += Array.isArray(miner.alerts) ? miner.alerts.length : 0;
    current.totalHashrate += Number(miner.metrics?.hashrateRt ?? 0);
    current.lastScanFinishedAt = miner.metrics?.lastSeenAt ?? current.lastScanFinishedAt;
    groups.set(segment, current);
  }

  return [...groups.values()].sort((a, b) => a.segment.localeCompare(b.segment));
}

function dedupeStrings(values) {
  return [...new Set(values.filter(Boolean).map((value) => String(value).trim()).filter(Boolean))];
}

function normalizeViews(views, settings) {
  const source = Array.isArray(views) && views.length > 0 ? views : settings.scanViews;
  return source.map((view, index) => ({
    id: String(view.id ?? `view-${index + 1}`),
    label: String(view.label ?? view.subnetPrefix ?? `View ${index + 1}`),
    subnetPrefix: String(view.subnetPrefix ?? "").trim(),
    startHost: Number(view.startHost ?? 1),
    endHost: Number(view.endHost ?? 255),
    username: String(view.username ?? settings.defaultUsername ?? "root"),
    password: String(view.password ?? settings.defaultPassword ?? "ltc@dog"),
    timeoutSeconds: 5,
    mode: String(view.mode ?? settings.defaultMode ?? "global"),
    site: String(view.site ?? "scan")
  })).filter((view) => view.subnetPrefix);
}

function targetCountFromViews(views) {
  return views.reduce((total, view) => total + Math.max(0, (view.endHost - view.startHost) + 1), 0);
}

function filterKnownMinersByViews(miners, views) {
  if (!views.length) {
    return [];
  }
  const segments = new Set(views.map((view) => view.subnetPrefix));
  return miners.filter((miner) => {
    const ip = miner.baseUrl ? new URL(miner.baseUrl).hostname : "";
    return segments.has(segmentFromIp(ip));
  });
}

export class ScanTaskService {
  constructor({ collectorService, repository, registry, resourceGuard, config }) {
    this.collectorService = collectorService;
    this.repository = repository;
    this.registry = registry;
    this.resourceGuard = resourceGuard;
    this.config = config;
    this.runningPromise = null;
    this.delayedRetryTimer = null;
    this.activeAbortController = null;
  }

  getCurrentTask() {
    return this.repository.getScanState().currentTask;
  }

  getTaskHistory() {
    return this.repository.getScanState().history;
  }

  getResultSegments() {
    return summarizeSegments(this.repository.getSnapshot().miners);
  }

  getMinersBySegment(segment) {
    const snapshot = this.repository.getSnapshot();
    return snapshot.miners.filter((miner) => {
      const ip = resolveMinerIp(miner) ?? "";
      return segmentFromIp(ip) === segment;
    });
  }

  async startTask(body = {}) {
    const active = this.getCurrentTask();
    if (active && ["running", "delayed", "waiting-stop"].includes(active.scanState)) {
      return active;
    }

    const settings = this.repository.getSettings();
    const mode = body.mode === "known-list" ? "known-list" : "global";
    const scanViews = normalizeViews(body.scanViews, settings);
    const timeoutSeconds = Math.max(2, Math.ceil((this.config.fetchTimeoutMs ?? 5000) / 1000));
    const requestedConcurrency = this.config.scanConcurrency;
    const onlyEnabled = body.onlyEnabled !== false;
    const defaults = {
      username: body.username ?? settings.defaultUsername,
      password: body.password ?? settings.defaultPassword,
      timeoutSeconds,
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

    const selectedSegments = dedupeStrings(scanViews.map((view) => view.subnetPrefix));
    const miners = mode === "known-list"
      ? filterKnownMinersByViews(
          onlyEnabled ? this.registry.loadMiners() : this.registry.loadAllMiners(),
          scanViews
        )
      : this.registry.buildMinersFromViews(scanViews, defaults);

    if (miners.length === 0) {
      throw new HttpError(400, "No miners available for this scan request");
    }

    const guard = await this.resourceGuard.evaluate();
    const warningReason = guard.allowed ? null : guard.reasons.join("; ");
    const task = {
      scanTaskId: randomUUID(),
      scanState: "running",
      requestedAt: new Date().toISOString(),
      lastUpdatedAt: new Date().toISOString(),
      lastScanStartedAt: new Date().toISOString(),
      lastScanFinishedAt: null,
      delayedByHashSentry: false,
      resourceWarning: !guard.allowed,
      warningByHashSentry: !guard.allowed && guard.reasons.some((reason) => reason.includes("HashSentry")),
      stopRequested: false,
      mode,
      onlyEnabled,
      concurrency: requestedConcurrency,
      timeoutSeconds,
      scanViews,
      selectedViewCount: scanViews.length,
      selectedSegments,
      progress: 0,
      matchedCount: 0,
      failedCount: 0,
      nonMinerCount: 0,
      totalTargets: mode === "global" ? targetCountFromViews(scanViews) : miners.length,
      segmentCount: 0,
      lastMatchedIp: null,
      lastDelayReason: null,
      warningReason,
      lastError: null,
      stoppedReason: null,
      resourceSnapshot: guard.snapshot
    };

    this.repository.setCurrentTask(task);

    if (!guard.allowed) {
      logger.warn("Manual scan forced despite resource guard warning", {
        reason: task.warningReason,
        mode
      });
    }

    this.clearDelayedRetry();
    this.runningPromise = this.runTask(task, miners, requestedConcurrency).finally(() => {
      this.runningPromise = null;
    });

    return task;
  }

  async stopTask() {
    const current = this.getCurrentTask();
    if (!current) {
      throw new HttpError(404, "No active scan task");
    }

    this.clearDelayedRetry();
    if (this.activeAbortController) {
      this.activeAbortController.abort();
      this.activeAbortController = null;
    }
    current.stopRequested = true;
    current.lastUpdatedAt = new Date().toISOString();
    current.stoppedReason = "Stopped by client request";
    if (current.scanState === "delayed" || current.scanState === "waiting-stop") {
      current.scanState = "stopped";
      current.lastScanFinishedAt = new Date().toISOString();
      current.delayedByHashSentry = false;
      this.repository.setCurrentTask(current);
      this.repository.pushScanHistory(current);
      return current;
    }

    current.scanState = "waiting-stop";
    this.repository.setCurrentTask(current);
    return current;
  }

  clearDelayedRetry() {
    if (this.delayedRetryTimer) {
      clearTimeout(this.delayedRetryTimer);
      this.delayedRetryTimer = null;
    }
  }

  scheduleDelayedRetry(task, miners, requestedConcurrency) {
    this.clearDelayedRetry();

    const retry = async () => {
      const current = this.getCurrentTask();
      if (!current || current.scanTaskId !== task.scanTaskId) {
        return;
      }

      if (current.stopRequested) {
        const stoppedAt = new Date().toISOString();
      const stoppedTask = {
          ...current,
          scanState: "stopped",
          delayedByHashSentry: false,
          lastUpdatedAt: stoppedAt,
          lastScanFinishedAt: stoppedAt,
          stoppedReason: current.stoppedReason ?? "Stopped by client request"
        };
      this.repository.setCurrentTask(stoppedTask);
      this.repository.pushScanHistory(stoppedTask);
      return;
    }

      const guard = await this.resourceGuard.evaluate();
      const next = {
        ...current,
        lastUpdatedAt: new Date().toISOString(),
        delayedByHashSentry: !guard.allowed && guard.reasons.some((reason) => reason.includes("HashSentry")),
        lastDelayReason: guard.allowed ? null : guard.reasons.join("; "),
        resourceSnapshot: guard.snapshot
      };

      this.repository.setCurrentTask(next);

      if (!guard.allowed) {
        this.delayedRetryTimer = setTimeout(() => {
          void retry();
        }, 3000);
        return;
      }

      this.clearDelayedRetry();
      const runningTask = {
        ...next,
        scanState: "running",
        lastScanStartedAt: new Date().toISOString()
      };
      this.repository.setCurrentTask(runningTask);
      this.runningPromise = this.runTask(runningTask, miners, requestedConcurrency).finally(() => {
        this.runningPromise = null;
      });
    };

    this.delayedRetryTimer = setTimeout(() => {
      void retry();
    }, 3000);
  }

  async runTask(task, miners, requestedConcurrency) {
    this.clearDelayedRetry();
    this.activeAbortController = new AbortController();
    try {
      const progressUpdater = (progress) => {
        const current = this.getCurrentTask();
        if (!current || current.scanTaskId !== task.scanTaskId) {
          return;
        }

        const next = {
          ...current,
          lastUpdatedAt: new Date().toISOString(),
          progress: progress.totalTargets > 0
            ? Number(((progress.completedCount / progress.totalTargets) * 100).toFixed(1))
            : 0,
          matchedCount: progress.matchedCount,
          failedCount: progress.failedCount,
          nonMinerCount: progress.nonMinerCount ?? current.nonMinerCount ?? 0,
          lastMatchedIp: progress.lastMatchedIp
        };
        this.repository.setCurrentTask(next);
      };

      const snapshot = await this.collectorService.refresh({
        trigger: "task",
        miners,
        totalTargets: miners.length,
        requestedBy: "scan-task",
        recordFailedTargets: task.mode === "known-list",
        trackKnownMinerState: task.mode === "known-list",
        persistKnownMinerUnion: task.mode === "global",
        shouldStop: () => Boolean(this.getCurrentTask()?.stopRequested),
        onProgress: progressUpdater,
        scanConcurrency: requestedConcurrency,
        abortSignal: this.activeAbortController.signal
      });

      const segments = summarizeSegments(snapshot.miners);
      const current = this.getCurrentTask();
      if (!current || current.scanTaskId !== task.scanTaskId) {
        return;
      }
      const completedCount =
        Number(snapshot.successCount ?? 0) +
        Number(snapshot.failedCount ?? 0) +
        Number(snapshot.nonMinerCount ?? 0);
      const finalProgress =
        current.totalTargets > 0
          ? Number(
              Math.min(
                100,
                ((completedCount / current.totalTargets) * 100)
              ).toFixed(1)
            )
          : 0;

      const completedTask = {
        ...current,
        scanState: snapshot.stopped ? "stopped" : "completed",
        lastUpdatedAt: new Date().toISOString(),
        lastScanFinishedAt: snapshot.generatedAt,
        progress: snapshot.stopped ? finalProgress : 100,
        matchedCount: snapshot.successCount,
        failedCount: snapshot.failedCount,
        nonMinerCount: snapshot.nonMinerCount ?? current.nonMinerCount ?? 0,
        segmentCount: segments.length,
        delayedByHashSentry: false,
        resourceSnapshot: current.resourceSnapshot,
        lastError: null,
        warningReason: snapshot.warningReason ?? null,
        snapshotAccepted: snapshot.acceptedSnapshot !== false,
        baselineCount: snapshot.baselineCount ?? null,
        observedCount: snapshot.observedCount ?? null
      };

      this.repository.setCurrentTask(completedTask);
      this.repository.pushScanHistory(completedTask);
      logger.info("Scan task finished", {
        scanTaskId: completedTask.scanTaskId,
        scanState: completedTask.scanState,
        matchedCount: completedTask.matchedCount,
        failedCount: completedTask.failedCount,
        segmentCount: completedTask.segmentCount
      });
    } finally {
      this.activeAbortController = null;
    }
  }
}
