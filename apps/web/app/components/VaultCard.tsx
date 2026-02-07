import Link from "next/link";
import type { VaultRecord } from "@pti/shared";
import {
  formatBps,
  formatUsd,
} from "../../lib/format";
import TokenBadge from "./TokenBadge";

function getRateProfile(vault: VaultRecord, tranche: "senior" | "junior"): "Fixed" | "Variable" {
  const tags = (vault.uiConfig.tags ?? []).map((value) => value.toLowerCase());
  const banner = (vault.uiConfig.banner ?? "").toLowerCase();
  const fixedTags = [`${tranche}-fixed`, `${tranche}_fixed`, `${tranche} fixed`];
  const variableTags = [`${tranche}-variable`, `${tranche}_variable`, `${tranche} variable`];

  if (fixedTags.some((tag) => tags.includes(tag))) return "Fixed";
  if (variableTags.some((tag) => tags.includes(tag))) return "Variable";

  if (tranche === "senior" && (banner.includes("cap") || banner.includes("fixed"))) {
    return "Fixed";
  }
  if (tranche === "junior" && (banner.includes("floating") || banner.includes("variable"))) {
    return "Variable";
  }

  return tranche === "senior" ? "Fixed" : "Variable";
}

export default function VaultCard({ vault }: { vault: VaultRecord }) {
  const status = vault.uiConfig.status;
  const isLive = status === "LIVE";
  const seniorRate = formatBps(vault.metrics.seniorApyBps ?? null);
  const juniorRate = formatBps(vault.metrics.juniorApyBps ?? null);
  const seniorProfile = getRateProfile(vault, "senior");
  const juniorProfile = getRateProfile(vault, "junior");

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

      <div className="vault-card__chips">
        <span className="chip chip--soft">{vault.uiConfig.routeLabel ?? vault.route}</span>
        <span className="chip chip--soft">Risk: {vault.uiConfig.risk ?? "N/A"}</span>
        <span className="chip chip--soft">{vault.assetSymbol}</span>
      </div>

      <div className="vault-card__focus-grid">
        <div className="vault-card__focus-item">
          <span className="stat-label">Junior rate</span>
          <span className="vault-card__focus-value">{juniorRate}</span>
          <span className="vault-card__focus-tag">{juniorProfile}</span>
        </div>
        <div className="vault-card__focus-item">
          <span className="stat-label">Senior rate</span>
          <span className="vault-card__focus-value">{seniorRate}</span>
          <span className="vault-card__focus-tag">{seniorProfile}</span>
        </div>
        <div className="vault-card__focus-item">
          <span className="stat-label">TVL</span>
          <span className="vault-card__focus-value">{formatUsd(vault.metrics.tvl)}</span>
        </div>
      </div>

      <div className="vault-card__actions">
        <Link className="button" href={`/vaults/${vault.vaultId}`}>
          {isLive ? "Enter vault" : "View preview"}
        </Link>
      </div>
    </article>
  );
}
