import {execFile} from "node:child_process";
import {existsSync} from "node:fs";
import {resolve} from "node:path";
import {promisify} from "node:util";

import {getEnv, getRequiredEnv} from "./env.mjs";

const execFileAsync = promisify(execFile);

export const PHAROS_ATLANTIC_CHAIN_ID = "688689";
export const PHAROS_ATLANTIC_BLOCKSCOUT_VERIFIER_URL =
  "https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract";

export function isAddressLike(value) {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

export function getContractsDir() {
  const candidates = [
    getEnv("CONTRACTS_WORKSPACE_DIR"),
    getEnv("KEEPER_CONTRACTS_DIR"),
    resolve(process.cwd(), "..", "..", "contracts")
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (existsSync(resolve(candidate, "foundry.toml"))) {
      return resolve(candidate);
    }
  }

  throw new Error("Unable to locate contracts workspace.");
}

function stripAnsi(value) {
  return value.replace(/\u001b\[[0-9;]*m/g, "");
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractHexByLabel(output, label, hexLength) {
  const safeLabel = escapeRegex(label);
  const direct = new RegExp(`${safeLabel}\\s*:?\\s*(0x[a-fA-F0-9]{${hexLength}})`, "i").exec(
    output
  );
  if (direct?.[1]) {
    return direct[1];
  }

  const labelIdx = output.search(new RegExp(`\\b${safeLabel}\\b`, "i"));
  if (labelIdx < 0) {
    throw new Error(`Missing label in deploy output: ${label}`);
  }
  const tail = output.slice(labelIdx, labelIdx + 800);
  const fallback = new RegExp(`0x[a-fA-F0-9]{${hexLength}}`).exec(tail);
  if (fallback?.[0]) {
    return fallback[0];
  }
  throw new Error(`Missing value for deploy label: ${label}`);
}

function extractTxHash(output) {
  const patterns = [
    /transaction hash:\s*(0x[a-fA-F0-9]{64})/i,
    /tx hash:\s*(0x[a-fA-F0-9]{64})/i,
    /hash:\s*(0x[a-fA-F0-9]{64})/i
  ];
  for (const pattern of patterns) {
    const match = pattern.exec(output);
    if (match?.[1]) return match[1];
  }
  return null;
}

function extractSkipReason(output) {
  const match = output.match(/skip:\s*([^\n\r]+)/i);
  return match?.[1]?.trim() ?? null;
}

function extractRate(output, label) {
  const pattern = new RegExp(`${label}[^0-9]*([0-9]+)`, "i");
  const match = output.match(pattern);
  return match?.[1] ?? null;
}

export async function runDeployForge({owner, requestedBy, assetAddress}) {
  const rpcUrl = getRequiredEnv("PHAROS_ATLANTIC_RPC_URL");
  const deployerPrivateKey = getRequiredEnv("DEPLOYER_PRIVATE_KEY");
  const trancheFactory = getRequiredEnv("TRANCHE_FACTORY");

  if (!isAddressLike(owner)) throw new Error("owner must be a valid EVM address.");
  if (!isAddressLike(requestedBy)) throw new Error("requestedBy must be a valid EVM address.");
  if (!isAddressLike(assetAddress)) throw new Error("assetAddress must be a valid EVM address.");
  if (!isAddressLike(trancheFactory)) throw new Error("TRANCHE_FACTORY must be a valid EVM address.");

  const operator = getEnv("DEPLOYER_OPERATOR", requestedBy);
  const guardian = getEnv("DEPLOYER_GUARDIAN", requestedBy);
  const strategist = getEnv("DEPLOYER_STRATEGIST", owner);
  const managerAdmin = getEnv("DEPLOYER_MANAGER_ADMIN", owner);

  if (!isAddressLike(operator)) throw new Error("DEPLOYER_OPERATOR is invalid.");
  if (!isAddressLike(guardian)) throw new Error("DEPLOYER_GUARDIAN is invalid.");
  if (!isAddressLike(strategist)) throw new Error("DEPLOYER_STRATEGIST is invalid.");
  if (!isAddressLike(managerAdmin)) throw new Error("DEPLOYER_MANAGER_ADMIN is invalid.");

  const contractsDir = getContractsDir();
  const args = [
    "script",
    "script/DeployTrancheVault.s.sol",
    "--broadcast",
    "--verify",
    "--rpc-url",
    rpcUrl,
    "--chain-id",
    PHAROS_ATLANTIC_CHAIN_ID,
    "--verifier",
    "blockscout",
    "--verifier-url",
    PHAROS_ATLANTIC_BLOCKSCOUT_VERIFIER_URL
  ];

  const command = `forge ${args.join(" ")}`;
  const {stdout, stderr} = await execFileAsync("forge", args, {
    cwd: contractsDir,
    env: {
      ...process.env,
      PRIVATE_KEY: deployerPrivateKey,
      OWNER: owner,
      OPERATOR: operator,
      GUARDIAN: guardian,
      STRATEGIST: strategist,
      MANAGER_ADMIN: managerAdmin,
      TRANCHE_FACTORY: trancheFactory,
      ASSET: assetAddress
    },
    maxBuffer: 1024 * 1024 * 16
  });

  const output = stripAnsi(`${stdout}\n${stderr}`);
  return {
    command,
    result: {
      paramsHash: extractHexByLabel(output, "TrancheParamsHash", 64),
      txHash: extractTxHash(output),
      trancheRegistry: extractHexByLabel(output, "TrancheRegistry", 40),
      trancheController: extractHexByLabel(output, "TrancheController", 40),
      seniorToken: extractHexByLabel(output, "SeniorToken", 40),
      juniorToken: extractHexByLabel(output, "JuniorToken", 40),
      boringVault: extractHexByLabel(output, "BoringVault", 40),
      teller: extractHexByLabel(output, "Teller", 40),
      manager: extractHexByLabel(output, "Manager", 40),
      accountant: extractHexByLabel(output, "Accountant", 40)
    }
  };
}

function getUpdaterPrivateKey() {
  const key = getEnv(
    "ACCOUNTANT_UPDATER_PRIVATE_KEY",
    getEnv("PRIVATE_KEY", getEnv("DEPLOYER_PRIVATE_KEY"))
  );
  if (!key) {
    throw new Error(
      "Missing updater key. Set ACCOUNTANT_UPDATER_PRIVATE_KEY or PRIVATE_KEY."
    );
  }
  return key;
}

export async function runUpdateRateForge({
  vaultAddress,
  accountantAddress,
  assetAddress,
  minUpdateBps,
  allowPauseUpdate
}) {
  const rpcUrl = getRequiredEnv("PHAROS_ATLANTIC_RPC_URL");
  if (!isAddressLike(vaultAddress)) throw new Error("vaultAddress must be a valid EVM address.");
  if (!isAddressLike(accountantAddress)) {
    throw new Error("accountantAddress must be a valid EVM address.");
  }
  if (!isAddressLike(assetAddress)) throw new Error("assetAddress must be a valid EVM address.");

  const minUpdate = Number(minUpdateBps ?? 1);
  if (!Number.isFinite(minUpdate) || minUpdate < 0 || minUpdate > 10_000) {
    throw new Error("minUpdateBps must be between 0 and 10000.");
  }

  const contractsDir = getContractsDir();
  const updaterPrivateKey = getUpdaterPrivateKey();
  const args = [
    "script",
    "script/UpdateExchangeRate.s.sol:UpdateExchangeRate",
    "--broadcast",
    "--rpc-url",
    rpcUrl,
    "--chain-id",
    PHAROS_ATLANTIC_CHAIN_ID
  ];
  const command = `forge ${args.join(" ")}`;

  const {stdout, stderr} = await execFileAsync("forge", args, {
    cwd: contractsDir,
    env: {
      ...process.env,
      PRIVATE_KEY: updaterPrivateKey,
      VAULT: vaultAddress,
      ACCOUNTANT: accountantAddress,
      ASSET: assetAddress,
      MIN_UPDATE_BPS: String(Math.floor(minUpdate)),
      ALLOW_PAUSE_UPDATE: allowPauseUpdate ? "true" : "false"
    },
    maxBuffer: 1024 * 1024 * 8
  });

  const output = stripAnsi(`${stdout}\n${stderr}`);
  const skipReason = extractSkipReason(output);
  return {
    command,
    result: {
      vaultAddress,
      accountantAddress,
      assetAddress,
      command,
      txHash: extractTxHash(output),
      skipped: skipReason !== null,
      skipReason,
      currentRate: extractRate(output, "currentRate"),
      nextRate: extractRate(output, "nextRate")
    }
  };
}

