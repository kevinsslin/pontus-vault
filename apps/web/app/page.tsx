import Link from "next/link";
import VaultCard from "./components/VaultCard";
import { getVaults } from "../lib/data/vaults";

export default async function HomePage() {
  const vaults = await getVaults();
  const featured = vaults.slice(0, 3);

  return (
    <main className="page">
      <section className="hero reveal">
        <div>
          <p className="eyebrow">Pontus Vault</p>
          <h1>Tranche vault infrastructure for Pharos.</h1>
          <p className="muted">
            Structure yield into senior and junior risk sleeves. Route capital to vetted
            strategies while keeping discovery, metrics, and activity transparent.
          </p>
          <div className="card-actions">
            <Link className="button" href="/discover">
              Explore vaults
            </Link>
            <Link className="button button--ghost" href="/portfolio">
              View portfolio
            </Link>
          </div>
        </div>
        <div className="hero-panel reveal delay-1">
          <h3>Tranche split</h3>
          <p className="muted">
            Senior absorbs steady returns with caps. Junior takes the volatility and keeps
            upside.
          </p>
          <div className="hero-panel__meter">
            <div>
              <div className="stat-label">Senior sleeve</div>
              <div className="meter">
                <span style={{ width: "78%" }} />
              </div>
            </div>
            <div>
              <div className="stat-label">Junior sleeve</div>
              <div className="meter">
                <span style={{ width: "42%" }} />
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="section-title">
          <h2>How Pontus works</h2>
        </div>
        <div className="grid grid-3">
          <div className="card">
            <h3>Structure</h3>
            <p className="muted">
              Split incoming capital into senior and junior tranches with explicit caps and
              loss absorption.
            </p>
          </div>
          <div className="card">
            <h3>Route</h3>
            <p className="muted">
              Operators manage strategy calls through allowlisted adapters and OpenFi
              integrations.
            </p>
          </div>
          <div className="card">
            <h3>Observe</h3>
            <p className="muted">
              Goldsky snapshots and activity feed keep pricing, TVL, and flows visible in one
              place.
            </p>
          </div>
        </div>
      </section>

      <section className="section reveal delay-3">
        <div className="section-title">
          <h2>Featured vaults</h2>
          <Link className="button button--ghost" href="/discover">
            Discover all
          </Link>
        </div>
        <div className="grid grid-3">
          {featured.map((vault) => (
            <VaultCard key={vault.productId} vault={vault} />
          ))}
        </div>
      </section>
    </main>
  );
}
