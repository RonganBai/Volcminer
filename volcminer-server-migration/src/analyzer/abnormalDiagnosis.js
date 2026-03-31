const ISSUE_RULES = [
  {
    code: "POWER_SUPPLY_FAULT",
    category: "power",
    priority: 100,
    matches: ["voltage < 0.75*target_voltage"],
    reason: "The power supply is damaged and output voltage is far below the target range.",
    solution:
      "Replace the power supply and inspect the output cables and input power before powering on again."
  },
  {
    code: "OVER_VOLTAGE",
    category: "power",
    priority: 95,
    matches: ["voltage too high"],
    reason: "Power output voltage is abnormally high and exceeds the safe range.",
    solution:
      "Stop the miner, inspect the power supply output, and replace the power supply if the overvoltage condition persists."
  },
  {
    code: "FAN_ERROR",
    category: "fan",
    priority: 90,
    matches: [
      "fan err",
      "fan error",
      "fan lost",
      "fan abnormal",
      "fan fail",
      "too slow ...0",
      "fan0speed = 0",
      "fan1speed = 0",
      "fan2speed = 0",
      "fan3speed = 0",
      "fan0speedcur:0",
      "fan1speedcur:0",
      "fan2speedcur:0",
      "fan3speedcur:0"
    ],
    reason: "A fan failure or abnormal fan speed was detected.",
    solution:
      "Check fan wiring, fan power, and fan connectors. Replace the failed fan and confirm all fans return to normal speed."
  },
  {
    code: "CHAIN_BREAK",
    category: "hashboard",
    priority: 80,
    matches: [
      "chain break",
      "chain num error",
      "hashboard error",
      "chain find only",
      "wrong asic",
      "configsoftreset:0x00000004",
      "powerstatus:0",
      "operation 0x0"
    ],
    reason: "A hash board chain communication or ASIC detection error was detected.",
    solution:
      "Inspect the affected hash board, ribbon cable, and connector. If fan errors happened first, repair cooling before replacing the hash board.",
    inspectEarlierForCategories: ["fan"]
  },
  {
    code: "OVER_MAX_TEMP",
    category: "temperature",
    priority: 70,
    matches: ["over max temp", "temp is too high", "overheat"],
    reason: "Miner temperature exceeded the safe threshold.",
    solution: "Improve airflow, clean dust, and verify the fan speed and ambient temperature."
  },
  {
    code: "AUTHEN_START_WAIT",
    category: "recovery_wait",
    priority: 60,
    matches: ["Authen Start !!!!!"],
    reason: "The miner restarted authentication after an error and needs a short recovery window.",
    solution:
      "Keep the miner under observation until the next auto scan, then confirm whether the hashrate has recovered."
  },
  {
    code: "ERRORMSG",
    category: "generic",
    priority: 1,
    matches: ["ERRORMSG"],
    reason: "Miner reported an unspecified kernel or hardware error.",
    solution:
      "Open the miner detail page and inspect the full kernel log. Check power, fan speed, and hash board status."
  }
];

const ABNORMAL_GROUP = {
  SOFT: "soft",
  UNKNOWN: "unknown",
  HARD: "hard",
  REBOOT: "reboot"
};

const ABNORMAL_TYPE = {
  ZERO_HASH: "zero_hash",
  REAUTH: "reauth",
  MULTI_RESTART: "multi_restart",
  TEMPERATURE: "temperature",
  DROPPED_BOARD: "dropped_board",
  ALL_BOARD_FAILURE: "all_board_failure",
  POWER: "power",
  FAN: "fan",
  HASHBOARD: "hashboard",
  GENERIC: "generic"
};

