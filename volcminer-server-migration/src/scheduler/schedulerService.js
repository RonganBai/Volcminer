import { logger } from "../utils/logger.js";

const SCHEDULED_CYCLE = ["known-list", "known-list", "known-list", "global-all-views"];

function normalizeViews(views, settings) {
  return (Array.isArray(views) ? views : []).map((view, index) => ({
    id: String(view.id ?? `view-${index + 1}`),
    label: String(view.label ?? view.subnetPrefix ?? `View ${index + 1}`),
    subnetPrefix: String(view.subnetPrefix ?? "").trim(),
    startHost: Number(view.startHost ?? 1),
    endHost: Number(view.endHost ?? 255),
    username: String(view.username ?? settings.defaultUsername ?? "root"),
    password: String(view.password ?? settings.defaultPassword ?? "ltc@dog"),
    timeoutSeconds: Number(settings.defaultTimeoutSeconds ?? 5),
    mode: String(view.mode ?? settings.defaultMode ?? "global"),
    site: String(view.site ?? "scan")
  })).filter((view) => view.subnetPrefix);
}

export class SchedulerService {
  constructor({ collectorService, repository, resourceGuard, config, registry }) {
    this.collectorService = collectorService;
    this.repository = repository;
    this.resourceGuard = resourceGuard;
    this.config = config;
    this.registry = registry;
    this.timer = null;
    this.nextScheduledAt = null;
  }

  start() {
    this.nextScheduledAt = new Date(Date.now() + this.config.schedulerInitialDelayMs).toISOString();
    this.repository.updateScheduler({
      scanState: "waiting",
      lastDelayReason: null,
      lastSkipReason: null,
      delayedByHashSentry: false,
      nextScheduledAt: this.nextScheduledAt
    });

    this.timer = setInterval(() => {
      this.tick().catch((error) => {
        logger.error("Scheduler tick failed", { error: error.message });
        this.repository.updateScheduler({
          scanState: "skipped",
          lastError: error.message
        });
      });
    }, this.config.schedulerTickMs);
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  async triggerManualRefresh(requestedBy = "manual") {
    logger.info("Manual refresh requested", { requestedBy });
    return this.collectorService.refresh({ trigger: "manual", requestedBy });
  }

  async tick() {
    const scheduler = this.repository.getSnapshot().scheduler;
    const nextScheduledAt = scheduler.nextScheduledAt
      ? new Date(scheduler.nextScheduledAt).getTime()
      : Date.now();

    if (Date.now() < nextScheduledAt) {
      return;
    }

    const guard = await this.resourceGuard.evaluate();
    if (!guard.allowed) {
      const delayedByHashSentry = guard.reasons.some((reason) => reason.includes("HashSentry"));
      const lastDelayReason = guard.reasons.join("; ");
      const cycleIndex = Number.isFinite(Number(scheduler.scheduledCycleIndex))
        ? Number(scheduler.scheduledCycleIndex)
        : 0;
      const scheduledMode = SCHEDULED_CYCLE[cycleIndex] ?? SCHEDULED_CYCLE[0];
      this.nextScheduledAt = new Date(Date.now() + this.config.schedulerTickMs).toISOString();
      this.repository.updateScheduler({
        scanState: "delayed",
        delayedByHashSentry,
        lastDelayReason,
        nextScheduledAt: this.nextScheduledAt,
        resourceSnapshot: guard.snapshot,
        scheduledCycleIndex: cycleIndex,
        scheduledCycleLength: SCHEDULED_CYCLE.length,
        lastScheduledMode: scheduledMode
      });
      logger.warn("Scheduler delayed", {
        delayedByHashSentry,
        reason: lastDelayReason,
        scheduledMode
      });
      return;
    }

    const cycleIndex = Number.isFinite(Number(scheduler.scheduledCycleIndex))
      ? Number(scheduler.scheduledCycleIndex)
      : 0;
    const scheduledMode = SCHEDULED_CYCLE[cycleIndex] ?? SCHEDULED_CYCLE[0];
    const snapshot = scheduledMode === "global-all-views"
      ? await this.runScheduledGlobalFullScan()
      : await this.collectorService.refresh({
          trigger: "scheduled-known-list",
          requestedBy: "scheduler",
          trackKnownMinerState: true
        });

    const nextCycleIndex = (cycleIndex + 1) % SCHEDULED_CYCLE.length;
    this.nextScheduledAt = new Date(Date.now() + this.config.pollIntervalMs).toISOString();
    this.repository.updateScheduler({
      scanState: "waiting",
      delayedByHashSentry: false,
      lastDelayReason: null,
      nextScheduledAt: this.nextScheduledAt,
      resourceSnapshot: guard.snapshot,
      lastSuccessfulScanAt: snapshot.generatedAt,
      scheduledCycleIndex: nextCycleIndex,
      scheduledCycleLength: SCHEDULED_CYCLE.length,
      lastScheduledMode: scheduledMode
    });
  }

  async runScheduledGlobalFullScan() {
    const settings = this.repository.getSettings();
    const scanViews = normalizeViews(settings.scanViews, settings);
    const miners = this.registry.buildMinersFromViews(scanViews, {
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

    return this.collectorService.refresh({
      trigger: "scheduled-global-full-range",
      requestedBy: "scheduler",
      miners,
      totalTargets: miners.length,
      trackKnownMinerState: false,
      recordFailedTargets: false,
      persistKnownMinerUnion: true,
      preserveExistingSnapshot: true,
      scanConcurrency: this.config.scanConcurrency
    });
  }
}
