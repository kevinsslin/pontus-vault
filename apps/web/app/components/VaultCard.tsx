import Link from "next/link";
import type { VaultRecord } from "@pti/shared";
import { formatUsd, formatWad } from "../../lib/format";

export default function VaultCard({ vault }: { vault: VaultRecord }) {
  const status = vault.uiConfig.status;
  const isLive = status === "LIVE";
  return (
    <div className="card vault-card">
      <div className="vault-card__top">
        <span className={`badge ${status === "LIVE" ? "badge--live" : "badge--soon"}`}>
          {status}
        </span>
        <span className="chip">{vault.assetSymbol}</span>
      </div>
      <h3>{vault.name}</h3>
      <p className="muted">{vault.uiConfig.summary}</p>
      <div className="stat-grid">
        <div className="stat">
          <span className="stat-label">TVL</span>
          <span className="stat-value">{formatUsd(vault.metrics.tvl)}</span>
        </div>
        <div className="stat">
          <span className="stat-label">Senior Price</span>
          <span className="stat-value">{formatWad(vault.metrics.seniorPrice)}x</span>
        </div>
        <div className="stat">
          <span className="stat-label">Junior Price</span>
          <span className="stat-value">{formatWad(vault.metrics.juniorPrice)}x</span>
        </div>
      </div>
      <div className="card-actions">
        <Link className="button" href={`/vaults/${vault.productId}`}>
          View details
        </Link>
        <Link
          className={`button button--ghost ${!isLive ? "button--disabled" : ""}`}
          href={isLive ? `/vaults/${vault.productId}/deposit` : "#"}
          aria-disabled={!isLive}
          tabIndex={isLive ? 0 : -1}
        >
          Deposit
        </Link>
      </div>
    </div>
  );
}
