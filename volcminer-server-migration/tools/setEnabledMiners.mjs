import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const inputPath = process.argv[2]
  ? path.resolve(process.cwd(), process.argv[2])
  : path.join(projectRoot, "config", "miners-discovered.generated.json");
const outputPath = process.argv[3]
  ? path.resolve(process.cwd(), process.argv[3])
  : inputPath;
const enabledCount = Math.max(0, Number(process.argv[4] ?? "60"));

const parsed = JSON.parse(fs.readFileSync(inputPath, "utf8"));
if (!Array.isArray(parsed.miners)) {
  throw new Error(`miners array missing: ${inputPath}`);
}

const miners = parsed.miners.map((miner, index) => ({
  ...miner,
  enabled: index < enabledCount
}));

const output = {
  ...parsed,
  updatedAt: new Date().toISOString(),
  enabledCount: Math.min(enabledCount, miners.length),
  miners
};

fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`, "utf8");
console.log(`Enabled first ${output.enabledCount} miners in ${outputPath}`);
