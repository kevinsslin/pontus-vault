import Link from "next/link";
import { notFound } from "next/navigation";
import { PHAROS_ATLANTIC } from "@pti/shared";
import { VAULT_TREND_POINTS } from "../../../lib/constants/vault-detail";
import { getActivityForVault, getVaultById } from "../../../lib/data/vaults";
import { buildAssetAllocation } from "../../../lib/asset-allocation";
import { formatBps, formatRelativeTimestamp, formatSharePrice, formatUsd } from "../../../lib/format";
import TokenBadge from "../../components/TokenBadge";
import VaultAssetAllocationChart from "../../components/VaultAssetAllocationChart";
import VaultPerformanceChart from "../../components/VaultPerformanceChart";
import VaultExecutionPanel from "../../components/VaultExecutionPanel";

function seniorMixPercent(tvl: string | null, seniorDebt: string | null): number | null {
  if (!tvl || !seniorDebt) return null;
  try {
    const tvlValue = BigInt(tvl);
    const debtValue = BigInt(seniorDebt);
    if (tvlValue === 0n) return null;
    const pctBps = Number((debtValue * 10_000n) / tvlValue);
    return Math.max(0, Math.min(100, pctBps / 100));
  } catch {
    return null;
  }
}

function parseWad(value: string | null): number | null {
  if (!value) return null;
  const parsed = Number(value) / 1e18;
  return Number.isFinite(parsed) ? parsed : null;
}

function buildTrendSeries(
  seniorNav: string | null,
  juniorNav: string | null,
) {
  const seniorBase = parseWad(seniorNav) ?? 1.0;
  const juniorBase = parseWad(juniorNav) ?? 1.0;

  return VAULT_TREND_POINTS.map((point) => ({
    label: point.label,
    seniorSharePrice: seniorBase * point.seniorFactor,
    juniorSharePrice: juniorBase * point.juniorFactor,
  }));
}

