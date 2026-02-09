"use client";

import { useId, useState } from "react";
import type { VaultRecord } from "@pti/shared";
import { formatBps } from "../../lib/format";
import WalletConnectButton from "./WalletConnectButton";

type ExecutionMode = "deposit" | "redeem";
type TrancheMode = "senior" | "junior";

type VaultExecutionPanelProps = {
  vault: VaultRecord;
  defaultMode?: ExecutionMode;
};

export default function VaultExecutionPanel({
  vault,
  defaultMode = "deposit",
}: VaultExecutionPanelProps) {
  const [mode, setMode] = useState<ExecutionMode>(defaultMode);
  const [tranche, setTranche] = useState<TrancheMode>("senior");
  const [amount, setAmount] = useState("");
  const [submitMessage, setSubmitMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const amountId = useId();

  const isDeposit = mode === "deposit";
  const actionLabel = isDeposit ? "Deposit" : "Redeem";
  const inputLabel = isDeposit ? `Amount (${vault.assetSymbol})` : "Shares";
  const submitLabel = isDeposit ? "Submit deposit" : "Submit redeem";

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitMessage(null);
    const raw = amount.trim();
    const num = raw ? Number.parseFloat(raw) : NaN;
    if (!raw || Number.isNaN(num) || num <= 0) {
      setSubmitMessage("Please enter a valid amount.");
      return;
    }
    setSubmitting(true);
    setSubmitMessage(
      isDeposit
        ? `Deposit ${num} ${vault.assetSymbol} → ${tranche === "senior" ? "Senior" : "Junior"}. Connect wallet above to sign the transaction.`
        : `Redeem ${num} shares (${tranche}). Connect wallet above to sign the transaction.`
    );
    setSubmitting(false);
  }
  const routeLabel =
    vault.uiConfig.routeLabel ??
    (vault.uiConfig.strategyKeys && vault.uiConfig.strategyKeys.length > 0
      ? vault.uiConfig.strategyKeys.join(" + ")
      : "Multi-strategy");
  const selectedApy = formatBps(
    tranche === "senior" ? vault.metrics.seniorApyBps ?? null : vault.metrics.juniorApyBps ?? null
  );

  return (
    <article className="card execution-panel" id="execute">
      <div className="execution-panel__header">
        <p className="eyebrow">Trade ticket</p>
        <h3>{isDeposit ? "Deposit into vault" : "Redeem from vault"}</h3>
      </div>

      <div className="execution-segment" role="tablist" aria-label="Execution mode">
        <button
          className={`segment-button ${isDeposit ? "segment-button--active" : ""}`}
          onClick={() => setMode("deposit")}
          role="tab"
          aria-selected={isDeposit}
          type="button"
        >
          Deposit
        </button>
        <button
          className={`segment-button ${!isDeposit ? "segment-button--active" : ""}`}
          onClick={() => setMode("redeem")}
          role="tab"
          aria-selected={!isDeposit}
          type="button"
        >
          Redeem
        </button>
      </div>

      <form className="execution-form" aria-label={`${actionLabel} form`} onSubmit={handleSubmit}>
        <label className="field-label" htmlFor={amountId}>
          {inputLabel}
        </label>
        <input
          id={amountId}
          name="amount"
          type="number"
          placeholder="0.00"
          className="input"
          inputMode="decimal"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />

        <div>
          <p className="field-label">Tranche</p>
          <div className="radio-group">
            <label className="radio-chip">
              <input
                type="radio"
                name="tranche"
                checked={tranche === "senior"}
                onChange={() => setTranche("senior")}
              />
              Senior
            </label>
            <label className="radio-chip">
              <input
                type="radio"
                name="tranche"
                checked={tranche === "junior"}
                onChange={() => setTranche("junior")}
              />
              Junior
            </label>
          </div>
        </div>

        <div className="execution-actions">
          <button className="button" type="submit" disabled={submitting}>
            {submitting ? "Submitting..." : submitLabel}
          </button>
          <WalletConnectButton />
        </div>
        {submitMessage ? (
          <p className="execution-form__message" role="status">
            {submitMessage}
          </p>
        ) : null}
      </form>

      <div className="execution-summary">
        <div className="execution-summary__row">
          <span className="execution-summary__label">Action</span>
          <span className="execution-summary__value">{actionLabel}</span>
        </div>
        <div className="execution-summary__row">
          <span className="execution-summary__label">Tranche</span>
          <span className="execution-summary__value">{tranche === "senior" ? "Senior" : "Junior"}</span>
        </div>
        <div className="execution-summary__row">
          <span className="execution-summary__label">Selected APY</span>
          <span className="execution-summary__value">{selectedApy}</span>
        </div>
        <div className="execution-summary__row">
          <span className="execution-summary__label">Route</span>
          <span className="execution-summary__value">{routeLabel}</span>
        </div>
      </div>
    </article>
  );
}
