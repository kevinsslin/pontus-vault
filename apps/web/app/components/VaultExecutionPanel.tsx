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
  const amountId = useId();

  const isDeposit = mode === "deposit";
  const actionLabel = isDeposit ? "Deposit" : "Redeem";
  const inputLabel = isDeposit ? `Amount (${vault.assetSymbol})` : "Shares";
  const submitLabel = isDeposit ? "Submit deposit" : "Submit redeem";
  const routeLabel = vault.uiConfig.routeLabel ?? vault.route;
  const selectedApy = formatBps(
    tranche === "senior" ? vault.metrics.seniorApyBps ?? null : vault.metrics.juniorApyBps ?? null
  );

  return (
    <section className="section section--compact reveal delay-2" id="execute">
      <div className="execution-toolbar">
        <div className="execution-toolbar__copy">
          <p className="eyebrow">Execution</p>
          <h3>{isDeposit ? "Allocate into this vault" : "Redeem from this vault"}</h3>
          <p className="muted">
            Stay on one screen: review metrics, choose tranche, and execute when ready.
          </p>
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
      </div>

      <div className="form-layout">
        <form className="card execution-form" aria-label={`${actionLabel} form`}>
          <h3>{actionLabel} form</h3>

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

          <div className="card-actions">
            <button className="button" type="button">
              Preview output
            </button>
            <button className="button button--ghost" type="button">
              {submitLabel}
            </button>
          </div>
          <div className="card-actions">
            <WalletConnectButton />
          </div>
          <p className="micro">
            Wallet connection is requested only when you are ready to execute.
          </p>
        </form>

        <aside className="card card--spotlight execution-notes">
          <h3>Execution notes</h3>
          <div className="execution-notes__grid">
            <div className="execution-note">
              <span className="label">Action</span>
              <span className="value">{actionLabel}</span>
            </div>
            <div className="execution-note">
              <span className="label">Selected tranche</span>
              <span className="value">{tranche === "senior" ? "Senior" : "Junior"}</span>
            </div>
            <div className="execution-note">
              <span className="label">Selected APY</span>
              <span className="value">{selectedApy}</span>
            </div>
            <div className="execution-note">
              <span className="label">Asset</span>
              <span className="value">{vault.assetSymbol}</span>
            </div>
            <div className="execution-note">
              <span className="label">Route</span>
              <span className="value">{routeLabel}</span>
            </div>
            <div className="execution-note">
              <span className="label">Policy</span>
              <span className="value">{vault.uiConfig.banner ?? "N/A"}</span>
            </div>
          </div>
        </aside>
      </div>
    </section>
  );
}
