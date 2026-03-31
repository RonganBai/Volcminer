import fs from "node:fs";
import path from "node:path";

const FIXED_CONCURRENCY = 500;
const FIXED_TIMEOUT_SECONDS = 5;

export class CacheRepository {
  constructor(dataDir) {
    this.dataDir = dataDir;
    this.cacheFile = path.join(dataDir, "cache.json");
    this.snapshotFile = path.join(dataDir, "miner-snapshot.json");
    this.scanStateFile = path.join(dataDir, "scan-state.json");
    this.settingsFile = path.join(dataDir, "settings.json");
    this.persistTimer = null;
    this.persistInFlight = null;
    this.persistPending = false;
    this.state = {
      generatedAt: null,
      miners: [],
      alerts: [],
      dashboard: null,
      history: {},
      minerRuntime: {},
      settings: {
        serverUrl: null,
        defaultUsername: "root",
        defaultPassword: "ltc@dog",
        defaultMode: "global",
        defaultConcurrency: FIXED_CONCURRENCY,
        defaultTimeoutSeconds: FIXED_TIMEOUT_SECONDS,
        scanViews: [
          {
            id: "view-default-172-100-1",
            label: "172.100.1",
            subnetPrefix: "172.100.1",
            startHost: 1,
            endHost: 255,
            username: "root",
            password: "ltc@dog",
            timeoutSeconds: FIXED_TIMEOUT_SECONDS,
            mode: "global"
          }
        ]
      },
      scan: {
        currentTask: null,
        history: [],
        snapshotHistory: []
      },
      scheduler: {
        scanState: "idle",
        lastScanStartedAt: null,
        lastScanFinishedAt: null,
        lastSuccessfulScanAt: null,
        delayedByHashSentry: false,
        currentConcurrency: 0,
        queueLength: 0,
        minerCount: 0,
        successCount: 0,
        failedCount: 0,
        lastDelayReason: null,
        lastSkipReason: null,
        lastError: null,
        lastSnapshotWarningReason: null,
        lastSnapshotWarningAt: null,
        lastSnapshotWarningCount: null,
        lastSnapshotBaselineCount: null,
        scheduledCycleIndex: 0,
        scheduledCycleLength: 4,
        lastScheduledMode: null
      }
    };
  }

  ensureReady() {
    fs.mkdirSync(this.dataDir, { recursive: true });

    const persistedSettings = this.loadPersistedSettings();
    if (persistedSettings) {
      this.state.settings = persistedSettings;
    }

    if (
      !fs.existsSync(this.cacheFile) &&
      !fs.existsSync(this.snapshotFile) &&
      !fs.existsSync(this.scanStateFile)
    ) {
      this.persistSync();
      return;
    }

    try {
      const legacyState = this.loadLegacyCacheState();
      const persistedSnapshot =
        this.loadPersistedSnapshot() ?? this.normalizePersistedSnapshot(legacyState);
      const persistedScan =
        this.loadPersistedScanState() ?? this.normalizePersistedScanState(legacyState);
      const nextState = {
        generatedAt: persistedSnapshot.generatedAt,
        miners: persistedSnapshot.miners,
        alerts: persistedSnapshot.alerts,
        dashboard: persistedSnapshot.dashboard,
        history: persistedSnapshot.history,
        minerRuntime: persistedSnapshot.minerRuntime,
        settings: legacyState?.settings && typeof legacyState.settings === "object"
          ? {
              ...this.state.settings,
              ...legacyState.settings,
              scanViews: Array.isArray(legacyState.settings.scanViews)
                ? legacyState.settings.scanViews
                : this.state.settings.scanViews
              }
            : this.state.settings,
        scan: persistedScan.scan,
        scheduler: persistedScan.scheduler
      };
      this.state = nextState;
      if (persistedSettings) {
        this.state.settings = persistedSettings;
      }
      this.state.settings.defaultConcurrency = FIXED_CONCURRENCY;
      this.state.settings.defaultTimeoutSeconds = FIXED_TIMEOUT_SECONDS;
      this.state.settings.scanViews = this.state.settings.scanViews.map((view) => ({
        ...view,
        timeoutSeconds: FIXED_TIMEOUT_SECONDS
      }));
      if (!Array.isArray(this.state.scan.snapshotHistory) || this.state.scan.snapshotHistory.length === 0) {
        this.state.scan.snapshotHistory = [{
          generatedAt: this.state.generatedAt ?? new Date().toISOString(),
          minerCount: Array.isArray(this.state.miners) ? this.state.miners.length : 0,
          alertCount: Array.isArray(this.state.alerts) ? this.state.alerts.length : 0,
          segmentCount: Array.isArray(this.state.dashboard?.segments) ? this.state.dashboard.segments.length : 0,
          successCount: 0,
          failedCount: 0,
          nonMinerCount: 0,
          trigger: "startup-seed",
          mode: null,
          accepted: true,
          warningReason: null,
          baselineCount: Array.isArray(this.state.miners) ? this.state.miners.length : 0,
          observedCount: Array.isArray(this.state.miners) ? this.state.miners.length : 0
        }];
        this.persistSync();
      }
    } catch {
      this.persistSync();
    }
  }

