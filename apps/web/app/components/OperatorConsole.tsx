"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  OperatorCreateOperationRequest,
  OperatorJobType,
  OperatorOperation,
  OperatorOperationStep,
  OperatorOperationWithSteps,
  OperatorStepStatus,
  VaultRecord,
} from "@pti/shared";
import { useDynamicContext } from "@dynamic-labs/sdk-react-core";

type OperatorConsoleProps = {
  vaults: VaultRecord[];
};

const EXECUTION_MODE =
  process.env.NEXT_PUBLIC_OPERATOR_TX_MODE === "send_transaction"
    ? "send_transaction"
    : "sign_only";

const JOBS: Array<{ value: OperatorJobType; label: string; helper: string }> = [
  {
    value: "DEPLOY_VAULT",
    label: "Deploy vault",
    helper: "Prepare deployment intent + execution evidence logging.",
  },
  {
    value: "CONFIGURE_VAULT",
    label: "Configure vault",
    helper: "Set tranche caps/rates on controller with wallet signatures.",
  },
  {
    value: "PUBLISH_VAULT",
    label: "Publish vault",
    helper: "Move listing status from review to live.",
  },
  {
    value: "REBALANCE_VAULT",
    label: "Rebalance vault",
    helper: "Approve and execute manager rebalance path.",
  },
];

function shortHash(value: string) {
  if (value.length <= 16) return value;
  return `${value.slice(0, 8)}...${value.slice(-6)}`;
}

function parseValueWeiToHex(valueWei: string | null): `0x${string}` {
  const normalized = valueWei && valueWei.trim().length > 0 ? valueWei : "0";
  return `0x${BigInt(normalized).toString(16)}`;
}

function isStepTerminal(status: OperatorStepStatus) {
  return ["SUCCEEDED", "FAILED", "CANCELLED"].includes(status);
}

function useOptionalPrimaryWallet() {
  try {
    return useDynamicContext().primaryWallet ?? null;
  } catch {
    return null;
  }
}

function operationStatusLabel(status: OperatorOperation["status"]) {
  if (status === "SUCCEEDED") return "done";
  if (status === "FAILED") return "failed";
  if (status === "CANCELLED") return "cancelled";
  if (status === "RUNNING") return "running";
  return "created";
}

