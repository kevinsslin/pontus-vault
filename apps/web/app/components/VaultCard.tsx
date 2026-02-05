import Link from "next/link";
import type { VaultRecord } from "@pti/shared";
import { formatUsd, formatWad } from "../../lib/format";

export default function VaultCard({ vault }: { vault: VaultRecord }) {
  const status = vault.uiConfig.status;
  const isLive = status === "LIVE";
  const tags = vault.uiConfig.tags?.slice(0, 2) ?? [];

  return (
    <article className="card vault-card">
      <div className="vault-card__top">
        <span className={`badge ${isLive ? "badge--live" : "badge--soon"}`}>{status}</span>
        <span className="chip">{vault.assetSymbol}</span>
      </div>

      <div>
        <h3>{vault.name}</h3>
        <p className="muted">{vault.uiConfig.summary ?? "Structured yield product."}</p>
      </div>

      <div className="card-actions">
        <span className="chip chip--soft">{vault.uiConfig.routeLabel ?? vault.route}</span>
        <span className="chip chip--soft">Risk: {vault.uiConfig.risk ?? "N/A"}</span>
        {tags.map((tag) => (
          <span key={tag} className="chip chip--soft">
            {tag}
          </span>
        ))}
      </div>

      <div className="stat-grid">
        <div className="stat">
          <span className="stat-label">TVL</span>
          <span className="stat-value">{formatUsd(vault.metrics.tvl)}</span>
        </div>
        <div className="stat">
          <span className="stat-label">Senior NAV</span>
          <span className="stat-value">{formatWad(vault.metrics.seniorPrice)}x</span>
        </div>
        <div className="stat">
          <span className="stat-label">Junior NAV</span>
          <span className="stat-value">{formatWad(vault.metrics.juniorPrice)}x</span>
        </div>
      </div>

      <div className="card-actions">
        <Link className="button" href={`/vaults/${vault.productId}`}>
          Open vault
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
    </article>
  );
}