  replaceSnapshot(snapshot) {
    this.state = {
      generatedAt: snapshot.generatedAt,
      miners: snapshot.miners,
      alerts: snapshot.alerts,
      dashboard: snapshot.dashboard,
      history: snapshot.history,
      minerRuntime: snapshot.minerRuntime ?? this.state.minerRuntime,
      settings: this.state.settings,
      scan: this.state.scan,
      scheduler: snapshot.scheduler ?? this.state.scheduler
    };
    this.persist();
  }

  updateScheduler(patch) {
    this.state.scheduler = {
      ...this.state.scheduler,
      ...patch
    };
    this.persist(250);
  }

  persistSync() {
    const payload = JSON.stringify(this.state, null, 2);
    fs.writeFileSync(this.cacheFile, payload, "utf8");
    fs.writeFileSync(
      this.snapshotFile,
      JSON.stringify(this.buildPersistedSnapshotState(), null, 2),
      "utf8"
    );
    fs.writeFileSync(
      this.scanStateFile,
      JSON.stringify(this.buildPersistedScanState(), null, 2),
      "utf8"
    );
    this.persistSettingsSync();
  }

  persist(delayMs = 0) {
    this.persistPending = true;

    if (this.persistTimer) {
      return;
    }

    this.persistTimer = setTimeout(() => {
      this.persistTimer = null;
      void this.flushPersist();
    }, delayMs);
  }

  async flushPersist() {
    if (this.persistInFlight || !this.persistPending) {
      return;
    }

    this.persistPending = false;
    const payload = JSON.stringify(this.state, null, 2);
    this.persistInFlight = Promise.all([
      fs.promises.writeFile(this.cacheFile, payload, "utf8"),
      fs.promises.writeFile(
        this.snapshotFile,
        JSON.stringify(this.buildPersistedSnapshotState(), null, 2),
        "utf8"
      ),
      fs.promises.writeFile(
        this.scanStateFile,
        JSON.stringify(this.buildPersistedScanState(), null, 2),
        "utf8"
      ),
      fs.promises.writeFile(
        this.settingsFile,
        JSON.stringify(this.state.settings, null, 2),
        "utf8"
      )
    ])
      .catch(() => {})
      .finally(() => {
        this.persistInFlight = null;
        if (this.persistPending) {
          this.persist();
        }
      });

    await this.persistInFlight;
  }

  getSnapshot() {
    return structuredClone(this.state);
  }

  getMinerRuntime() {
    return structuredClone(this.state.minerRuntime);
  }

  getMiner(id) {
    return this.state.miners.find((miner) => miner.id === id) ?? null;
  }

  getSettings() {
    return structuredClone(this.state.settings);
  }

  updateSettings(patch) {
    const next = {
      ...this.state.settings,
      ...patch,
      defaultConcurrency: FIXED_CONCURRENCY,
      defaultTimeoutSeconds: FIXED_TIMEOUT_SECONDS
    };

    if (patch.scanViews !== undefined) {
      next.scanViews = Array.isArray(patch.scanViews)
        ? structuredClone(patch.scanViews).map((view) => ({
            ...view,
            timeoutSeconds: FIXED_TIMEOUT_SECONDS
          }))
        : this.state.settings.scanViews;
    }

    this.state.settings = next;
    this.persist();
    return this.getSettings();
  }

