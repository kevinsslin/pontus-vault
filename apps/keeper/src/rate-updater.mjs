import {execFile} from "node:child_process";
import {resolve} from "node:path";
import {promisify} from "node:util";

const execFileAsync = promisify(execFile);

const REQUIRED_ENV_KEYS = ["PHAROS_ATLANTIC_RPC_URL", "PRIVATE_KEY", "VAULT", "ACCOUNTANT", "ASSET"];
const DEFAULT_INTERVAL_MS = 5 * 60 * 1000;

function getRequiredEnv(name) {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing required env: ${name}`);
  }
  return value.trim();
}

function getContractsDir() {
  const configured = process.env.KEEPER_CONTRACTS_DIR;
  if (configured && configured.trim().length > 0) {
    return resolve(configured.trim());
  }
  return resolve(process.cwd(), "..", "..", "contracts");
}

async function runUpdateOnce(contractsDir) {
  const args = [
    "script",
    "script/UpdateExchangeRate.s.sol:UpdateExchangeRate",
    "--broadcast",
    "--rpc-url",
    getRequiredEnv("PHAROS_ATLANTIC_RPC_URL"),
    "--chain-id",
    "688689"
  ];

  const {stdout, stderr} = await execFileAsync("forge", args, {
    cwd: contractsDir,
    env: process.env
  });

  if (stdout.trim().length > 0) {
    console.log(stdout.trim());
  }
  if (stderr.trim().length > 0) {
    console.error(stderr.trim());
  }
}

function parseIntervalMs() {
  const raw = process.env.KEEPER_INTERVAL_MS;
  if (!raw) return DEFAULT_INTERVAL_MS;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`Invalid KEEPER_INTERVAL_MS: ${raw}`);
  }
  return parsed;
}

async function main() {
  for (const key of REQUIRED_ENV_KEYS) {
    getRequiredEnv(key);
  }

  const contractsDir = getContractsDir();
  const intervalMs = parseIntervalMs();
  const runOnce = (process.env.KEEPER_RUN_ONCE ?? "false").toLowerCase() === "true";

  let running = false;

  const tick = async () => {
    if (running) {
      console.warn("[keeper] skip tick: previous run still in progress");
      return;
    }

    running = true;
    const startedAt = new Date().toISOString();
    console.log(`[keeper] tick start ${startedAt}`);

    try {
      await runUpdateOnce(contractsDir);
      const finishedAt = new Date().toISOString();
      console.log(`[keeper] tick success ${finishedAt}`);
    } catch (error) {
      const finishedAt = new Date().toISOString();
      console.error(`[keeper] tick failed ${finishedAt}`);
      console.error(error instanceof Error ? error.message : String(error));
    } finally {
      running = false;
    }
  };

  await tick();
  if (runOnce) return;

  setInterval(() => {
    void tick();
  }, intervalMs);
}

void main();
