import Link from "next/link";
import type { VaultRecord } from "@pti/shared";
import {
  formatBps,
  formatRelativeTimestamp,
  formatUsd,
} from "../../lib/format";
import { buildAssetAllocation } from "../../lib/asset-allocation";
import TokenBadge from "./TokenBadge";
import VaultAllocationMiniChart from "./VaultAllocationMiniChart";

function getApyBand(vault: VaultRecord): string {
  const seniorApy = formatBps(vault.metrics.seniorApyBps ?? null);
  const juniorApy = formatBps(vault.metrics.juniorApyBps ?? null);
  if (seniorApy === "—" && juniorApy === "—") return "—";
  if (seniorApy === "—") return juniorApy;
  if (juniorApy === "—") return seniorApy;
  return `${seniorApy} - ${juniorApy}`;
}

export default function VaultCard({ vault }: { vault: VaultRecord }) {
  const status = vault.uiConfig.status;
  const isLive = status === "LIVE";
  const updatedLabel = formatRelativeTimestamp(vault.metrics.updatedAt);
  const assetAllocation = buildAssetAllocation(vault.route, vault.metrics.tvl);
  const apyBand = getApyBand(vault);

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

      <div className="vault-card__overview">
        <div className="stat">
          <span className="stat-label">APY band</span>
          <span className="stat-value">{apyBand}</span>
        </div>
        <div className="stat">
          <span className="stat-label">TVL</span>
          <span className="stat-value">{formatUsd(vault.metrics.tvl)}</span>
        </div>
        <div className="stat">
          <span className="stat-label">Last update</span>
          <span className="stat-value">{updatedLabel}</span>
        </div>
      </div>

      <div className="vault-card__allocation">
        <span className="stat-label">Asset allocation</span>
        <VaultAllocationMiniChart slices={assetAllocation} />
      </div>

      <div className="vault-card__actions">
        <Link className="button" href={`/vaults/${vault.vaultId}`}>
          {isLive ? "Enter vault" : "View preview"}
        </Link>
      </div>
    </article>
  );
}