function isAddressLike(value: string) {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

function isTxHashLike(value: string) {
  return /^0x[a-fA-F0-9]{64}$/.test(value);
}

function explorerAddressHref(address: string) {
  return `${PHAROS_ATLANTIC.explorerUrl}/address/${address}`;
}

function explorerTxHref(txHash: string) {
  return `${PHAROS_ATLANTIC.explorerUrl}/tx/${txHash}`;
}

function AddressLink({ address }: { address: string }) {
  if (!isAddressLike(address)) return <span>{address}</span>;
  return (
    <a
      href={explorerAddressHref(address)}
      target="_blank"
      rel="noreferrer"
      className="mono"
      title="Open in block explorer"
    >
      {address}
    </a>
  );
}

export default async function VaultDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const vault = await getVaultById(id);
  if (!vault) {
    notFound();
  }

  const activity = getActivityForVault(vault.vaultId);
  const isLive = vault.uiConfig.status === "LIVE";
  const cloneImpls =
    vault.chain === "pharos-atlantic"
      ? {
          trancheControllerImpl: PHAROS_ATLANTIC.pontusInfra.trancheControllerImpl,
          trancheTokenImpl: PHAROS_ATLANTIC.pontusInfra.trancheTokenImpl,
        }
      : null;
  const seniorMix = seniorMixPercent(vault.metrics.tvl, vault.metrics.seniorDebt);
  const juniorMix = seniorMix === null ? null : Math.max(0, 100 - seniorMix);
  const updatedLabel = formatRelativeTimestamp(vault.metrics.updatedAt);
  const mobileVaultTitle = vault.name.replace(/^Pontus Vault\s+/i, "").trim() || vault.name;
  const strategyLabel =
    vault.uiConfig.routeLabel ??
    (vault.uiConfig.strategyKeys && vault.uiConfig.strategyKeys.length > 0
      ? vault.uiConfig.strategyKeys.join(" + ")
      : "Multi-strategy");
  const trendSeries = buildTrendSeries(
    vault.metrics.seniorPrice,
    vault.metrics.juniorPrice,
  );
  const assetAllocation = buildAssetAllocation(strategyLabel, vault.metrics.tvl);

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Vault detail</p>
        <h1 className="vault-title">
          <span className="vault-title__text vault-title__text--desktop">{vault.name}</span>
          <span className="vault-title__text vault-title__text--mobile">{mobileVaultTitle}</span>
        </h1>
        <p className="muted">{vault.uiConfig.summary}</p>
        <div className="card-actions vault-head-status">
          <span className={`badge ${isLive ? "badge--live" : "badge--soon"}`}>
            {vault.uiConfig.status}
          </span>
          <TokenBadge symbol={vault.assetSymbol} />
        </div>
        <div className="vault-profile-grid">
          <article className="card vault-profile-item">
            <span className="stat-label">Quote asset</span>
            <strong>{vault.assetSymbol}</strong>
          </article>
          <article className="card vault-profile-item">
            <span className="stat-label">Risk profile</span>
            <strong>{vault.uiConfig.risk ?? "N/A"}</strong>
          </article>
          <article className="card vault-profile-item">
            <span className="stat-label">Route</span>
            <strong>{strategyLabel}</strong>
          </article>
        </div>
      </section>

      <div className="vault-detail-layout">
        <div className="vault-detail-main">
          <section className="section section--compact reveal">
            <div className="detail-yield-grid">
              <article className="card card--priority">
                <div className="stat-label">Senior APY</div>
                <div className="yield-value">{formatBps(vault.metrics.seniorApyBps ?? null)}</div>
              </article>
              <article className="card card--priority">
                <div className="stat-label">Junior APY</div>
                <div className="yield-value">{formatBps(vault.metrics.juniorApyBps ?? null)}</div>
              </article>
            </div>
          </section>

          <section className="section section--tight reveal">
            <div className="stat-grid">
              <article className="card">
                <div className="stat-label">TVL</div>
                <div className="stat-value">{formatUsd(vault.metrics.tvl)}</div>
                <p className="micro">Updated {updatedLabel}</p>
              </article>
              <article className="card">
                <div className="stat-label">Senior Share Price</div>
                <div className="stat-value">{formatSharePrice(vault.metrics.seniorPrice)}</div>
                <p className="muted">Debt: {formatUsd(vault.metrics.seniorDebt)}</p>
              </article>
              <article className="card">
                <div className="stat-label">Junior Share Price</div>
                <div className="stat-value">{formatSharePrice(vault.metrics.juniorPrice)}</div>
                <p className="muted">Supply: {formatUsd(vault.metrics.juniorSupply)}</p>
              </article>
            </div>
          </section>

          <section className="section section--tight reveal">
            <VaultPerformanceChart points={trendSeries} />
          </section>

          <section className="section section--compact reveal">
            <VaultAssetAllocationChart slices={assetAllocation} />
          </section>

          <section className="section section--compact reveal">
            <div className="grid grid-2">
              <article className="card">
                <h3>Vault terms</h3>
                <div className="list-rows">
                  <div className="row">
                    <span className="key">Asset</span>
                    <span className="value">
                      <TokenBadge symbol={vault.assetSymbol} />
                    </span>
                  </div>
                  <div className="row">
                    <span className="key">Strategies</span>
                    <span className="value">{strategyLabel}</span>
                  </div>
                  <div className="row">
                    <span className="key">Risk</span>
                    <span className="value">{vault.uiConfig.risk ?? "N/A"}</span>
                  </div>
                  <div className="row">
                    <span className="key">Policy</span>
                    <span className="value">{vault.uiConfig.banner ?? "N/A"}</span>
                  </div>
                </div>
              </article>

              <article className="card">
                <h3>Execution setup</h3>
                <div className="list-rows">
                  <div className="row">
                    <span className="key">Status</span>
                    <span className="value">{vault.uiConfig.status}</span>
                  </div>
                  <div className="row">
                    <span className="key">Chain</span>
                    <span className="value">{vault.chain}</span>
                  </div>
                  <div className="row">
                    <span className="key">Teller</span>
                    <span className="value">
                      <AddressLink address={vault.tellerAddress} />
                    </span>
                  </div>
                  <div className="row">
                    <span className="key">Manager</span>
                    <span className="value">
                      <AddressLink address={vault.managerAddress} />
                    </span>
                  </div>
                  {isTxHashLike(vault.uiConfig.deployTxHash ?? "") ? (
                    <div className="row">
                      <span className="key">Deploy tx</span>
                      <span className="value">
                        <a
                          href={explorerTxHref(vault.uiConfig.deployTxHash!)}
                          target="_blank"
                          rel="noreferrer"
                          className="mono"
                          title="Open in block explorer"
                        >
                          {vault.uiConfig.deployTxHash}
                        </a>
                      </span>
                    </div>
                  ) : null}
                </div>
                {isLive ? null : (
                  <div className="card-actions">
                    <Link className="button button--ghost" href="/discover">
                      Browse live vaults
                    </Link>
                  </div>
                )}
              </article>
            </div>
          </section>

          <section className="section section--compact reveal">
            <article className="card">
              <h3>Tranche allocation</h3>
              <div className="mix-chart">
                <div className="mix-chart__bar" aria-hidden="true">
                  <span className="mix-chart__senior" style={{ width: `${seniorMix ?? 0}%` }} />
                  <span className="mix-chart__junior" style={{ width: `${juniorMix ?? 0}%` }} />
                </div>
                <div className="mix-chart__legend">
                  <span>Senior {seniorMix === null ? "—" : `${seniorMix.toFixed(2)}%`}</span>
                  <span>Junior {juniorMix === null ? "—" : `${juniorMix.toFixed(2)}%`}</span>
                </div>
              </div>
              <p className="micro">{`Updated ${updatedLabel}`}</p>
            </article>
          </section>

          <section className="section section--compact reveal">
            <article className="card">
              <h3>Addresses</h3>
                <div className="list-rows">
                  <div className="row">
                    <span className="key">
                      {cloneImpls ? "TrancheController (clone)" : "TrancheController"}
                    </span>
                    <span className="value">
                      <AddressLink address={vault.controllerAddress} />
                      {cloneImpls ? (
                        <div className="micro muted">
                          Minimal proxy (EIP-1167). Verified impl:{" "}
                          <AddressLink address={cloneImpls.trancheControllerImpl} />
                        </div>
                      ) : null}
                    </span>
                  </div>
                  <div className="row">
                    <span className="key">
                      {cloneImpls ? "SeniorToken (clone)" : "SeniorToken"}
                    </span>
                    <span className="value">
                      <AddressLink address={vault.seniorTokenAddress} />
                      {cloneImpls ? (
                        <div className="micro muted">
                          Minimal proxy (EIP-1167). Verified impl:{" "}
                          <AddressLink address={cloneImpls.trancheTokenImpl} />
                        </div>
                      ) : null}
                    </span>
                  </div>
                  <div className="row">
                    <span className="key">
                      {cloneImpls ? "JuniorToken (clone)" : "JuniorToken"}
                    </span>
                    <span className="value">
                      <AddressLink address={vault.juniorTokenAddress} />
                      {cloneImpls ? (
                        <div className="micro muted">
                          Minimal proxy (EIP-1167). Verified impl:{" "}
                          <AddressLink address={cloneImpls.trancheTokenImpl} />
                        </div>
                      ) : null}
                    </span>
                  </div>
                <div className="row">
                  <span className="key">BoringVault</span>
                  <span className="value">
                    <AddressLink address={vault.vaultAddress} />
                  </span>
                </div>
                <div className="row">
                  <span className="key">Teller</span>
                  <span className="value">
                    <AddressLink address={vault.tellerAddress} />
                  </span>
                </div>
              </div>
            </article>
          </section>

          <section className="section section--compact reveal">
            <article className="card">
              <h3>Activity feed</h3>
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Type</th>
                      <th>Tranche</th>
                      <th>Amount</th>
                      <th>Actor</th>
                      <th>Time</th>
                    </tr>
                  </thead>
                  <tbody>
                    {activity.map((entry) => (
                      <tr key={entry.id}>
                        <td>{entry.type}</td>
                        <td>{entry.tranche}</td>
                        <td>{entry.amount}</td>
                        <td>{entry.actor}</td>
                        <td>{entry.time}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>
          </section>
        </div>

        <aside className="vault-detail-cta reveal">
          {isLive ? (
            <VaultExecutionPanel vault={vault} />
          ) : (
            <article className="card card--spotlight" id="execute">
              <h3>Execution unavailable</h3>
              <p className="muted">
                {vault.name} is currently {vault.uiConfig.status}. Deposits and redeems are disabled
                until this vault is activated.
              </p>
              <div className="card-actions">
                <Link className="button button--ghost" href="/discover">
                  Browse live vaults
                </Link>
              </div>
            </article>
          )}
        </aside>
      </div>
    </main>
  );
}
