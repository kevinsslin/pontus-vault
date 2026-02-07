import Link from "next/link";
import type { VaultRecord } from "@pti/shared";
import {
  formatBps,
  formatRelativeTimestamp,
  formatUsd,
  formatWad,
} from "../../lib/format";
import TokenBadge from "./TokenBadge";

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
  const tags = vault.uiConfig.tags?.slice(0, 1) ?? [];
  const ratioBps = seniorRatioBps(vault);
  const ratioPct = ratioBps === null ? null : Number(ratioBps) / 100;
  const ratioWidth = ratioPct === null ? 0 : Math.max(0, Math.min(ratioPct, 100));
  const juniorPct = ratioPct === null ? null : Math.max(0, 100 - ratioPct);
  const updatedLabel = formatRelativeTimestamp(vault.metrics.updatedAt);

  return (
    <article className="card vault-card">
      <div className="vault-card__top">
        <span className={`badge ${isLive ? "badge--live" : "badge--soon"}`}>{status}</span>
        <TokenBadge symbol={vault.assetSymbol} />
      </div>

      <div>
        <h3>{vault.name}</h3>
        <p className="muted">{vault.uiConfig.summary ?? "Structured yield vault."}</p>
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

      <div className="yield-grid">
        <div className="yield-item yield-item--senior">
          <span className="stat-label">Senior APY</span>
          <span className="yield-value">{formatBps(vault.metrics.seniorApyBps ?? null)}</span>
        </div>
        <div className="yield-item yield-item--junior">
          <span className="stat-label">Junior APY</span>
          <span className="yield-value">{formatBps(vault.metrics.juniorApyBps ?? null)}</span>
        </div>
      </div>

      <div className="stat-grid">
        <div className="stat">
          <span className="stat-label">TVL</span>
          <span className="stat-value">{formatUsd(vault.metrics.tvl)}</span>
        </div>
        <div className="stat">
          <span className="stat-label">Senior Yield</span>
          <span className="stat-value">{formatWad(vault.metrics.seniorPrice)}x</span>
        </div>
        <div className="stat">
          <span className="stat-label">Junior Yield</span>
          <span className="stat-value">{formatWad(vault.metrics.juniorPrice)}x</span>
        </div>
      </div>

      <div className="risk-meter">
        <div className="risk-meter__labels">
          <span className="stat-label">Tranche Mix</span>
          <span className="stat-value">{ratioPct === null ? "—" : `${ratioPct.toFixed(2)}%`}</span>
        </div>
        <div className="risk-meter__track" aria-hidden="true">
          <span className="risk-meter__fill" style={{ width: `${ratioWidth}%` }} />
        </div>
        <div className="risk-meter__split">
          <span>Senior {ratioPct === null ? "—" : `${ratioPct.toFixed(2)}%`}</span>
          <span>Junior {juniorPct === null ? "—" : `${juniorPct.toFixed(2)}%`}</span>
        </div>
        <p className="micro">Updated {updatedLabel}</p>
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
