import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const root = path.resolve(scriptDir, "../../..");

const ABI_SOURCES = [
  {
    source: path.join(root, "contracts/out/TrancheRegistry.sol/TrancheRegistry.json"),
    target: path.join(root, "apps/indexer/abis/TrancheRegistry.json"),
    label: "TrancheRegistry",
  },
  {
    source: path.join(root, "contracts/out/TrancheController.sol/TrancheController.json"),
    target: path.join(root, "apps/indexer/abis/TrancheController.json"),
    label: "TrancheController",
  },
  {
    source: path.join(root, "contracts/out/ERC20.sol/ERC20.json"),
    target: path.join(root, "apps/indexer/abis/ERC20.json"),
    label: "ERC20",
    select: (abi) => abi.filter((item) => item?.type === "function" && item?.name === "totalSupply"),
  },
];

async function syncAbi({ source, target, label, select }) {
  const raw = await readFile(source, "utf8");
  const parsed = JSON.parse(raw);

  if (!Array.isArray(parsed.abi)) {
    throw new Error(`Missing abi array in ${source}`);
  }

  const selectedAbi = typeof select === "function" ? select(parsed.abi) : parsed.abi;
  if (!Array.isArray(selectedAbi) || selectedAbi.length === 0) {
    throw new Error(`No ABI fragments selected for ${label}`);
  }

  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, `${JSON.stringify(selectedAbi, null, 2)}\n`, "utf8");
  return `${label}: ${path.relative(root, source)} -> ${path.relative(root, target)}`;
}

async function main() {
  const results = await Promise.all(ABI_SOURCES.map((entry) => syncAbi(entry)));
  for (const line of results) {
    console.log(`[abi:sync] ${line}`);
  }
}

main().catch((error) => {
  console.error("[abi:sync] failed", error);
  process.exitCode = 1;
});
