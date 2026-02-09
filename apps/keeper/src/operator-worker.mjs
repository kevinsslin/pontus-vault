import {getEnv, getRequiredEnv} from "./env.mjs";
import {runDeployForge, isAddressLike} from "./forge.mjs";
import {getRequiredSupabaseAdminClient} from "./supabase.mjs";

import {normalizeVaultUiConfig} from "@pti/shared";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseOperatorAllowlist() {
  const raw = getEnv("OPERATOR_ADMIN_ADDRESSES");
  const set = new Set(
    raw
      .split(",")
      .map((item) => item.trim().toLowerCase())
      .filter((item) => item.length > 0)
  );
  if (set.size === 0) {
    throw new Error("Missing OPERATOR_ADMIN_ADDRESSES. Refusing to run as an unbounded worker.");
  }
  return set;
}

function isReadyAddress(value) {
  return Boolean(value) && value !== ZERO_ADDRESS;
}

function deriveOperationStatus(steps) {
  if (steps.length === 0) return "CREATED";
  if (steps.every((step) => step.status === "CANCELLED")) return "CANCELLED";
  if (steps.some((step) => step.status === "FAILED")) return "FAILED";
  if (steps.every((step) => ["SUCCEEDED", "CONFIRMED"].includes(step.status))) {
    return "SUCCEEDED";
  }
  if (
    steps.some((step) =>
      ["CREATED", "AWAITING_SIGNATURE", "BROADCASTED", "RUNNING"].includes(step.status)
    )
  ) {
    return "RUNNING";
  }
  return "RUNNING";
}

async function fetchTxBlockNumber(txHash) {
  if (!txHash) return null;
  const rpcUrl = getEnv("PHAROS_ATLANTIC_RPC_URL");
  if (!rpcUrl) return null;

  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getTransactionReceipt",
      params: [txHash]
    })
  });

  const payload = await response.json();
  const blockHex = payload?.result?.blockNumber;
  if (!blockHex) return null;
  const blockNumber = Number.parseInt(blockHex, 16);
  return Number.isFinite(blockNumber) ? blockNumber : null;
}

async function recomputeAndPersistOperationStatus(supabase, operationId) {
  const {data: steps, error: stepsError} = await supabase
    .from("operator_operation_steps")
    .select("status")
    .eq("operation_id", operationId);
  if (stepsError) throw new Error(stepsError.message);

  const nextStatus = deriveOperationStatus(steps ?? []);
  const {error: updateError} = await supabase
    .from("operator_operations")
    .update({status: nextStatus})
    .eq("operation_id", operationId);
  if (updateError) throw new Error(updateError.message);
}

async function updateStep(supabase, operationId, stepIndex, patch) {
  const {error} = await supabase
    .from("operator_operation_steps")
    .update(patch)
    .eq("operation_id", operationId)
    .eq("step_index", stepIndex);
  if (error) throw new Error(error.message);
  await recomputeAndPersistOperationStatus(supabase, operationId);
}

async function claimStep(supabase, operationId, stepIndex) {
  const {data, error} = await supabase
    .from("operator_operation_steps")
    .update({status: "RUNNING"})
    .eq("operation_id", operationId)
    .eq("step_index", stepIndex)
    .eq("status", "BROADCASTED")
    .select("*")
    .maybeSingle();

  if (error) throw new Error(error.message);
  return data ?? null;
}

async function findNextDeployStep(supabase) {
  const {data, error} = await supabase
    .from("operator_operation_steps")
    .select("*")
    .eq("kind", "OFFCHAIN")
    .eq("label", "Execute deployment transaction")
    .eq("status", "BROADCASTED")
    .order("created_at", {ascending: true})
    .limit(1);

  if (error) throw new Error(error.message);
  return (data ?? [])[0] ?? null;
}