function asText(value) {
  if (typeof value === "string") {
    return value;
  }

  if (value && typeof value === "object") {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }

  return String(value ?? "");
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

function normalizeLogText(text) {
  return String(text ?? "").replace(/\r\n/g, "\n").replace(/\r/g, "\n").trim();
}

function parseTime(value) {
  const timestamp = value ? new Date(value).getTime() : NaN;
  return Number.isFinite(timestamp) ? timestamp : null;
}

function trimSnippet(text, maxLength = 240) {
  const normalized = normalizeLogText(text).replace(/\s+/g, " ").trim();
  if (!normalized) {
    return "--";
  }
  return normalized.length <= maxLength ? normalized : `${normalized.slice(0, maxLength)}...`;
}

function createDiagnosis({
  code,
  category,
  reason,
  solution,
  logSnippet,
  detectedAt,
  secondaryCode = null,
  secondaryReason = null
}) {
  return {
    code,
    category,
    reason,
    solution,
    logSnippet: trimSnippet(logSnippet),
    detectedAt,
    secondaryCode,
    secondaryReason
  };
}

function abnormalGroupFromCode(code) {
  if (!code) {
    return null;
  }

  switch (code) {
    case "ZERO_HASH_RESTARTING":
    case "AUTHEN_START_WAIT":
    case "TEMP_FULL_SPEED_RECOVERING":
    case "HASHBOARD_DROPPED_RESTARTING":
    case "HASHBOARD_ALL_FAILED_RESTARTING":
      return ABNORMAL_GROUP.SOFT;
    case "MULTI_RESTART":
      return ABNORMAL_GROUP.REBOOT;
    case "ERRORMSG":
    case "UNKNOWN_ZERO_HASH":
      return ABNORMAL_GROUP.UNKNOWN;
    default:
      return ABNORMAL_GROUP.HARD;
  }
}

function abnormalTypeFromCode(code) {
  if (!code) {
    return null;
  }

  switch (code) {
    case "ZERO_HASH_RESTARTING":
    case "ZERO_HASH_RESTART_FAILED":
      return ABNORMAL_TYPE.ZERO_HASH;
    case "AUTHEN_START_WAIT":
      return ABNORMAL_TYPE.REAUTH;
    case "MULTI_RESTART":
      return ABNORMAL_TYPE.MULTI_RESTART;
    case "TEMP_FULL_SPEED_RECOVERING":
    case "TEMP_FULL_SPEED_PERSISTED":
    case "OVER_MAX_TEMP":
      return ABNORMAL_TYPE.TEMPERATURE;
    case "HASHBOARD_DROPPED_RESTARTING":
    case "HASHBOARD_DROPPED_RESTART_FAILED":
      return ABNORMAL_TYPE.DROPPED_BOARD;
    case "HASHBOARD_ALL_FAILED_RESTARTING":
    case "HASHBOARD_ALL_FAILED_NEEDS_REPLACEMENT":
      return ABNORMAL_TYPE.ALL_BOARD_FAILURE;
    case "POWER_SUPPLY_FAULT":
    case "OVER_VOLTAGE":
    case "POWER_CONTROL_FAULT":
      return ABNORMAL_TYPE.POWER;
    case "FAN_ERROR":
      return ABNORMAL_TYPE.FAN;
    case "CHAIN_BREAK":
      return ABNORMAL_TYPE.HASHBOARD;
    default:
      return ABNORMAL_TYPE.GENERIC;
  }
}

function extractBoardRates(rawStatus) {
  const chains = rawStatus?.chains;
  if (Array.isArray(chains)) {
    return chains
      .map((chain) => ({
        index: toNumber(chain?.index, 0),
        rate: toNumber(chain?.chain_rate ?? chain?.rate, 0)
      }))
      .filter((chain) => chain.index > 0);
  }

  if (typeof chains === "string" && chains.trim()) {
    try {
      const parsed = JSON.parse(chains);
      if (Array.isArray(parsed)) {
        return parsed
          .map((chain) => ({
            index: toNumber(chain?.index, 0),
            rate: toNumber(chain?.chain_rate ?? chain?.rate, 0)
          }))
          .filter((chain) => chain.index > 0);
      }
    } catch {
      return [];
    }
  }

  return [];
}

function matchAuthenRecoveryWait(log) {
  const authRule = ISSUE_RULES.find((rule) => rule.code === "AUTHEN_START_WAIT");
  if (!authRule) {
    return null;
  }

  const normalized = normalizeLogText(log);
  const lines = normalized.split("\n");
  if (lines.length === 0) {
    return null;
  }

  const recentWindowStart = lines.length > 20 ? lines.length - 20 : 0;
  let lineIndex = -1;
  for (let index = lines.length - 1; index >= recentWindowStart; index -= 1) {
    if (lines[index].toLowerCase().includes("authen start !!!!!")) {
      lineIndex = index;
      break;
    }
  }

  if (lineIndex === -1) {
    return null;
  }

  const start = lineIndex - 6 < 0 ? 0 : lineIndex - 6;
  const end = lineIndex + 3 >= lines.length ? lines.length - 1 : lineIndex + 3;
  let authIndex = 0;
  for (let index = 0; index < lineIndex; index += 1) {
    authIndex += lines[index].length + 1;
  }

  return {
    rule: authRule,
    start: authIndex,
    snippet: lines.slice(start, end + 1).join("\n").trim()
  };
}

function countRecentDiagnosisOccurrences(history, code, detectedAt, windowMs = 60 * 60 * 1000) {
  const detectedAtMs = parseTime(detectedAt);
  if (detectedAtMs == null || !Array.isArray(history)) {
    return 0;
  }

  return history.reduce((count, entry) => {
    if (String(entry?.diagnosisCode ?? "").trim() !== code) {
      return count;
    }

    const entryAtMs = parseTime(entry?.diagnosisDetectedAt ?? entry?.at);
    if (entryAtMs == null) {
      return count;
    }

    const delta = detectedAtMs - entryAtMs;
    if (delta >= 0 && delta <= windowMs) {
      return count + 1;
    }

    return count;
  }, 0);
}

function buildRepeatedAuthenWaitDiagnosis(authenRecoveryMatch, detectedAt, history) {
  const recentAuthCount = countRecentDiagnosisOccurrences(
    history,
    "AUTHEN_START_WAIT",
    detectedAt
  );

  if (recentAuthCount + 1 < 3) {
    return null;
  }

  return createDiagnosis({
    code: "MULTI_RESTART",
    category: "reboot",
    reason:
      "The miner has restarted authentication 3 or more times within 1 hour and is likely rebooting repeatedly.",
    solution:
      "Check the power supply, startup stability, and kernel log. Confirm whether the miner keeps entering authentication wait.",
    logSnippet: authenRecoveryMatch.snippet,
    detectedAt
  });
}

function matchAllBoardFailure(log) {
  const normalized = normalizeLogText(log);
  const lines = normalized.split("\n");
  if (lines.length === 0) {
    return null;
  }

  let chunkEnd = lines.length;
  while (chunkEnd > 0) {
    const chunkStart = chunkEnd - 20 < 0 ? 0 : chunkEnd - 20;
    const chunkLines = lines.slice(chunkStart, chunkEnd);
    const hasErrorLine = chunkLines.some((line) =>
      line.trimLeft().toLowerCase().startsWith("errormsg")
    );

    if (hasErrorLine) {
      const chunkText = chunkLines.join("\n");
      const lowerChunk = chunkText.toLowerCase();
      if (
        lowerChunk.includes("chain j0 has wrong asic") &&
        lowerChunk.includes("chain j1 has wrong asic") &&
        lowerChunk.includes("chain j2 has wrong asic")
      ) {
        const absoluteStart = normalized.indexOf(chunkText);
        return {
          rule: {
            code: "HASHBOARD_ALL_FAILED_RESTARTING",
            category: "all_board_failure",
            priority: 85,
            matches: ["chain j0 has wrong asic"],
            reason: "",
            solution: "",
            inspectEarlierForCategories: []
          },
          start: absoluteStart < 0 ? 0 : absoluteStart,
          snippet: chunkText.trim()
        };
      }
    }

    chunkEnd = chunkStart;
  }

  return null;
}

function matchFullSpeedDueToTemperature(log) {
  const normalized = normalizeLogText(log);
  const lines = normalized.split("\n");
  if (lines.length === 0) {
    return null;
  }

  let chunkEnd = lines.length;
  while (chunkEnd > 0) {
    const chunkStart = chunkEnd - 20 < 0 ? 0 : chunkEnd - 20;
    const chunkLines = lines.slice(chunkStart, chunkEnd);
    const chunkText = chunkLines.join("\n");
    if (chunkText.toLowerCase().includes("full speed due to temperature")) {
      const absoluteStart = normalized.indexOf(chunkText);
      return {
        rule: {
          code: "TEMP_FULL_SPEED_RECOVERING",
          category: "temperature",
          priority: 75,
          matches: ["full speed due to temperature"],
          reason: "",
          solution: "",
          inspectEarlierForCategories: []
        },
        start: absoluteStart < 0 ? 0 : absoluteStart,
        snippet: chunkText.trim()
      };
    }

    chunkEnd = chunkStart;
  }

  return null;
}

function findBestRuleMatchInLines(normalized, lines, rules) {
  let bestMatch = null;
  for (let lineIndex = lines.length - 1; lineIndex >= 0; lineIndex -= 1) {
    const line = lines[lineIndex];
    const lowerLine = line.toLowerCase();

    for (const rule of rules) {
      for (const matcher of rule.matches) {
        if (!lowerLine.includes(String(matcher).toLowerCase())) {
          continue;
        }

        const candidate = {
          rule,
          matcher,
          lineIndex,
          start: normalized.indexOf(line),
          snippet: lines.slice(lineIndex - 6 < 0 ? 0 : lineIndex - 6, lineIndex + 3 >= lines.length ? lines.length - 1 : lineIndex + 3 + 1).join("\n").trim()
        };
        if (
          !bestMatch ||
          candidate.rule.priority > bestMatch.rule.priority ||
          (candidate.rule.priority === bestMatch.rule.priority &&
            candidate.matcher.length > (bestMatch.matcher?.length ?? 0)) ||
          (candidate.rule.priority === bestMatch.rule.priority &&
            candidate.matcher.length === (bestMatch.matcher?.length ?? 0) &&
            candidate.lineIndex > bestMatch.lineIndex)
        ) {
          bestMatch = candidate;
        }
      }
    }
  }

  if (!bestMatch) {
    return null;
  }

  return {
    rule: bestMatch.rule,
    start: bestMatch.start,
    snippet: bestMatch.snippet
  };
}

function findChunkedPrimaryMatch(log, rules) {
  const normalized = normalizeLogText(log);
  const lines = normalized.split("\n");
  if (lines.length === 0) {
    return null;
  }

  let bestMatch = null;
  let chunkEnd = lines.length;
  while (chunkEnd > 0) {
    const chunkStart = chunkEnd - 20 < 0 ? 0 : chunkEnd - 20;
    const chunkLines = lines.slice(chunkStart, chunkEnd);
    const hasErrorLine = chunkLines.some((line) =>
      line.trimLeft().toLowerCase().startsWith("errormsg")
    );

    if (hasErrorLine) {
      const chunkText = chunkLines.join("\n");
      const match = findBestRuleMatchInLines(chunkText, chunkLines, rules);
      if (match) {
        const absoluteStart = normalized.indexOf(chunkText);
        const candidate = {
          rule: match.rule,
          start: absoluteStart < 0 ? match.start : absoluteStart + match.start,
          snippet: match.snippet
        };
        if (
          !bestMatch ||
          candidate.rule.priority > bestMatch.rule.priority ||
          (candidate.rule.priority === bestMatch.rule.priority &&
            candidate.start > bestMatch.start)
        ) {
          bestMatch = candidate;
        }
      }
    }

    chunkEnd = chunkStart;
  }

  return bestMatch;
}

function buildUnknownZeroHashDiagnosis(logText, detectedAt) {
  return createDiagnosis({
    code: "UNKNOWN_ZERO_HASH",
    category: "generic",
    reason: "Unknown zero-hash issue",
    solution: "Inspect the miner log, fan speed, temperature, and hash board status.",
    logSnippet: logText,
    detectedAt
  });
}

function buildZeroHashRestartingDiagnosis(detectedAt) {
  return createDiagnosis({
    code: "ZERO_HASH_RESTARTING",
    category: "zero_hash_reboot",
    reason: "Hashrate is abnormal. The miner is marked for reboot verification.",
    solution: "Wait for the next scan and check whether the current hashrate returns to normal.",
    logSnippet: "Current hashrate is 0 while average hashrate is still above 0.",
    detectedAt
  });
}

function buildDroppedBoardRestartingDiagnosis(boardIndexes, detectedAt) {
  return createDiagnosis({
    code: "HASHBOARD_DROPPED_RESTARTING",
    category: "dropped_board",
    reason: "Detected dropped hash board. Miner is rebooting before confirmation.",
    solution: "Wait for the next scan to confirm whether the dropped board has recovered.",
    logSnippet: `BOARD_INDEX:${boardIndexes.join(",")}`,
    detectedAt
  });
}

function buildLogDiagnosis(log, detectedAt, history = []) {
  const normalizedLog = normalizeLogText(log);
  if (!normalizedLog) {
    return null;
  }

  const authenRecoveryMatch = matchAuthenRecoveryWait(normalizedLog);
  if (authenRecoveryMatch) {
    const repeatedAuthenDiagnosis = buildRepeatedAuthenWaitDiagnosis(
      authenRecoveryMatch,
      detectedAt,
      history
    );
    if (repeatedAuthenDiagnosis) {
      return repeatedAuthenDiagnosis;
    }

    const hasEarlierKernelError = normalizedLog
      .slice(0, Math.max(0, authenRecoveryMatch.start))
      .toLowerCase()
      .includes("errormsg");

    return createDiagnosis({
      code: authenRecoveryMatch.rule.code,
      category: authenRecoveryMatch.rule.category,
      reason: authenRecoveryMatch.rule.reason,
      solution: authenRecoveryMatch.rule.solution,
      logSnippet: authenRecoveryMatch.snippet,
      detectedAt,
      secondaryCode: hasEarlierKernelError ? "ERRORMSG" : null,
      secondaryReason: hasEarlierKernelError
        ? "Kernel error occurred before the miner restarted authentication."
        : null
    });
  }

  const allBoardFailureMatch = matchAllBoardFailure(normalizedLog);
  if (allBoardFailureMatch) {
    return createDiagnosis({
      code: "HASHBOARD_ALL_FAILED_RESTARTING",
      category: "all_board_failure",
      reason: "All hash boards reported ASIC errors. Miner is rebooting before confirmation.",
      solution: "Wait for the next scan to confirm whether the miner recovers after reboot.",
      logSnippet: allBoardFailureMatch.snippet,
      detectedAt
    });
  }

  const tempFullSpeedMatch = matchFullSpeedDueToTemperature(normalizedLog);
  if (tempFullSpeedMatch) {
    return createDiagnosis({
      code: "TEMP_FULL_SPEED_RECOVERING",
      category: "temperature",
      reason: "Miner temperature is too high and full-speed protection has been triggered.",
      solution: "Improve cooling and monitor the miner over the next scans until hashrate returns to normal.",
      logSnippet: tempFullSpeedMatch.snippet,
      detectedAt
    });
  }

  const primaryMatch = findChunkedPrimaryMatch(
    normalizedLog,
    ISSUE_RULES.filter((rule) => rule.code !== "AUTHEN_START_WAIT" && rule.code !== "ERRORMSG")
  );

  if (primaryMatch) {
    const primaryRule = primaryMatch.rule;
    if (primaryRule.code === "CHAIN_BREAK" && Array.isArray(primaryRule.inspectEarlierForCategories)) {
      const earlierLog = normalizedLog.slice(0, primaryMatch.start);
      const rootCauseMatch = findChunkedPrimaryMatch(
        earlierLog,
        ISSUE_RULES.filter((rule) =>
          primaryRule.inspectEarlierForCategories.includes(rule.category)
        )
      );

      if (rootCauseMatch) {
        return createDiagnosis({
          code: rootCauseMatch.rule.code,
          category: rootCauseMatch.rule.category,
          reason: rootCauseMatch.rule.reason,
          solution: rootCauseMatch.rule.solution,
          logSnippet: `${rootCauseMatch.snippet}\n...\n${primaryMatch.snippet}`,
          detectedAt,
          secondaryCode: primaryRule.code,
          secondaryReason: primaryRule.reason
        });
      }
    }

    return createDiagnosis({
      code: primaryRule.code,
      category: primaryRule.category,
      reason: primaryRule.reason,
      solution: primaryRule.solution,
      logSnippet: primaryMatch.snippet,
      detectedAt
    });
  }

  const genericMatch = ISSUE_RULES.find((rule) => rule.code === "ERRORMSG");
  if (genericMatch && normalizedLog.toLowerCase().includes("errormsg")) {
    return createDiagnosis({
      code: genericMatch.code,
      category: genericMatch.category,
      reason: genericMatch.reason,
      solution: genericMatch.solution,
      logSnippet: normalizedLog,
      detectedAt
    });
  }

  return null;
}

function isDroppedBoardCandidate(miner) {
  const currentMh = toNumber(miner?.metrics?.hashrateRt, 0);
  if (currentMh <= 0 || currentMh >= 15000 || miner?.metrics?.online !== true) {
    return false;
  }

  return extractBoardRates(miner?.rawStatus).some((chain) => chain.rate <= 0);
}

function droppedBoardIndexes(miner) {
  return extractBoardRates(miner?.rawStatus)
    .filter((chain) => chain.rate <= 0)
    .map((chain) => chain.index)
    .sort((left, right) => left - right);
}

export function shouldInspectKernelLog(miner) {
  const metrics = miner?.metrics ?? {};
  const currentMh = toNumber(metrics.hashrateRt, 0);
  const averageMh = toNumber(metrics.hashrateAvg, 0);
  const maxTemperatureC = toNumber(metrics.maxTemperatureC, 0);
  const averageFanRpm = toNumber(metrics.averageFanRpm, 0);
  const combinedText = `${asText(miner?.monitor?.text)}\n${asText(miner?.rawStatus)}`.toLowerCase();

  if (
    currentMh <= 0 ||
    averageMh <= 0 ||
    (currentMh > 0 && currentMh < 15000) ||
    maxTemperatureC >= 85 ||
    averageFanRpm <= 0
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

export function buildAbnormalDiagnosis(miner, history = []) {
  const detectedAt = miner?.metrics?.lastSeenAt ?? new Date().toISOString();
  const metrics = miner?.metrics ?? {};
  const currentMh = toNumber(metrics.hashrateRt, 0);
  const averageMh = toNumber(metrics.hashrateAvg, 0);
  const kernelLogText = normalizeLogText(miner?.kernelLog?.text ?? "");
  const combinedFallbackText = normalizeLogText(
    [asText(miner?.monitor?.text), asText(miner?.rawStatus)].filter(Boolean).join("\n")
  );

  let diagnosis = null;

  if (metrics.online === true && currentMh <= 0 && averageMh > 0) {
    diagnosis = buildZeroHashRestartingDiagnosis(detectedAt);
  }

  if (!diagnosis && isDroppedBoardCandidate(miner)) {
    diagnosis = buildDroppedBoardRestartingDiagnosis(droppedBoardIndexes(miner), detectedAt);
  }

  if (!diagnosis && kernelLogText) {
    diagnosis = buildLogDiagnosis(kernelLogText, detectedAt, history);
  }

  if (!diagnosis && combinedFallbackText && combinedFallbackText !== kernelLogText) {
    diagnosis = buildLogDiagnosis(combinedFallbackText, detectedAt, history);
  }

  if (!diagnosis && metrics.online === true && currentMh <= 0 && averageMh <= 0) {
    diagnosis = buildUnknownZeroHashDiagnosis(kernelLogText || combinedFallbackText, detectedAt);
  }

  if (!diagnosis && toNumber(metrics.maxTemperatureC, 0) >= 90) {
    diagnosis = createDiagnosis({
      code: "OVER_MAX_TEMP",
      category: "temperature",
      reason: "Miner temperature exceeded the safe threshold.",
      solution: "Improve airflow, clean dust, and verify the fan speed and ambient temperature.",
      logSnippet: `maxTemperatureC=${metrics.maxTemperatureC}`,
      detectedAt
    });
  }

  if (!diagnosis && metrics.online === true && toNumber(metrics.averageFanRpm, 0) <= 0) {
    diagnosis = createDiagnosis({
      code: "FAN_ERROR",
      category: "fan",
      reason: "A fan failure or abnormal fan speed was detected.",
      solution:
        "Check fan wiring, fan power, and fan connectors. Replace the failed fan and confirm all fans return to normal speed.",
      logSnippet: `averageFanRpm=${metrics.averageFanRpm ?? 0}`,
      detectedAt
    });
  }

  return {
    diagnosis,
    abnormalGroup: abnormalGroupFromCode(diagnosis?.code ?? null),
    abnormalType: abnormalTypeFromCode(diagnosis?.code ?? null)
  };
}
