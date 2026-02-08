import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { promisify } from "node:util";

import { NextResponse } from "next/server";
import {
  normalizeVaultUiConfig,
  OperatorDeployVaultRequestSchema,
  OperatorDeployVaultResponseSchema,
  PHAROS_ATLANTIC,
} from "@pti/shared";

import { resolveDataSource, resolveLiveDataRuntimeConfig } from "../../../../lib/constants/runtime";
import { upsertVaultRegistryRow } from "../../../../lib/data/supabase";

const execFileAsync = promisify(execFile);
const BLOCKSCOUT_VERIFIER_URL = PHAROS_ATLANTIC.blockscoutVerifierUrl;
const CHAIN_ID = String(PHAROS_ATLANTIC.chainId);

type RouteDeployResult = {
  paramsHash: string;
  txHash: string | null;
  trancheRegistry: string;
  trancheController: string;
  seniorToken: string;
  juniorToken: string;
  boringVault: string;
  teller: string;
  manager: string;
  accountant: string;
};

type RouteDeployExecution = {
  command: string;
  result: RouteDeployResult;
};

export const dynamic = "force-dynamic";
export const revalidate = 0;

function isAddressLike(value: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

function getOperatorAllowlist(): Set<string> {
  return new Set(
    (process.env.OPERATOR_ADMIN_ADDRESSES ?? "")
      .split(",")
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item.length > 0)
  );
}

function assertOperatorPermission(requestedBy: string) {
  const allowlist = getOperatorAllowlist();
  const normalized = requestedBy.trim().toLowerCase();
  const source = resolveDataSource();

  if (!isAddressLike(normalized)) {
    throw new Error("requestedBy must be a valid EVM address.");
  }

  if (allowlist.size === 0 && source === "demo") {
    return;
  }

  if (allowlist.size === 0) {
    throw new Error("Operator allowlist is required in live mode.");
  }

  if (!allowlist.has(normalized)) {
    throw new Error("Operator wallet is not authorized.");
  }
}

function stripAnsi(value: string): string {
  return value.replace(/\u001b\[[0-9;]*m/g, "");
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractHexByLabel(output: string, label: string, hexLength: number): string {
  const safeLabel = escapeRegex(label);
  const direct = new RegExp(`${safeLabel}\\s*:?\\s*(0x[a-fA-F0-9]{${hexLength}})`, "i").exec(output);
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

function extractTxHash(output: string): string | null {
  const patterns = [
    /transaction hash:\s*(0x[a-fA-F0-9]{64})/i,
    /tx hash:\s*(0x[a-fA-F0-9]{64})/i,
    /hash:\s*(0x[a-fA-F0-9]{64})/i,
  ];

  for (const pattern of patterns) {
    const match = pattern.exec(output);
    if (match?.[1]) {
      return match[1];
    }
  }

  return null;
}

function resolveContractsDir(): string {
  const contractsDir = process.env.CONTRACTS_WORKSPACE_DIR ?? "";
  if (!contractsDir) {
    throw new Error("Missing CONTRACTS_WORKSPACE_DIR.");
  }
  if (!existsSync(`${contractsDir}/foundry.toml`)) {
    throw new Error("CONTRACTS_WORKSPACE_DIR is invalid (foundry.toml not found).");
  }
  return contractsDir;
}

async function fetchTxBlockNumber(txHash: string | null): Promise<number | null> {
  if (!txHash) {
    return null;
  }

  const rpcUrl = process.env.PHAROS_ATLANTIC_RPC_URL ?? "";
  if (!rpcUrl) {
    return null;
  }

  try {
    const response = await fetch(rpcUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getTransactionReceipt",
        params: [txHash],
      }),
      cache: "no-store",
    });
    const payload = (await response.json()) as {
      result?: { blockNumber?: string | null } | null;
    };
    const blockHex = payload?.result?.blockNumber;
    if (!blockHex) {
      return null;
    }
    const blockNumber = Number.parseInt(blockHex, 16);
    return Number.isFinite(blockNumber) ? blockNumber : null;
  } catch {
    return null;
  }
}