export default function OperatorConsole({ vaults }: OperatorConsoleProps) {
  const primaryWallet = useOptionalPrimaryWallet();
  const walletAddress = primaryWallet?.address ?? "";

  const [selectedVaultId, setSelectedVaultId] = useState<string>(
    vaults[0]?.vaultId ?? ""
  );
  const [jobType, setJobType] = useState<OperatorJobType>("CONFIGURE_VAULT");
  const [maxSeniorRatioBps, setMaxSeniorRatioBps] = useState("8000");
  const [seniorRatePerSecondWad, setSeniorRatePerSecondWad] = useState("0");
  const [rateModel, setRateModel] = useState("");
  const [rebalanceRoute, setRebalanceRoute] = useState("openfi-supply-withdraw");

  const [operations, setOperations] = useState<OperatorOperation[]>([]);
  const [activeOperation, setActiveOperation] =
    useState<OperatorOperationWithSteps | null>(null);
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<string | null>(null);

  const selectedVault = useMemo(
    () => vaults.find((vault) => vault.vaultId === selectedVaultId) ?? null,
    [vaults, selectedVaultId]
  );

  const selectedJob = useMemo(
    () => JOBS.find((job) => job.value === jobType) ?? JOBS[0],
    [jobType]
  );

  const loadOperations = useCallback(async (vaultId = selectedVaultId) => {
    if (!vaultId) return;
    const response = await fetch(`/api/operator/operations?vaultId=${vaultId}`, {
      cache: "no-store",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error ?? "Failed to load operator operations.");
    }
    setOperations(payload.operations ?? []);
  }, [selectedVaultId]);

  const loadOperation = useCallback(async (operationId: string) => {
    const response = await fetch(`/api/operator/operations/${operationId}`, {
      cache: "no-store",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error ?? "Failed to load operation details.");
    }
    setActiveOperation(payload);
  }, []);

  useEffect(() => {
    if (!selectedVaultId) return;
    void loadOperations(selectedVaultId).catch((error) => {
      setErrorMessage(error instanceof Error ? error.message : "Load failed.");
    });
  }, [loadOperations, selectedVaultId]);

  useEffect(() => {
    if (!activeOperation) return;
    const exists = operations.some(
      (operation) => operation.operationId === activeOperation.operation.operationId
    );
    if (!exists) {
      setActiveOperation(null);
    }
  }, [activeOperation, operations]);

  function buildRequestPayload(): OperatorCreateOperationRequest {
    const options: Record<string, unknown> = {};

    if (jobType === "CONFIGURE_VAULT") {
      options.maxSeniorRatioBps = Number(maxSeniorRatioBps || "8000");
      options.seniorRatePerSecondWad = seniorRatePerSecondWad || "0";
      if (rateModel.trim()) options.rateModel = rateModel.trim();
    } else if (jobType === "REBALANCE_VAULT") {
      options.route = rebalanceRoute.trim() || "openfi-supply-withdraw";
    }

    return {
      vaultId: selectedVaultId,
      chain: selectedVault?.chain ?? "pharos-atlantic",
      jobType,
      requestedBy: walletAddress || "unconnected-operator",
      idempotencyKey: crypto.randomUUID(),
      options,
    };
  }

  async function createOperation() {
    if (!selectedVaultId) return;

    setBusyAction("create");
    setErrorMessage(null);
    setInfoMessage(null);
    try {
      const requestPayload = buildRequestPayload();
      const response = await fetch("/api/operator/operations", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(requestPayload),
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Failed to create operation.");
      }
      setActiveOperation(payload);
      await loadOperations(selectedVaultId);
      setInfoMessage("Operation prepared. Execute steps in order below.");
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : "Create operation failed."
      );
    } finally {
      setBusyAction(null);
    }
  }

  async function signMessage(message: string): Promise<string> {
    if (!primaryWallet) {
      throw new Error("Connect an operator wallet first.");
    }

    const connector = primaryWallet.connector as {
      getSigner?: () => Promise<{
        signMessage?: (value: string | { message: string }) => Promise<string>;
      }>;
    };

    if (connector?.getSigner) {
      const signer = await connector.getSigner();
      if (signer?.signMessage) {
        try {
          return await signer.signMessage(message);
        } catch {
          return await signer.signMessage({ message });
        }
      }
    }

    if (typeof window !== "undefined") {
      const ethereum = (window as Window & { ethereum?: { request?: (args: { method: string; params?: unknown[] }) => Promise<string> } }).ethereum;
      if (ethereum?.request) {
        return ethereum.request({
          method: "personal_sign",
          params: [message, primaryWallet.address],
        });
      }
    }

    throw new Error("Wallet signer is unavailable.");
  }

  async function sendOnchainStep(step: OperatorOperationStep): Promise<string> {
    if (!primaryWallet) {
      throw new Error("Connect an operator wallet first.");
    }
    if (!step.toAddress || !step.calldata) {
      throw new Error("Step is missing to/data payload.");
    }

    const connector = primaryWallet.connector as {
      getWalletClient?: () => {
        sendTransaction?: (params: {
          account?: string;
          to: string;
          data?: `0x${string}`;
          value?: bigint;
        }) => Promise<string>;
      };
      getSigner?: () => Promise<{
        sendTransaction?: (params: {
          to: string;
          data?: string;
          value?: bigint;
        }) => Promise<{ hash?: string } | string>;
      }>;
    };

    const value = BigInt(step.valueWei ?? "0");
    const txData = step.calldata as `0x${string}`;

    const walletClient = connector?.getWalletClient?.();
    if (walletClient?.sendTransaction) {
      const txHash = await walletClient.sendTransaction({
        account: primaryWallet.address,
        to: step.toAddress,
        data: txData,
        value,
      });
      if (txHash) return txHash;
    }

    if (connector?.getSigner) {
      const signer = await connector.getSigner();
      if (signer?.sendTransaction) {
        const tx = await signer.sendTransaction({
          to: step.toAddress,
          data: txData,
          value,
        });
        if (typeof tx === "string") return tx;
        if (tx?.hash) return tx.hash;
      }
    }

    if (typeof window !== "undefined") {
      const ethereum = (window as Window & { ethereum?: { request?: (args: { method: string; params?: unknown[] }) => Promise<string> } }).ethereum;
      if (ethereum?.request) {
        return ethereum.request({
          method: "eth_sendTransaction",
          params: [
            {
              from: primaryWallet.address,
              to: step.toAddress,
              data: step.calldata,
              value: parseValueWeiToHex(step.valueWei),
            },
          ],
        });
      }
    }

    throw new Error("Wallet transaction transport is unavailable.");
  }

  async function patchStep(
    operationId: string,
    stepIndex: number,
    patch: {
      status: OperatorStepStatus;
      txHash?: string;
      proof?: string;
      errorCode?: string;
      errorMessage?: string;
    }
  ) {
    const response = await fetch(
      `/api/operator/operations/${operationId}/steps/${stepIndex}`,
      {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(patch),
      }
    );
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error ?? "Failed to update step.");
    }
    setActiveOperation(payload);
    await loadOperations(selectedVaultId);
  }

  async function executeStep(step: OperatorOperationStep) {
    if (!activeOperation) return;
    const actionKey = `${activeOperation.operation.operationId}:${step.stepIndex}`;
    setBusyAction(actionKey);
    setErrorMessage(null);
    setInfoMessage(null);
    try {
      if (step.kind === "ONCHAIN" && EXECUTION_MODE === "send_transaction") {
        const txHash = await sendOnchainStep(step);
        await patchStep(activeOperation.operation.operationId, step.stepIndex, {
          status: "CONFIRMED",
          txHash,
        });
        setInfoMessage(`Step confirmed onchain: ${shortHash(txHash)}`);
        return;
      }

      const signature = await signMessage(
        [
          `Pontus Operator Step`,
          `Operation: ${activeOperation.operation.operationId}`,
          `Step: ${step.stepIndex}`,
          `Label: ${step.label}`,
          `Vault: ${activeOperation.operation.vaultId}`,
          `Timestamp: ${new Date().toISOString()}`,
        ].join("\n")
      );

      await patchStep(activeOperation.operation.operationId, step.stepIndex, {
        status: "SUCCEEDED",
        proof: signature,
      });
      setInfoMessage(`Step signed and recorded: ${shortHash(signature)}`);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Step execution failed.";
      setErrorMessage(message);
      try {
        await patchStep(activeOperation.operation.operationId, step.stepIndex, {
          status: "FAILED",
          errorCode: "EXECUTION_ERROR",
          errorMessage: message,
        });
      } catch {
        // no-op: keep original error in UI
      }
    } finally {
      setBusyAction(null);
    }
  }

  const liveCount = vaults.filter((vault) => vault.uiConfig.status === "LIVE").length;

  return (
    <>
      <section className="reveal">
        <p className="eyebrow">Operator</p>
        <h1>Vault operations console.</h1>
        <p className="muted">
          Wallet-signed step runner for deploy, configure, publish, and rebalance.
          API validates inputs and persists every step for audit replay.
        </p>
        <div className="card-actions">
          <span className="chip">Live vaults: {liveCount}</span>
          <span className="chip">Total vaults: {vaults.length}</span>
          <span className="chip">
            Mode: {EXECUTION_MODE === "send_transaction" ? "Send tx" : "Sign only"}
          </span>
        </div>
      </section>

      <section className="section section--tight reveal delay-1">
        <div className="card operator-panel">
          <h3>Prepare operation</h3>
          <p className="muted">
            Pick vault + action, generate step plan, then execute each step with the
            operator wallet.
          </p>
          <div className="operator-grid">
            <label className="field">
              <span>Vault</span>
              <select
                value={selectedVaultId}
                onChange={(event) => setSelectedVaultId(event.target.value)}
              >
                {vaults.map((vault) => (
                  <option key={vault.vaultId} value={vault.vaultId}>
                    {vault.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Job type</span>
              <select
                value={jobType}
                onChange={(event) => setJobType(event.target.value as OperatorJobType)}
              >
                {JOBS.map((job) => (
                  <option key={job.value} value={job.value}>
                    {job.label}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <p className="muted">{selectedJob.helper}</p>

          {jobType === "CONFIGURE_VAULT" ? (
            <div className="operator-grid">
              <label className="field">
                <span>Max senior ratio (bps)</span>
                <input
                  value={maxSeniorRatioBps}
                  onChange={(event) => setMaxSeniorRatioBps(event.target.value)}
                  inputMode="numeric"
                />
              </label>
              <label className="field">
                <span>Senior rate per second (wad)</span>
                <input
                  value={seniorRatePerSecondWad}
                  onChange={(event) => setSeniorRatePerSecondWad(event.target.value)}
                  inputMode="numeric"
                />
              </label>
              <label className="field">
                <span>Rate model address (optional)</span>
                <input
                  value={rateModel}
                  onChange={(event) => setRateModel(event.target.value)}
                  placeholder="0x..."
                />
              </label>
            </div>
          ) : null}

          {jobType === "REBALANCE_VAULT" ? (
            <label className="field">
              <span>Rebalance route</span>
              <input
                value={rebalanceRoute}
                onChange={(event) => setRebalanceRoute(event.target.value)}
                placeholder="openfi-supply-withdraw"
              />
            </label>
          ) : null}

          <div className="card-actions">
            <button
              className="button"
              type="button"
              onClick={() => void createOperation()}
              disabled={busyAction !== null}
            >
              {busyAction === "create" ? "Preparing..." : "Prepare operation"}
            </button>
            <span className="chip">
              Operator wallet: {walletAddress ? shortHash(walletAddress) : "Not connected"}
            </span>
          </div>
          {errorMessage ? <p className="operator-error">{errorMessage}</p> : null}
          {infoMessage ? <p className="operator-info">{infoMessage}</p> : null}
        </div>
      </section>

      <section className="section section--tight reveal delay-2">
        <div className="card operator-history">
          <h3>Recent operations</h3>
          <div className="operator-list">
            {operations.length === 0 ? (
              <p className="muted">No operations logged for this vault yet.</p>
            ) : (
              operations.map((operation) => (
                <button
                  className="operator-item"
                  key={operation.operationId}
                  type="button"
                  onClick={() => void loadOperation(operation.operationId)}
                >
                  <div>
                    <strong>{operation.jobType}</strong>
                    <p className="muted">Vault {operation.vaultId}</p>
                  </div>
                  <span className="chip">
                    {operationStatusLabel(operation.status)}
                  </span>
                </button>
              ))
            )}
          </div>
        </div>
      </section>

      {activeOperation ? (
        <section className="section section--tight reveal delay-3">
          <div className="card operator-steps">
            <h3>Operation detail</h3>
            <p className="muted">
              {activeOperation.operation.jobType} · {activeOperation.operation.operationId}
            </p>
            <div className="operator-step-list">
              {activeOperation.steps.map((step) => {
                const isBusy =
                  busyAction ===
                  `${activeOperation.operation.operationId}:${step.stepIndex}`;
                return (
                  <article className="operator-step" key={step.stepId}>
                    <div className="operator-step__head">
                      <h4>
                        #{step.stepIndex + 1} {step.label}
                      </h4>
                      <span className="chip">{step.status.toLowerCase()}</span>
                    </div>
                    <p className="muted">{step.description ?? "No description."}</p>
                    {step.toAddress ? (
                      <p className="operator-mono">
                        to: {step.toAddress}
                        <br />
                        data: {step.calldata ?? "0x"}
                      </p>
                    ) : null}
                    {step.txHash ? (
                      <p className="operator-mono">tx: {shortHash(step.txHash)}</p>
                    ) : null}
                    {step.proof ? (
                      <p className="operator-mono">proof: {shortHash(step.proof)}</p>
                    ) : null}
                    {step.errorMessage ? (
                      <p className="operator-error">{step.errorMessage}</p>
                    ) : null}
                    <div className="card-actions">
                      <button
                        className="button"
                        type="button"
                        disabled={isBusy || isStepTerminal(step.status)}
                        onClick={() => void executeStep(step)}
                      >
                        {isBusy
                          ? "Executing..."
                          : step.kind === "ONCHAIN" &&
                            EXECUTION_MODE === "send_transaction"
                          ? "Sign & send"
                          : "Sign & record"}
                      </button>
                      <span className="chip">{step.kind.toLowerCase()}</span>
                    </div>
                  </article>
                );
              })}
            </div>
          </div>
        </section>
      ) : null}
    </>
  );
}
