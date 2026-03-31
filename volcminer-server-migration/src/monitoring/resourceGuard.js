import os from "node:os";
import { runCommand } from "../utils/process.js";

function bytesToMb(bytes) {
  return Math.round(bytes / 1024 / 1024);
}

export class ResourceGuard {
  constructor(config) {
    this.config = config;
  }

  async getSnapshot() {
    const cpuCount = os.cpus().length || 1;
    const loadAverage1m = os.loadavg()[0];
    const totalMemoryMb = bytesToMb(os.totalmem());
    const freeMemoryMb = bytesToMb(os.freemem());
    const cpuLoadLimit = Number((cpuCount * this.config.cpuLoadGuardRatio).toFixed(2));
    const ps = await runCommand("ps", ["aux"]);
    const lines = ps.stdout.split("\n").slice(1).filter(Boolean);
    const hashsentryScanProcesses = lines.filter((line) =>
      line.includes("celery") && line.includes("scan_queue")
    ).length;

    return {
      cpuCount,
      loadAverage1m,
      cpuLoadLimit,
      totalMemoryMb,
      freeMemoryMb,
      hashsentryScanProcesses,
      hashsentryActive: hashsentryScanProcesses >= this.config.maxHashSentryScanProcesses
    };
  }

  async evaluate() {
    const snapshot = await this.getSnapshot();
    const reasons = [];

    if (snapshot.loadAverage1m >= snapshot.cpuLoadLimit) {
      reasons.push(
        `load average ${snapshot.loadAverage1m.toFixed(2)} >= limit ${snapshot.cpuLoadLimit.toFixed(2)}`
      );
    }

    if (snapshot.freeMemoryMb <= this.config.minAvailableMemoryMb) {
      reasons.push(
        `free memory ${snapshot.freeMemoryMb}MB <= limit ${this.config.minAvailableMemoryMb}MB`
      );
    }

    if (this.config.skipIfHashSentryActive && snapshot.hashsentryActive) {
      reasons.push(`HashSentry scan workers active: ${snapshot.hashsentryScanProcesses}`);
    }

    return {
      snapshot,
      allowed: reasons.length === 0,
      reasons
    };
  }
}