  loadPersistedSettings() {
    if (!fs.existsSync(this.settingsFile)) {
      return null;
    }

    try {
      const raw = fs.readFileSync(this.settingsFile, "utf8");
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== "object") {
        return null;
      }

      return {
        ...this.state.settings,
        ...parsed,
        defaultConcurrency: FIXED_CONCURRENCY,
        defaultTimeoutSeconds: FIXED_TIMEOUT_SECONDS,
        scanViews: Array.isArray(parsed.scanViews)
          ? parsed.scanViews.map((view) => ({
              ...view,
              timeoutSeconds: FIXED_TIMEOUT_SECONDS
            }))
          : this.state.settings.scanViews
      };
    } catch {
      return null;
    }
  }

  persistSettingsSync() {
    fs.writeFileSync(
      this.settingsFile,
      JSON.stringify(this.state.settings, null, 2),
      "utf8"
    );
  }

  getScanState() {
    return structuredClone(this.state.scan);
  }

  getSnapshotHistory() {
    return structuredClone(this.state.scan.snapshotHistory ?? []);
  }

  pushSnapshotHistory(entry) {
    const history = Array.isArray(this.state.scan.snapshotHistory)
      ? this.state.scan.snapshotHistory
      : [];
    this.state.scan.snapshotHistory = [structuredClone(entry), ...history].slice(0, 3);
    this.persistSync();
  }

  loadLegacyCacheState() {
    if (!fs.existsSync(this.cacheFile)) {
      return null;
    }

    const raw = fs.readFileSync(this.cacheFile, "utf8");
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : null;
  }

  loadPersistedSnapshot() {
    if (!fs.existsSync(this.snapshotFile)) {
      return null;
    }

    const raw = fs.readFileSync(this.snapshotFile, "utf8");
    const parsed = JSON.parse(raw);
    return this.normalizePersistedSnapshot(parsed);
  }

  loadPersistedScanState() {
    if (!fs.existsSync(this.scanStateFile)) {
      return null;
    }

    const raw = fs.readFileSync(this.scanStateFile, "utf8");
    const parsed = JSON.parse(raw);
    return this.normalizePersistedScanState(parsed);
  }

  buildPersistedSnapshotState() {
    return {
      generatedAt: this.state.generatedAt,
      miners: this.state.miners,
      alerts: this.state.alerts,
      dashboard: this.state.dashboard,
      history: this.state.history,
      minerRuntime: this.state.minerRuntime
    };
  }

  buildPersistedScanState() {
    return {
      scan: this.state.scan,
      scheduler: this.state.scheduler
    };
  }

  normalizePersistedSnapshot(parsed) {
    if (!parsed || typeof parsed !== "object") {
      return {
        generatedAt: null,
        miners: [],
        alerts: [],
        dashboard: null,
        history: {},
        minerRuntime: {}
      };
    }

    return {
      generatedAt: parsed.generatedAt ?? null,
      miners: Array.isArray(parsed.miners) ? parsed.miners : [],
      alerts: Array.isArray(parsed.alerts) ? parsed.alerts : [],
      dashboard: parsed.dashboard ?? null,
      history: parsed.history && typeof parsed.history === "object" ? parsed.history : {},
      minerRuntime:
        parsed.minerRuntime && typeof parsed.minerRuntime === "object"
          ? parsed.minerRuntime
          : {}
    };
  }

  normalizePersistedScanState(parsed) {
    return {
      scan:
        parsed?.scan && typeof parsed.scan === "object"
          ? {
              currentTask: parsed.scan.currentTask ?? null,
              history: Array.isArray(parsed.scan.history) ? parsed.scan.history : [],
              snapshotHistory: Array.isArray(parsed.scan.snapshotHistory)
                ? parsed.scan.snapshotHistory
                : []
            }
          : {
              currentTask: null,
              history: [],
              snapshotHistory: []
            },
      scheduler:
        parsed?.scheduler && typeof parsed.scheduler === "object"
          ? {
              ...this.state.scheduler,
              ...parsed.scheduler
            }
          : { ...this.state.scheduler }
    };
  }

  normalizeRuntimeStateOnStartup() {
    const currentTask = this.state.scan.currentTask;
    if (
      currentTask &&
      ["running", "delayed", "waiting-stop"].includes(currentTask.scanState)
    ) {
      const stoppedAt = new Date().toISOString();
      const normalizedTask = {
        ...currentTask,
        scanState: "stopped",
        stopRequested: true,
        delayedByHashSentry: false,
        lastUpdatedAt: stoppedAt,
        lastScanFinishedAt: currentTask.lastScanFinishedAt ?? stoppedAt,
        stoppedReason:
          currentTask.stoppedReason ?? "Stopped because service restarted"
      };
      this.state.scan.currentTask = null;
      this.state.scan.history = [structuredClone(normalizedTask), ...this.state.scan.history].slice(0, 30);
    }

    this.state.scheduler = {
      ...this.state.scheduler,
      scanState: "idle",
      delayedByHashSentry: false,
      currentConcurrency: 0,
      queueLength: 0,
      minerCount: 0,
      successCount: 0,
      failedCount: 0,
      lastDelayReason: null,
      lastSkipReason: null,
      lastError: null
    };
    this.persist();
  }

  setCurrentTask(task) {
    this.state.scan.currentTask = task ? structuredClone(task) : null;
    this.persist(250);
  }

  pushScanHistory(task) {
    this.state.scan.history = [structuredClone(task), ...this.state.scan.history].slice(0, 30);
    this.persist();
  }
}
