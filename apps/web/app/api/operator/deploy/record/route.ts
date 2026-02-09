import { NextResponse } from "next/server";
import { z } from "zod";

import { normalizeVaultUiConfig } from "@pti/shared";

import { resolveDataSource, resolveLiveDataRuntimeConfig } from "../../../../../lib/constants/runtime";
import { getVaultRegistryRow, upsertVaultRegistryRow } from "../../../../../lib/data/supabase";
import { getOperatorOperation, updateOperatorOperationStep } from "../../../../../lib/operator/store";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const RecordDeployBodySchema = z.object({
  operationId: z.string().min(1),
  stepIndex: z.number().int().min(0),
  vaultId: z.string().min(1),
  operatorAddress: z.string().min(1),
  forgeOutput: z.string().min(1),
});

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

function assertOperatorPermission(operatorAddress: string) {
  const source = resolveDataSource();
  const allowlist = getOperatorAllowlist();
  const normalized = operatorAddress.trim().toLowerCase();
  if (!isAddressLike(normalized)) {
    throw new Error("operatorAddress must be a valid EVM address.");
  }
  if (allowlist.size === 0 && source !== "demo") {
    throw new Error("Operator allowlist is required (OPERATOR_ADMIN_ADDRESSES).");
  }
  if (allowlist.size > 0 && !allowlist.has(normalized)) {
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
  if (direct?.[1]) return direct[1];
  const labelIdx = output.search(new RegExp(`\\b${safeLabel}\\b`, "i"));
  if (labelIdx < 0) throw new Error(`Missing label in forge output: ${label}`);
  const tail = output.slice(labelIdx, labelIdx + 800);
  const fallback = new RegExp(`0x[a-fA-F0-9]{${hexLength}}`).exec(tail);
  if (fallback?.[0]) return fallback[0];
  throw new Error(`Missing value for label: ${label}`);
}

function extractTxHash(output: string): string | null {
  const patterns = [
    /transaction hash:\s*(0x[a-fA-F0-9]{64})/i,
    /tx hash:\s*(0x[a-fA-F0-9]{64})/i,
    /hash:\s*(0x[a-fA-F0-9]{64})/i,
  ];
  for (const pattern of patterns) {
    const match = pattern.exec(output);
    if (match?.[1]) return match[1];
  }
  return null;
}

async function fetchTxBlockNumber(txHash: string | null): Promise<number | null> {
  if (!txHash) return null;
  const rpcUrl = process.env.PHAROS_ATLANTIC_RPC_URL ?? "";
  if (!rpcUrl) return null;
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
    const payload = (await response.json()) as { result?: { blockNumber?: string | null } | null };
    const blockHex = payload?.result?.blockNumber;
    if (!blockHex) return null;
    const blockNumber = Number.parseInt(blockHex, 16);
    return Number.isFinite(blockNumber) ? blockNumber : null;
  } catch {
    return null;
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const parsed = RecordDeployBodySchema.parse(body);
    assertOperatorPermission(parsed.operatorAddress);

    const operation = await getOperatorOperation(parsed.operationId);
    if (!operation) {
      return NextResponse.json({ error: "Operation not found." }, { status: 404 });
    }
    if (operation.operation.jobType !== "DEPLOY_VAULT") {
      return NextResponse.json({ error: "Operation is not a deploy vault job." }, { status: 400 });
    }
    const requestedBy = (operation.operation.requestedBy ?? "").toLowerCase();
    if (requestedBy !== parsed.operatorAddress.trim().toLowerCase()) {
      return NextResponse.json({ error: "Operator does not match operation requestedBy." }, { status: 403 });
    }

    const step = operation.steps.find((s) => s.stepIndex === parsed.stepIndex);
    if (!step || step.label !== "Execute deployment transaction") {
      return NextResponse.json({ error: "Step not found or not the deploy step." }, { status: 400 });
    }
    if (!["CREATED", "RUNNING", "BROADCASTED"].includes(step.status)) {
      return NextResponse.json({ error: "Step already completed or failed." }, { status: 400 });
    }

    const cleanOutput = stripAnsi(parsed.forgeOutput);
    const txHash = extractTxHash(cleanOutput);
    const paramsHash = extractHexByLabel(cleanOutput, "TrancheParamsHash", 64);
    const trancheRegistry = extractHexByLabel(cleanOutput, "TrancheRegistry", 40);
    const trancheController = extractHexByLabel(cleanOutput, "TrancheController", 40);
    const seniorToken = extractHexByLabel(cleanOutput, "SeniorToken", 40);
    const juniorToken = extractHexByLabel(cleanOutput, "JuniorToken", 40);
    const boringVault = extractHexByLabel(cleanOutput, "BoringVault", 40);
    const teller = extractHexByLabel(cleanOutput, "Teller", 40);
    const manager = extractHexByLabel(cleanOutput, "Manager", 40);
    const accountant = extractHexByLabel(cleanOutput, "Accountant", 40);

    const runtime = resolveLiveDataRuntimeConfig();
    const vaultRow = await getVaultRegistryRow(runtime.supabaseUrl, runtime.supabaseKey, parsed.vaultId);
    if (!vaultRow) {
      return NextResponse.json({ error: "Vault not found in registry." }, { status: 404 });
    }

    const trancheFactoryEnv = process.env.TRANCHE_FACTORY ?? "";
    const deploymentBlock = await fetchTxBlockNumber(txHash);
    const baseUiConfig = normalizeVaultUiConfig(vaultRow.ui_config);

    await upsertVaultRegistryRow(runtime.supabaseUrl, runtime.supabaseKey, {
      vaultId: vaultRow.vault_id,
      chain: vaultRow.chain,
      name: vaultRow.name,
      assetSymbol: vaultRow.asset_symbol,
      assetAddress: vaultRow.asset_address,
      controllerAddress: trancheController,
      seniorTokenAddress: seniorToken,
      juniorTokenAddress: juniorToken,
      vaultAddress: boringVault,
      tellerAddress: teller,
      managerAddress: manager,
      uiConfig: {
        ...baseUiConfig,
        paramsHash,
        owner: operation.operation.requestedBy,
        deployTxHash: txHash ?? undefined,
        accountantAddress: accountant,
        trancheRegistry,
        trancheFactory: isAddressLike(trancheFactoryEnv) ? trancheFactoryEnv : undefined,
        indexerStartBlock: deploymentBlock ?? undefined,
      },
    });

    await updateOperatorOperationStep(parsed.operationId, parsed.stepIndex, {
      status: "CONFIRMED",
      ...(txHash ? { txHash } : {}),
    });

    return NextResponse.json({
      ok: true,
      txHash,
      vaultId: parsed.vaultId,
      chain: vaultRow.chain,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Record deploy failed.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
