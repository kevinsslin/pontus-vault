import Link from "next/link";
import type { VaultRecord } from "@pti/shared";
import { formatTimestamp, formatUsd, formatWad } from "../../lib/format";

function seniorRatioBps(vault: VaultRecord): bigint | null {
  if (!vault.metrics.tvl || !vault.metrics.seniorDebt) return null;
  try {
    const tvl = BigInt(vault.metrics.tvl);
    const seniorDebt = BigInt(vault.metrics.seniorDebt);
    if (tvl === 0n) return null;
    return (seniorDebt * 10_000n) / tvl;
  } catch {
    return null;
  }
}

export default function VaultCard({ vault }: { vault: VaultRecord }) {
  const status = vault.uiConfig.status;
  const isLive = status === "LIVE";
  const tags = vault.uiConfig.tags?.slice(0, 2) ?? [];
  const ratioBps = seniorRatioBps(vault);
  const ratioPct = ratioBps === null ? null : Number(ratioBps) / 100;
  const ratioWidth = ratioPct === null ? 0 : Math.max(0, Math.min(ratioPct, 100));

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

      <div className="risk-meter">
        <div className="risk-meter__labels">
          <span className="stat-label">Senior Coverage</span>
          <span className="stat-value">{ratioPct === null ? "—" : `${ratioPct.toFixed(2)}%`}</span>
        </div>
        <div className="risk-meter__track" aria-hidden="true">
          <span className="risk-meter__fill" style={{ width: `${ratioWidth}%` }} />
        </div>
        <p className="muted">Updated {formatTimestamp(vault.metrics.updatedAt)}</p>
      </div>

      <div className="card-actions">
        <Link className="button" href={`/vaults/${vault.vaultId}`}>
          {isLive ? "Enter vault" : "View preview"}
        </Link>
        <p className="flow-note">
          Deposit and redeem actions are available inside the vault detail page.
        </p>
      </div>
    </article>
  );
}