async function runDeployScript(params: {
  owner: string;
  requestedBy: string;
  assetAddress: string;
}): Promise<RouteDeployExecution> {
  const rpcUrl = process.env.PHAROS_ATLANTIC_RPC_URL;
  const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;
  const trancheFactory = process.env.TRANCHE_FACTORY;

  if (!rpcUrl) throw new Error("Missing PHAROS_ATLANTIC_RPC_URL.");
  if (!deployerPrivateKey) throw new Error("Missing DEPLOYER_PRIVATE_KEY.");
  if (!trancheFactory || !isAddressLike(trancheFactory)) {
    throw new Error("Missing or invalid TRANCHE_FACTORY.");
  }
  if (!isAddressLike(params.assetAddress)) {
    throw new Error("assetAddress must be a valid EVM address.");
  }

  const operator = process.env.DEPLOYER_OPERATOR ?? params.requestedBy;
  const guardian = process.env.DEPLOYER_GUARDIAN ?? params.requestedBy;
  const strategist = process.env.DEPLOYER_STRATEGIST ?? params.owner;
  const managerAdmin = process.env.DEPLOYER_MANAGER_ADMIN ?? params.owner;

  if (!isAddressLike(operator)) throw new Error("DEPLOYER_OPERATOR is invalid.");
  if (!isAddressLike(guardian)) throw new Error("DEPLOYER_GUARDIAN is invalid.");
  if (!isAddressLike(strategist)) throw new Error("DEPLOYER_STRATEGIST is invalid.");
  if (!isAddressLike(managerAdmin)) throw new Error("DEPLOYER_MANAGER_ADMIN is invalid.");

  const contractsDir = resolveContractsDir();
  const args = [
    "script",
    "script/DeployTrancheVault.s.sol",
    "--broadcast",
    "--verify",
    "--rpc-url",
    rpcUrl,
    "--chain-id",
    CHAIN_ID,
    "--verifier",
    "blockscout",
    "--verifier-url",
    BLOCKSCOUT_VERIFIER_URL,
  ];

  const command = `forge ${args.join(" ")}`;
  const { stdout, stderr } = await execFileAsync("forge", args, {
    cwd: contractsDir,
    env: {
      ...process.env,
      PRIVATE_KEY: deployerPrivateKey,
      OWNER: params.owner,
      OPERATOR: operator,
      GUARDIAN: guardian,
      STRATEGIST: strategist,
      MANAGER_ADMIN: managerAdmin,
      TRANCHE_FACTORY: trancheFactory,
      ASSET: params.assetAddress,
    },
    maxBuffer: 1024 * 1024 * 16,
  });

  const cleanOutput = stripAnsi(`${stdout}\n${stderr}`);
  const result: RouteDeployResult = {
    paramsHash: extractHexByLabel(cleanOutput, "TrancheParamsHash", 64),
    txHash: extractTxHash(cleanOutput),
    trancheRegistry: extractHexByLabel(cleanOutput, "TrancheRegistry", 40),
    trancheController: extractHexByLabel(cleanOutput, "TrancheController", 40),
    seniorToken: extractHexByLabel(cleanOutput, "SeniorToken", 40),
    juniorToken: extractHexByLabel(cleanOutput, "JuniorToken", 40),
    boringVault: extractHexByLabel(cleanOutput, "BoringVault", 40),
    teller: extractHexByLabel(cleanOutput, "Teller", 40),
    manager: extractHexByLabel(cleanOutput, "Manager", 40),
    accountant: extractHexByLabel(cleanOutput, "Accountant", 40),
  };

  return { command, result };
}

