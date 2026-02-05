import Link from "next/link";
import { getPortfolioSnapshot } from "../../lib/data/vaults";

export default function PortfolioPage() {
  const portfolio = getPortfolioSnapshot();

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Portfolio</p>
        <h1>Your tranche exposure</h1>
        <p className="muted">Aggregate view across senior and junior positions.</p>
      </section>

      <section className="section reveal delay-1">
        <div className="stat-grid">
          <div className="card">
            <div className="stat-label">Total value</div>
            <div className="stat-value">{portfolio.totalValue}</div>
          </div>
          <div className="card">
            <div className="stat-label">24h change</div>
            <div className="stat-value">{portfolio.dayChange}</div>
          </div>
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="card">
          <h3>Positions</h3>
          <table className="table">
            <thead>
              <tr>
                <th>Vault</th>
                <th>Tranche</th>
                <th>Shares</th>
                <th>Value</th>
                <th>PnL</th>
              </tr>
            </thead>
            <tbody>
              {portfolio.positions.map((position) => (
                <tr key={`${position.productId}-${position.tranche}`}>
                  <td>{position.name}</td>
                  <td>{position.tranche}</td>
                  <td>{position.shares}</td>
                  <td>{position.value}</td>
                  <td>{position.pnl}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="card-actions">
            <Link className="button button--ghost" href="/discover">
              Add exposure
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}
