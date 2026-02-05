import Link from "next/link";
import { notFound } from "next/navigation";
import { getActivityForVault, getVaultById } from "../../../lib/data/vaults";
import {
  apySpreadBps,
  formatBps,
  formatRelativeTimestamp,
  formatTimestamp,
  formatUsd,
  formatWad,
} from "../../../lib/format";
import TokenBadge from "../../components/TokenBadge";

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
  const tags = vault.uiConfig.tags ?? [];
  const seniorMix = seniorMixPercent(vault.metrics.tvl, vault.metrics.seniorDebt);
  const juniorMix = seniorMix === null ? null : Math.max(0, 100 - seniorMix);
  const updatedLabel = formatRelativeTimestamp(vault.metrics.updatedAt);

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Vault detail</p>
        <h1>{vault.name}</h1>
        <p className="muted">{vault.uiConfig.summary}</p>
        <div className="card-actions">
          <span className={`badge ${isLive ? "badge--live" : "badge--soon"}`}>
            {vault.uiConfig.status}
          </span>
          <TokenBadge symbol={vault.assetSymbol} />
          <span className="chip">{vault.uiConfig.routeLabel ?? vault.route}</span>
          <span className="chip">Risk: {vault.uiConfig.risk ?? "N/A"}</span>
          {tags.map((tag) => (
            <span className="chip" key={tag}>
              {tag}
            </span>
          ))}
        </div>
        <div className="journey">
          <span className="chip chip--soft">1. Review vault profile</span>
          <span className="chip chip--soft">2. Pick tranche side</span>
          <span className="chip chip--soft">3. Execute deposit or redeem</span>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="detail-yield-grid">
          <article className="card card--priority">
            <div className="stat-label">Senior APY</div>
            <div className="yield-value">{formatBps(vault.metrics.seniorApyBps ?? null)}</div>
            <p className="micro">Target annualized rate for senior tranche.</p>
          </article>
          <article className="card card--priority">
            <div className="stat-label">Junior APY</div>
            <div className="yield-value">{formatBps(vault.metrics.juniorApyBps ?? null)}</div>
            <p className="micro">Junior side absorbs volatility for upside.</p>
          </article>
          <article className="card card--priority">
            <div className="stat-label">Yield spread</div>
            <div className="yield-value">
              {apySpreadBps(vault.metrics.seniorApyBps ?? null, vault.metrics.juniorApyBps ?? null)}
            </div>
            <p className="micro">Junior minus senior expected yield.</p>
          </article>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="stat-grid">
          <article className="card">
            <div className="stat-label">TVL</div>
            <div className="stat-value">{formatUsd(vault.metrics.tvl)}</div>
            <p className="micro">Updated {updatedLabel}</p>
          </article>
          <article className="card">
            <div className="stat-label">Senior NAV</div>
            <div className="stat-value">{formatWad(vault.metrics.seniorPrice)}x</div>
            <p className="muted">Debt: {formatUsd(vault.metrics.seniorDebt)}</p>
          </article>
          <article className="card">
            <div className="stat-label">Junior NAV</div>
            <div className="stat-value">{formatWad(vault.metrics.juniorPrice)}x</div>
            <p className="muted">Supply: {formatUsd(vault.metrics.juniorSupply)}</p>
          </article>
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="grid grid-2">
          <article className="card">
            <h3>Underlying and route</h3>
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
                <span className="key">Chain</span>
                <span className="value">{vault.chain}</span>
              </div>
              <div className="row">
                <span className="key">Policy note</span>
                <span className="value">{vault.uiConfig.banner ?? "N/A"}</span>
              </div>
            </div>
          </article>

          <article className="card">
            <h3>Execution flow</h3>
            {isLive ? (
              <>
                <p className="muted">
                  This vault is live. Continue to tranche actions from here. Deposit and redeem are
                  intentionally hidden from listing pages to keep the flow explicit.
                </p>
                <div className="card-actions">
                  <Link className="button" href={`/vaults/${vault.vaultId}/deposit`}>
                    Deposit
                  </Link>
                  <Link className="button button--ghost" href={`/vaults/${vault.vaultId}/redeem`}>
                    Redeem
                  </Link>
                </div>
              </>
            ) : (
              <>
                <p className="muted">
                  This vault is still in onboarding. You can review configuration and history, but
                  transaction actions are not enabled yet.
                </p>
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

      <section className="section reveal delay-2">
        <article className="card">
          <h3>Tranche allocation</h3>
          <p className="muted">
            Snapshot of capital distribution by tranche value. Senior is designed for stability,
            junior for leveraged upside.
          </p>
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
          <p className="micro">Onchain timestamp: {formatTimestamp(vault.metrics.updatedAt)}</p>
        </article>
      </section>

      <section className="section reveal delay-3">
        <article className="card">
          <h3>Contract wiring</h3>
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

      <section className="section reveal delay-3">
        <article className="card">
          <h3>Activity feed</h3>
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
        </article>
      </section>
    </main>
  );
}
