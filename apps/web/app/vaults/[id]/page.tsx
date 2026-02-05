import Link from "next/link";
import { notFound } from "next/navigation";
import { getActivityForVault, getVaultById } from "../../../lib/data/vaults";
import { formatTimestamp, formatUsd, formatWad } from "../../../lib/format";

export default async function VaultDetailPage({ params }: { params: { id: string } }) {
  const vault = await getVaultById(params.id);
  if (!vault) {
    notFound();
  }

  const activity = getActivityForVault(vault.vaultId);
  const isLive = vault.uiConfig.status === "LIVE";
  const tags = vault.uiConfig.tags ?? [];

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
        <div className="stat-grid">
          <article className="card">
            <div className="stat-label">TVL</div>
            <div className="stat-value">{formatUsd(vault.metrics.tvl)}</div>
            <p className="muted">Updated {formatTimestamp(vault.metrics.updatedAt)}</p>
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
                <span className="value">{vault.assetSymbol}</span>
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
