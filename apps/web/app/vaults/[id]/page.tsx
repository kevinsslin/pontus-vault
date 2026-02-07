import Link from "next/link";
import { notFound } from "next/navigation";
import { getActivityForVault, getVaultById } from "../../../lib/data/vaults";
import { formatBps, formatRelativeTimestamp, formatUsd, formatWad } from "../../../lib/format";
import TokenBadge from "../../components/TokenBadge";
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

function parseBps(value: string | null): number | null {
  if (!value) return null;
  const parsed = Number(value) / 100;
  return Number.isFinite(parsed) ? parsed : null;
}

function buildTrendSeries(
  seniorNav: string | null,
  juniorNav: string | null,
  seniorApyBps: string | null,
  juniorApyBps: string | null
) {
  const seniorBase = parseWad(seniorNav) ?? 1.0;
  const juniorBase = parseWad(juniorNav) ?? 1.0;
  const seniorApyBase = parseBps(seniorApyBps) ?? 8;
  const juniorApyBase = parseBps(juniorApyBps) ?? 14;

  const labels = ["W-12", "W-10", "W-8", "W-6", "W-4", "W-2", "Now"];
  const seniorFactors = [0.992, 0.995, 0.997, 1.0, 1.002, 1.004, 1.006];
  const juniorFactors = [0.93, 0.95, 0.98, 1.0, 1.03, 1.06, 1.09];
  const apySeniorFactors = [0.98, 1.0, 1.03, 1.0, 0.97, 1.02, 1.01];
  const apyJuniorFactors = [0.9, 0.95, 1.05, 1.0, 1.08, 1.12, 1.04];

  return labels.map((label, index) => ({
    label,
    seniorNav: seniorBase * seniorFactors[index],
    juniorNav: juniorBase * juniorFactors[index],
    seniorApy: seniorApyBase * apySeniorFactors[index],
    juniorApy: juniorApyBase * apyJuniorFactors[index],
  }));
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
  const seniorMix = seniorMixPercent(vault.metrics.tvl, vault.metrics.seniorDebt);
  const juniorMix = seniorMix === null ? null : Math.max(0, 100 - seniorMix);
  const updatedLabel = formatRelativeTimestamp(vault.metrics.updatedAt);
  const mobileVaultTitle = vault.name.replace(/^Pontus Vault\s+/i, "").trim() || vault.name;
  const trendSeries = buildTrendSeries(
    vault.metrics.seniorPrice,
    vault.metrics.juniorPrice,
    vault.metrics.seniorApyBps ?? null,
    vault.metrics.juniorApyBps ?? null
  );

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Vault detail</p>
        <h1 className="vault-title">
          <span className="vault-title__text vault-title__text--desktop">{vault.name}</span>
          <span className="vault-title__text vault-title__text--mobile">{mobileVaultTitle}</span>
        </h1>
        <p className="muted">{vault.uiConfig.summary}</p>
        <div className="card-actions vault-meta">
          <span className={`badge ${isLive ? "badge--live" : "badge--soon"}`}>
            {vault.uiConfig.status}
          </span>
          <TokenBadge symbol={vault.assetSymbol} />
          <span className="chip">{vault.uiConfig.routeLabel ?? vault.route}</span>
          <span className="chip">Risk: {vault.uiConfig.risk ?? "N/A"}</span>
        </div>
      </section>

      <section className="section section--compact reveal delay-1">
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

      <section className="section section--tight reveal delay-1">
        <div className="stat-grid">
          <article className="card">
            <div className="stat-label">TVL</div>
            <div className="stat-value">{formatUsd(vault.metrics.tvl)}</div>
            <p className="micro">Updated {updatedLabel}</p>
          </article>
          <article className="card">
            <div className="stat-label">Senior Yield</div>
            <div className="stat-value">{formatWad(vault.metrics.seniorPrice)}x</div>
            <p className="muted">Debt: {formatUsd(vault.metrics.seniorDebt)}</p>
          </article>
          <article className="card">
            <div className="stat-label">Junior Yield</div>
            <div className="stat-value">{formatWad(vault.metrics.juniorPrice)}x</div>
            <p className="muted">Supply: {formatUsd(vault.metrics.juniorSupply)}</p>
          </article>
        </div>
      </section>

      <section className="section section--tight reveal delay-1">
        <VaultPerformanceChart points={trendSeries} />
      </section>

      <section className="section section--compact reveal delay-2">
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
                <span className="key">Route</span>
                <span className="value">{vault.route}</span>
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
                <span className="value">{vault.tellerAddress}</span>
              </div>
            </div>
            {isLive ? null : (
              <>
                <div className="card-actions">
                  <Link className="button button--ghost" href="/discover">
                    Browse live vaults
                  </Link>
                </div>
              </>
            )}
          </article>
        </div>
      </section>

      {isLive ? (
        <VaultExecutionPanel vault={vault} />
      ) : (
        <section className="section section--compact reveal delay-2" id="execute">
          <article className="card card--spotlight">
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
        </section>
      )}

      <section className="section section--compact reveal delay-2">
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

      <section className="section section--compact reveal delay-3">
        <article className="card">
          <h3>Addresses</h3>
          <div className="list-rows">
            <div className="row">
              <span className="key">Controller</span>
              <span className="value">{vault.controllerAddress}</span>
            </div>
            <div className="row">
              <span className="key">Senior token</span>
              <span className="value">{vault.seniorTokenAddress}</span>
            </div>
            <div className="row">
              <span className="key">Junior token</span>
              <span className="value">{vault.juniorTokenAddress}</span>
            </div>
            <div className="row">
              <span className="key">Vault / Teller</span>
              <span className="value">
                {vault.vaultAddress} / {vault.tellerAddress}
              </span>
            </div>
          </div>
        </article>
      </section>

      <section className="section section--compact reveal delay-3">
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
    </main>
  );
}
