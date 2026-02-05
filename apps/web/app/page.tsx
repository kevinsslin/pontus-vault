import Link from "next/link";
import VaultCard from "./components/VaultCard";
import { getVaults } from "../lib/data/vaults";
import { formatUsd, formatWad } from "../lib/format";

const PARTNER_LOGOS = [
  { mark: "OF", name: "OpenFi" },
  { mark: "PL", name: "Plume" },
  { mark: "ON", name: "Ondo" },
  { mark: "SU", name: "Superstate" },
  { mark: "CF", name: "Centrifuge" },
  { mark: "SR", name: "Securitize" },
];

function totalTvl(vaults: Awaited<ReturnType<typeof getVaults>>): string {
  const sum = vaults.reduce((acc, vault) => {
    const value = vault.metrics.tvl;
    if (!value) return acc;
    return acc + BigInt(value);
  }, 0n);
  return sum.toString();
}

function averageSeniorPrice(vaults: Awaited<ReturnType<typeof getVaults>>): string | null {
  const prices = vaults
    .map((vault) => vault.metrics.seniorPrice)
    .filter((value): value is string => Boolean(value));

  if (prices.length === 0) {
    return null;
  }

  const total = prices.reduce((acc, value) => acc + BigInt(value), 0n);
  return (total / BigInt(prices.length)).toString();
}

export default async function HomePage() {
  const vaults = await getVaults();
  const featured = vaults.slice(0, 3);
  const liveVaults = vaults.filter((vault) => vault.uiConfig.status === "LIVE");
  const tvl = totalTvl(vaults);
  const avgSenior = averageSeniorPrice(liveVaults);

  return (
    <main className="page">
      <section className="hero reveal">
        <div className="hero__content">
          <p className="eyebrow">Pontus Vault</p>
          <h1>One click to structured yield across DeFi and RWA routes.</h1>
          <p className="muted">
            Pontus packages institutional-style tranche products for Pharos: senior sleeves for
            capital stability, junior sleeves for upside capture, and transparent accounting from
            indexer to execution.
          </p>
          <div className="card-actions">
            <Link className="button" href="/discover">
              Start discovery
            </Link>
            <Link className="button button--ghost" href="/portfolio">
              Open portfolio
            </Link>
          </div>

          <div className="partner-marquee" aria-label="Ecosystem integrations">
            <div className="partner-track">
              {[...PARTNER_LOGOS, ...PARTNER_LOGOS].map((partner, index) => (
                <span className="partner-pill" key={`${partner.name}-${index}`}>
                  <span className="partner-mark">{partner.mark}</span>
                  {partner.name}
                </span>
              ))}
            </div>
          </div>
        </div>

        <aside className="hero__panel reveal delay-1">
          <p className="eyebrow">Platform snapshot</p>
          <h3>Capital routing with tranche-native controls.</h3>
          <div className="hero__kpi">
            <div className="kpi">
              <span className="label">Vault TVL</span>
              <span className="value">{formatUsd(tvl)}</span>
            </div>
            <div className="kpi">
              <span className="label">Live products</span>
              <span className="value">{liveVaults.length}</span>
            </div>
            <div className="kpi">
              <span className="label">Senior NAV</span>
              <span className="value">{formatWad(avgSenior)}x</span>
            </div>
            <div className="kpi">
              <span className="label">Upcoming</span>
              <span className="value">{vaults.length - liveVaults.length}</span>
            </div>
          </div>
          <p className="muted">Indexing, metadata, and execution paths are kept interface-consistent.</p>
        </aside>
      </section>

      <section className="section reveal delay-2">
        <div className="section-title">
          <h2>How Pontus works</h2>
        </div>
        <div className="grid grid-3">
          <div className="card card--spotlight">
            <h3>Design tranches</h3>
            <p className="muted">
              Compose senior and junior sleeves with explicit caps, waterfalls, and policy labels.
            </p>
          </div>
          <div className="card card--spotlight">
            <h3>Route capital</h3>
            <p className="muted">
              Allocate through allowlisted paths such as OpenFi lending and future RWA adapters.
            </p>
          </div>
          <div className="card card--spotlight">
            <h3>Read performance</h3>
            <p className="muted">
              Consume event snapshots, hourly and daily aggregates, and portfolio-ready metrics.
            </p>
          </div>
        </div>
      </section>

      <section className="section reveal delay-3">
        <div className="section-title">
          <h2>Featured vaults</h2>
          <Link className="button button--ghost" href="/discover">
            View all vaults
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
