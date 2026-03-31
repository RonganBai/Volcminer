export function looksLikeVolcMinerPayload(overview, status) {
  const overviewObj = overview && typeof overview === "object" ? overview : {};
  const statusObj = status && typeof status === "object" ? status : {};

  const minerType = String(overviewObj.minertype ?? overviewObj.minerType ?? "").trim();
  const cgminerVersion = String(overviewObj.cgminer_version ?? overviewObj.cgminerVersion ?? "").trim();
  const hostname = String(overviewObj.hostname ?? "").trim();
  const ipaddress = String(overviewObj.ipaddress ?? "").trim();
  const hasHashrate = [
    statusObj.ghs5s,
    statusObj.ghsav,
    statusObj.hashrateRt,
    statusObj.hashrateAvg
  ].some((value) => String(value ?? "").trim() !== "");
  const hasElapsed = String(statusObj.elapsed ?? "").trim() !== "";
  const hasPoolOrFan = Boolean(statusObj.pools || statusObj.fan || statusObj.chains);

  return Boolean(
    minerType ||
      cgminerVersion ||
      (hostname && ipaddress) ||
      hasHashrate ||
      hasElapsed ||
      hasPoolOrFan
  );
}

export function createNonMinerError(message, details = {}) {
  const error = new Error(message);
  error.code = "NON_MINER_DEVICE";
  error.details = details;
  return error;
}

export function isNonMinerError(error) {
  return error?.code === "NON_MINER_DEVICE";
}
