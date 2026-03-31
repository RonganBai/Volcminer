import http from "node:http";
import { config } from "./config.js";
import { logger } from "./utils/logger.js";
import { CacheRepository } from "./storage/cacheRepository.js";
import { MinerRegistry } from "./collector/minerRegistry.js";
import { VolcminerClient } from "./collector/volcminerClient.js";
import { MinerAnalyzer } from "./analyzer/minerAnalyzer.js";
import { CollectorService } from "./collector/collectorService.js";
import { ResourceGuard } from "./monitoring/resourceGuard.js";
import { SchedulerService } from "./scheduler/schedulerService.js";
import { ScanTaskService } from "./scan/scanTaskService.js";
import { createApp } from "./app.js";

const repository = new CacheRepository(config.dataDir);
repository.ensureReady();
repository.normalizeRuntimeStateOnStartup();

const registry = new MinerRegistry(config.minersConfigPath, config.knownMinersPath);
const client = new VolcminerClient(config.fetchTimeoutMs);
const analyzer = new MinerAnalyzer({
  alertTemperatureC: config.alertTemperatureC,
  alertHashrateDropRatio: config.alertHashrateDropRatio,
  alertOfflineAfterMs: config.alertOfflineAfterMs
});
const resourceGuard = new ResourceGuard(config);
const collectorService = new CollectorService({
  registry,
  client,
  analyzer,
  repository,
  scanConcurrency: config.scanConcurrency,
  repeatedOfflineWindowMs: config.repeatedOfflineWindowMs,
  repeatedOfflineThreshold: config.repeatedOfflineThreshold
});
const schedulerService = new SchedulerService({
  collectorService,
  repository,
  resourceGuard,
  config,
  registry
});
const scanTaskService = new ScanTaskService({
  collectorService,
  repository,
  registry,
  resourceGuard,
  config
});

const app = createApp({ repository, collectorService, scanTaskService, registry, config });
const server = http.createServer(app);

async function bootstrap() {
  repository.updateScheduler({
    scanState: "idle",
    nextScheduledAt: new Date(Date.now() + config.schedulerInitialDelayMs).toISOString()
  });

  server.listen(config.port, config.host, () => {
    logger.info("VolcMiner aggregator listening", {
      host: config.host,
      port: config.port,
      minersConfigPath: config.minersConfigPath,
      knownMinersPath: config.knownMinersPath
    });
  });

  if (config.enableBackgroundPolling) {
    schedulerService.start();
  }
}

async function shutdown(signal) {
  logger.info("Shutdown signal received", { signal });
  schedulerService.stop();

  server.close(async () => {
    try {
      await repository.flushPersist();
      repository.persistSync();
    } catch (error) {
      logger.warn("Persist on shutdown failed", {
        signal,
        error: error?.message ?? String(error)
      });
    }

    logger.info("HTTP server stopped", { signal });
    process.exit(0);
  });
}

process.on("SIGINT", () => {
  void shutdown("SIGINT");
});
process.on("SIGTERM", () => {
  void shutdown("SIGTERM");
});

bootstrap().catch((error) => {
  logger.error("Bootstrap failed", { error: error.message, stack: error.stack });
  process.exit(1);
});
