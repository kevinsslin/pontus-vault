import Link from "next/link";
import { getPortfolioSnapshot } from "../../lib/data/vaults";

export default function PortfolioPage() {
  const portfolio = getPortfolioSnapshot();
  const positionCount = portfolio.positions.length;

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Portfolio</p>
        <h1>Cross-vault tranche exposure in one ledger.</h1>
        <p className="muted">
          Track senior stability sleeves and junior upside sleeves with consistent
          accounting across all Pontus products.
        </p>
        <div className="card-actions">
          <span className="chip">Positions: {positionCount}</span>
          <span className="chip">Products: {new Set(portfolio.positions.map((p) => p.productId)).size}</span>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="stat-grid">
          <div className="card">
            <div className="stat-label">Total value</div>
            <div className="stat-value">{portfolio.totalValue}</div>
            <p className="muted">Marked-to-model from latest tranche prices.</p>
          </div>
          <div className="card">
            <div className="stat-label">24h change</div>
            <div className="stat-value">{portfolio.dayChange}</div>
            <p className="muted">Blended daily return across active sleeves.</p>
          </div>
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="card">
          <h3>Position ledger</h3>
          <table className="table">
            <thead>
              <tr>
                <th>Product</th>
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
            <Link className="button" href="/discover">
              Discover products
            </Link>
            <Link className="button button--ghost" href="/discover">
              Add exposure
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}
