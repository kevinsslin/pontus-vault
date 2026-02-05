import Link from "next/link";
import { notFound } from "next/navigation";
import { getActivityForVault, getVaultById } from "../../../lib/data/vaults";
import { formatTimestamp, formatUsd, formatWad } from "../../../lib/format";

export default async function VaultDetailPage({ params }: { params: { id: string } }) {
  const vault = await getVaultById(params.id);
  if (!vault) {
    notFound();
  }

  const activity = getActivityForVault(vault.productId);
  const isLive = vault.uiConfig.status === "LIVE";

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
          <span className="chip">{vault.uiConfig.routeLabel}</span>
          <span className="chip">Risk: {vault.uiConfig.risk}</span>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="stat-grid">
          <div className="card">
            <div className="stat-label">TVL</div>
            <div className="stat-value">{formatUsd(vault.metrics.tvl)}</div>
            <p className="muted">Updated {formatTimestamp(vault.metrics.updatedAt)}</p>
          </div>
          <div className="card">
            <div className="stat-label">Senior Price</div>
            <div className="stat-value">{formatWad(vault.metrics.seniorPrice)}x</div>
            <p className="muted">Debt {formatUsd(vault.metrics.seniorDebt)}</p>
          </div>
          <div className="card">
            <div className="stat-label">Junior Price</div>
            <div className="stat-value">{formatWad(vault.metrics.juniorPrice)}x</div>
            <p className="muted">Supply {formatUsd(vault.metrics.juniorSupply)}</p>
          </div>
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="grid grid-3">
          <div className="card">
            <h3>Underlying</h3>
            <p className="muted">Asset: {vault.assetSymbol}</p>
            <p className="muted">Route: {vault.route}</p>
            <p className="muted">Chain: {vault.chain}</p>
            <p className="muted">Banner: {vault.uiConfig.banner}</p>
          </div>
          <div className="card">
            <h3>Actions</h3>
            <p className="muted">Deposit or redeem by tranche. Disabled if not LIVE.</p>
            <div className="card-actions">
              <Link
                className={`button ${!isLive ? "button--disabled" : ""}`}
                href={isLive ? `/vaults/${vault.productId}/deposit` : "#"}
                aria-disabled={!isLive}
                tabIndex={isLive ? 0 : -1}
              >
                Deposit
              </Link>
              <Link
                className={`button button--ghost ${!isLive ? "button--disabled" : ""}`}
                href={isLive ? `/vaults/${vault.productId}/redeem` : "#"}
                aria-disabled={!isLive}
                tabIndex={isLive ? 0 : -1}
              >
                Redeem
              </Link>
            </div>
          </div>
          <div className="card">
            <h3>Addresses</h3>
            <p className="muted">Controller: {vault.controllerAddress}</p>
            <p className="muted">Senior token: {vault.seniorTokenAddress}</p>
            <p className="muted">Junior token: {vault.juniorTokenAddress}</p>
            <p className="muted">Vault: {vault.vaultAddress}</p>
          </div>
        </div>
      </section>

      <section className="section reveal delay-3">
        <div className="card">
          <h3>Activity</h3>
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
      </section>
    </main>
  );
}
