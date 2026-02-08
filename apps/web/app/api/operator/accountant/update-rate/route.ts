import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { promisify } from "node:util";

import { NextResponse } from "next/server";
import {
  OperatorUpdateExchangeRateRequestSchema,
  OperatorUpdateExchangeRateResponseSchema,
  PHAROS_ATLANTIC,
  type OperatorUpdateExchangeRateResponse,
} from "@pti/shared";

import { resolveDataSource } from "../../../../../lib/constants/runtime";

const execFileAsync = promisify(execFile);
const CHAIN_ID = String(PHAROS_ATLANTIC.chainId);

type LocalUpdateParams = {
  vaultAddress: string;
  accountantAddress: string;
  assetAddress: string;
  minUpdateBps: number;
  allowPauseUpdate: boolean;
};

type RouteUpdateExecution = {
  command: string;
  result: OperatorUpdateExchangeRateResponse;
};

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

function extractSkipReason(output: string): string | null {
  const match = output.match(/skip:\s*([^\n\r]+)/i);
  return match?.[1]?.trim() ?? null;
}

function extractRate(output: string, label: "currentRate" | "nextRate"): string | null {
  const pattern = new RegExp(`${label}[^0-9]*([0-9]+)`, "i");
  const match = output.match(pattern);
  return match?.[1] ?? null;
}

function resolveContractsDir(): string {
  const contractsDir = process.env.CONTRACTS_WORKSPACE_DIR ?? process.env.KEEPER_CONTRACTS_DIR ?? "";
  if (!contractsDir) {
    throw new Error("Missing CONTRACTS_WORKSPACE_DIR.");
  }
  if (!existsSync(`${contractsDir}/foundry.toml`)) {
    throw new Error("CONTRACTS_WORKSPACE_DIR is invalid (foundry.toml not found).");
  }
  return contractsDir;
}

function resolveUpdaterPrivateKey(): string {
  const key =
    process.env.ACCOUNTANT_UPDATER_PRIVATE_KEY ??
    process.env.PRIVATE_KEY ??
    process.env.DEPLOYER_PRIVATE_KEY ??
    "";
  if (!key) {
    throw new Error("Missing updater private key. Set ACCOUNTANT_UPDATER_PRIVATE_KEY or PRIVATE_KEY.");
  }
  return key;
}

async function runLocalUpdateRate(params: LocalUpdateParams): Promise<RouteUpdateExecution> {
  const rpcUrl = process.env.PHAROS_ATLANTIC_RPC_URL;
  if (!rpcUrl) {
    throw new Error("Missing PHAROS_ATLANTIC_RPC_URL.");
  }

  const updaterPrivateKey = resolveUpdaterPrivateKey();
  const contractsDir = resolveContractsDir();

  const args = [
    "script",
    "script/UpdateExchangeRate.s.sol:UpdateExchangeRate",
    "--broadcast",
    "--rpc-url",
    rpcUrl,
    "--chain-id",
    CHAIN_ID,
  ];

  const command = `forge ${args.join(" ")}`;
  const { stdout, stderr } = await execFileAsync("forge", args, {
    cwd: contractsDir,
    env: {
      ...process.env,
      PRIVATE_KEY: updaterPrivateKey,
      VAULT: params.vaultAddress,
      ACCOUNTANT: params.accountantAddress,
      ASSET: params.assetAddress,
      MIN_UPDATE_BPS: String(params.minUpdateBps),
      ALLOW_PAUSE_UPDATE: params.allowPauseUpdate ? "true" : "false",
    },
    maxBuffer: 1024 * 1024 * 8,
  });

  const cleanOutput = stripAnsi(`${stdout}\n${stderr}`);
  const skipReason = extractSkipReason(cleanOutput);
  const result = OperatorUpdateExchangeRateResponseSchema.parse({
    vaultAddress: params.vaultAddress,
    accountantAddress: params.accountantAddress,
    assetAddress: params.assetAddress,
    command,
    txHash: extractTxHash(cleanOutput),
    skipped: skipReason !== null,
    skipReason,
    currentRate: extractRate(cleanOutput, "currentRate"),
    nextRate: extractRate(cleanOutput, "nextRate"),
  });

  return { command, result };
}

function resolveRemoteUpdateRateUrl(baseUrl: string): string {
  const normalized = baseUrl.trim().replace(/\/+$/, "");
  if (!normalized) {
    return "";
  }
  if (normalized.endsWith("/update-rate")) {
    return normalized;
  }
  return `${normalized}/update-rate`;
}

async function runRemoteUpdateRate(params: LocalUpdateParams): Promise<RouteUpdateExecution> {
  const remoteExecutorBaseUrl = process.env.DEPLOY_EXECUTOR_URL ?? "";
  const remoteUrl = resolveRemoteUpdateRateUrl(remoteExecutorBaseUrl);
  if (!remoteUrl) {
    return runLocalUpdateRate(params);
  }

  const executorToken = process.env.DEPLOY_EXECUTOR_TOKEN ?? "";
  const response = await fetch(remoteUrl, {
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
    const message = typeof payload?.error === "string" ? payload.error : "Remote rate update failed.";
    throw new Error(message);
  }

  const parsed = payload as RouteUpdateExecution;
  if (typeof parsed?.command !== "string") {
    throw new Error("Remote rate update response is missing command.");
  }
  return {
    command: parsed.command,
    result: OperatorUpdateExchangeRateResponseSchema.parse(parsed.result),
  };
}

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = OperatorUpdateExchangeRateRequestSchema.parse(body);
    assertOperatorPermission(parsed.requestedBy);

    const { result } = await runRemoteUpdateRate({
      vaultAddress: parsed.vaultAddress,
      accountantAddress: parsed.accountantAddress,
      assetAddress: parsed.assetAddress,
      minUpdateBps: parsed.minUpdateBps ?? 1,
      allowPauseUpdate: parsed.allowPauseUpdate ?? false,
    });

    return NextResponse.json(OperatorUpdateExchangeRateResponseSchema.parse(result));
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to update exchange rate.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