async function loadOperation(supabase, operationId) {
  const {data, error} = await supabase
    .from("operator_operations")
    .select("*")
    .eq("operation_id", operationId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data ?? null;
}

async function loadOperationSteps(supabase, operationId) {
  const {data, error} = await supabase
    .from("operator_operation_steps")
    .select("*")
    .eq("operation_id", operationId)
    .order("step_index", {ascending: true});
  if (error) throw new Error(error.message);
  return data ?? [];
}

async function loadVaultRegistryRow(supabase, vaultId) {
  const {data, error} = await supabase
    .from("vault_registry")
    .select("*")
    .eq("vault_id", vaultId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data ?? null;
}

async function upsertVaultRegistryDeployment(supabase, vaultRow, deployment) {
  const trancheFactoryEnv = getEnv("TRANCHE_FACTORY");
  const deploymentBlock = await fetchTxBlockNumber(deployment.txHash);

  const nextUiConfig = {
    ...normalizeVaultUiConfig(vaultRow.ui_config),
    paramsHash: deployment.paramsHash,
    owner: deployment.owner,
    deployTxHash: deployment.txHash,
    accountantAddress: deployment.accountant,
    trancheRegistry: deployment.trancheRegistry,
    trancheFactory: isAddressLike(trancheFactoryEnv) ? trancheFactoryEnv : undefined,
    indexerStartBlock: deploymentBlock ?? undefined
  };

  const {error} = await supabase.from("vault_registry").upsert(
    {
      vault_id: vaultRow.vault_id,
      chain: vaultRow.chain,
      name: vaultRow.name,
      route: vaultRow.route,
      asset_symbol: vaultRow.asset_symbol,
      asset_address: vaultRow.asset_address,
      controller_address: deployment.trancheController,
      senior_token_address: deployment.seniorToken,
      junior_token_address: deployment.juniorToken,
      vault_address: deployment.boringVault,
      teller_address: deployment.teller,
      manager_address: deployment.manager,
      ui_config: nextUiConfig
    },
    {onConflict: "vault_id"}
  );

  if (error) throw new Error(error.message);
}

async function processDeployStep(supabase, allowlist, step) {
  const operationId = step.operation_id;
  const stepIndex = step.step_index;

  const operation = await loadOperation(supabase, operationId);
  if (!operation) {
    await updateStep(supabase, operationId, stepIndex, {
      status: "FAILED",
      error_code: "OPERATION_MISSING",
      error_message: "Operation not found."
    });
    return;
  }

  if (operation.job_type !== "DEPLOY_VAULT") {
    return;
  }

  if (!allowlist.has(String(operation.requested_by ?? "").toLowerCase())) {
    await updateStep(supabase, operationId, stepIndex, {
      status: "FAILED",
      error_code: "UNAUTHORIZED",
      error_message: "Operation requestedBy is not in operator allowlist."
    });
    return;
  }

  const opSteps = await loadOperationSteps(supabase, operationId);
  const prior = opSteps.find((candidate) => candidate.step_index === stepIndex - 1);
  if (prior && !["SUCCEEDED", "CONFIRMED"].includes(prior.status)) {
    // Not ready yet; keep queued until operator signs intent.
    return;
  }

  const claimed = await claimStep(supabase, operationId, stepIndex);
  if (!claimed) {
    return;
  }

  try {
    const vaultRow = await loadVaultRegistryRow(supabase, operation.vault_id);
    if (!vaultRow) {
      throw new Error("Vault registry row not found.");
    }

    const existingUiConfig = normalizeVaultUiConfig(vaultRow.ui_config);
    if (isReadyAddress(vaultRow.controller_address) && existingUiConfig.paramsHash) {
      await updateStep(supabase, operationId, stepIndex, {
        status: "CONFIRMED",
        tx_hash: existingUiConfig.deployTxHash ?? null,
        proof: existingUiConfig.paramsHash ?? null
      });

      const registerStep = opSteps.find((candidate) => candidate.step_index === stepIndex + 1);
      if (registerStep && !["SUCCEEDED", "FAILED", "CANCELLED", "CONFIRMED"].includes(registerStep.status)) {
        await updateStep(supabase, operationId, registerStep.step_index, {
          status: "SUCCEEDED",
          proof: existingUiConfig.paramsHash ?? null
        });
      }

      return;
    }

    const options = operation.options ?? {};
    const owner = isAddressLike(options.owner ?? "") ? String(options.owner).toLowerCase() : String(operation.requested_by).toLowerCase();
    const requestedBy = String(operation.requested_by).toLowerCase();

    const exec = await runDeployForge({
      owner,
      requestedBy,
      assetAddress: String(vaultRow.asset_address)
    });

    await upsertVaultRegistryDeployment(supabase, vaultRow, {
      owner,
      paramsHash: exec.result.paramsHash,
      txHash: exec.result.txHash,
      trancheRegistry: exec.result.trancheRegistry,
      trancheController: exec.result.trancheController,
      seniorToken: exec.result.seniorToken,
      juniorToken: exec.result.juniorToken,
      boringVault: exec.result.boringVault,
      teller: exec.result.teller,
      manager: exec.result.manager,
      accountant: exec.result.accountant
    });

    await updateStep(supabase, operationId, stepIndex, {
      status: "CONFIRMED",
      tx_hash: exec.result.txHash,
      proof: exec.result.paramsHash
    });

    const registerStep = opSteps.find((candidate) => candidate.step_index === stepIndex + 1);
    if (registerStep && !["SUCCEEDED", "FAILED", "CANCELLED", "CONFIRMED"].includes(registerStep.status)) {
      await updateStep(supabase, operationId, registerStep.step_index, {
        status: "SUCCEEDED",
        proof: exec.result.paramsHash
      });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await updateStep(supabase, operationId, stepIndex, {
      status: "FAILED",
      error_code: "EXECUTION_ERROR",
      error_message: message
    });
  }
}

async function tick(supabase, allowlist) {
  const step = await findNextDeployStep(supabase);
  if (!step) return false;

  await processDeployStep(supabase, allowlist, step);
  return true;
}

async function main() {
  // Sanity-check required env for execution.
  getRequiredEnv("PHAROS_ATLANTIC_RPC_URL");
  getRequiredEnv("DEPLOYER_PRIVATE_KEY");
  getRequiredEnv("TRANCHE_FACTORY");

  const supabase = getRequiredSupabaseAdminClient();
  const allowlist = parseOperatorAllowlist();

  const intervalMs = Number(getEnv("KEEPER_WORKER_INTERVAL_MS", "3000"));
  if (!Number.isFinite(intervalMs) || intervalMs <= 0) {
    throw new Error("KEEPER_WORKER_INTERVAL_MS must be a positive number.");
  }

  console.log(`[operator-worker] start interval=${intervalMs}ms`);
  while (true) {
    try {
      const didWork = await tick(supabase, allowlist);
      if (!didWork) {
        await sleep(intervalMs);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[operator-worker] tick failed: ${message}`);
      await sleep(Math.min(intervalMs * 2, 15_000));
    }
  }
}

void main();