function assertDeployResultShape(value: unknown): RouteDeployExecution {
  if (!value || typeof value !== "object") {
    throw new Error("Remote deploy executor returned invalid payload.");
  }
  const parsed = value as RouteDeployExecution;
  if (typeof parsed.command !== "string") {
    throw new Error("Remote deploy executor is missing command.");
  }
  const result = parsed.result as RouteDeployResult;
  type AddressField =
    | "trancheRegistry"
    | "trancheController"
    | "seniorToken"
    | "juniorToken"
    | "boringVault"
    | "teller"
    | "manager"
    | "accountant";
  const requiredAddresses: AddressField[] = [
    "trancheRegistry",
    "trancheController",
    "seniorToken",
    "juniorToken",
    "boringVault",
    "teller",
    "manager",
    "accountant",
  ];
  if (!result || typeof result !== "object") {
    throw new Error("Remote deploy executor is missing deploy result.");
  }
  if (!/^0x[a-fA-F0-9]{64}$/.test(result.paramsHash)) {
    throw new Error("Remote deploy executor returned invalid paramsHash.");
  }
  for (const key of requiredAddresses) {
    if (!isAddressLike(result[key])) {
      throw new Error(`Remote deploy executor returned invalid ${key}.`);
    }
  }
  if (result.txHash !== null && result.txHash !== undefined) {
    if (!/^0x[a-fA-F0-9]{64}$/.test(result.txHash)) {
      throw new Error("Remote deploy executor returned invalid txHash.");
    }
  }
  return {
    command: parsed.command,
    result: {
      ...result,
      txHash: result.txHash ?? null,
    },
  };
}

async function runDeploy(
  params: {
    owner: string;
    requestedBy: string;
    assetAddress: string;
  }
): Promise<RouteDeployExecution> {
  const remoteExecutorUrl = process.env.DEPLOY_EXECUTOR_URL ?? "";
  if (!remoteExecutorUrl) {
    return runDeployScript(params);
  }

  const executorToken = process.env.DEPLOY_EXECUTOR_TOKEN ?? "";
  const response = await fetch(remoteExecutorUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(executorToken ? { authorization: `Bearer ${executorToken}` } : {}),
    },
    body: JSON.stringify(params),
    cache: "no-store",
  });
  const payload = await response.json();
  if (!response.ok) {
    const message = typeof payload?.error === "string" ? payload.error : "Remote deploy executor failed.";
    throw new Error(message);
  }
  return assertDeployResultShape(payload);
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = OperatorDeployVaultRequestSchema.parse(body);
    const requestedBy = parsed.requestedBy.toLowerCase();
    const owner = (parsed.owner ?? parsed.requestedBy).toLowerCase();

    assertOperatorPermission(requestedBy);
    if (!isAddressLike(owner)) {
      throw new Error("owner must be a valid EVM address.");
    }

    const { command, result } = await runDeploy({
      owner,
      requestedBy,
      assetAddress: parsed.assetAddress,
    });
    const trancheFactoryEnv = process.env.TRANCHE_FACTORY ?? "";
    const deploymentBlock = await fetchTxBlockNumber(result.txHash);

    const runtime = resolveLiveDataRuntimeConfig();
    await upsertVaultRegistryRow(runtime.supabaseUrl, runtime.supabaseKey, {
      vaultId: parsed.vaultId,
      chain: parsed.chain,
      name: parsed.name,
      route: parsed.route,
      assetSymbol: parsed.assetSymbol,
      assetAddress: parsed.assetAddress,
      controllerAddress: result.trancheController,
      seniorTokenAddress: result.seniorToken,
      juniorTokenAddress: result.juniorToken,
      vaultAddress: result.boringVault,
      tellerAddress: result.teller,
      managerAddress: result.manager,
      uiConfig: {
        ...normalizeVaultUiConfig(parsed.uiConfig),
        paramsHash: result.paramsHash,
        owner,
        deployTxHash: result.txHash,
        accountantAddress: result.accountant,
        trancheRegistry: result.trancheRegistry,
        trancheFactory: isAddressLike(trancheFactoryEnv) ? trancheFactoryEnv : undefined,
        indexerStartBlock: deploymentBlock ?? undefined,
      },
    });

    return NextResponse.json(
      OperatorDeployVaultResponseSchema.parse({
        vaultId: parsed.vaultId,
        paramsHash: result.paramsHash,
        txHash: result.txHash,
        chain: parsed.chain,
        addresses: {
          trancheRegistry: result.trancheRegistry,
          trancheController: result.trancheController,
          seniorToken: result.seniorToken,
          juniorToken: result.juniorToken,
          boringVault: result.boringVault,
          teller: result.teller,
          manager: result.manager,
          accountant: result.accountant,
        },
        command,
      })
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Deploy failed.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
