import Image from "next/image";
import Link from "next/link";
import VaultCard from "./components/VaultCard";
import { getVaults } from "../lib/data/vaults";
import { formatUsd, formatWad } from "../lib/format";

const PARTNERS = [
  { name: "OpenFi", logo: "/partners/openfi.png", href: "https://openfi.xyz" },
  { name: "Plume", logo: "/partners/plume.png", href: "https://plumenetwork.xyz" },
  { name: "Ondo", logo: "/partners/ondo.png", href: "https://ondo.finance" },
  { name: "Superstate", logo: "/partners/superstate.png", href: "https://superstate.co" },
  { name: "Centrifuge", logo: "/partners/centrifuge.png", href: "https://centrifuge.io" },
  { name: "Securitize", logo: "/partners/securitize.png", href: "https://securitize.io" },
];

const WORKFLOW_STEPS = [
  {
    step: "01",
    title: "Open App",
    body: "Connect your wallet and load your allocator profile.",
  },
  {
    step: "02",
    title: "Vault Discovery",
    body: "Compare live vaults by APY, tranche mix, and route quality.",
  },
  {
    step: "03",
    title: "Tranche Execution",
    body: "Select senior or junior lane and execute deposit or redeem.",
  },
  {
    step: "04",
    title: "Portfolio Intelligence",
    body: "Monitor NAV, APY spread, and allocation shifts in one view.",
  },
];

const INVESTOR_LANES = [
  {
    title: "Senior Focus",
    subtitle: "Capital stability",
    body: "Target lower volatility with tighter downside exposure.",
  },
  {
    title: "Balanced Split",
    subtitle: "Income optimization",
    body: "Blend senior carry with junior upside in one allocation policy.",
  },
  {
    title: "Junior Focus",
    subtitle: "Return acceleration",
    body: "Take higher beta against structured downside boundaries.",
  },
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

function apyBand(vaults: Awaited<ReturnType<typeof getVaults>>): string {
  const rates = vaults.flatMap((vault) => {
    const values = [vault.metrics.seniorApyBps, vault.metrics.juniorApyBps];
    return values.filter((value): value is string => Boolean(value)).map((value) => Number(value));
  });

  if (rates.length === 0) return "—";
  const min = Math.min(...rates);
  const max = Math.max(...rates);
  return `${(min / 100).toFixed(2)}% - ${(max / 100).toFixed(2)}%`;
}

export default async function HomePage() {
  const vaults = await getVaults();
  const featured = vaults.slice(0, 3);
  const liveVaults = vaults.filter((vault) => vault.uiConfig.status === "LIVE");
  const tvl = totalTvl(vaults);
  const avgSenior = averageSeniorPrice(liveVaults);
  const avgSeniorLabel = avgSenior ? `${formatWad(avgSenior)}x` : "—";
  const band = apyBand(liveVaults);

  return (
    <main className="page">
      <section className="hero reveal">
        <div className="hero__content">
          <p className="eyebrow">Pontus Vault</p>
          <h1>Structured yield vaults for professional capital on Pharos.</h1>
          <p className="muted">
            Pontus gives allocators a clean way to split exposure into senior and junior tranches,
            route capital into curated DeFi and RWA channels, and track performance with one
            coherent performance view.
          </p>
          <div className="hero__line" />
          <div className="card-actions">
            <Link className="button" href="/discover">
              Open app
            </Link>
            <Link className="button button--ghost" href="/discover">
              Go to vault discovery
            </Link>
          </div>

          <div className="trust-strip">
            <div className="trust-item">
              <span className="label">Capital profile</span>
              <span className="value">Senior and junior sleeves</span>
            </div>
            <div className="trust-item">
              <span className="label">Risk controls</span>
              <span className="value">Policy-driven downside boundaries</span>
            </div>
            <div className="trust-item">
              <span className="label">Distribution ready</span>
              <span className="value">Institutional-grade vault packaging</span>
            </div>
          </div>

          <div className="partner-marquee" aria-label="Featured ecosystem integrations">
            <div className="partner-track">
              {[...PARTNERS, ...PARTNERS].map((partner, index) => (
                <a
                  className="partner-pill"
                  href={partner.href}
                  key={`${partner.name}-${index}`}
                  rel="noreferrer"
                  target="_blank"
                >
                  <Image
                    src={partner.logo}
                    alt={`${partner.name} logo`}
                    width={40}
                    height={40}
                    className="partner-logo"
                  />
                  {partner.name}
                </a>
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
              <span className="label">Live vaults</span>
              <span className="value">{liveVaults.length}</span>
            </div>
            <div className="kpi">
              <span className="label">Senior NAV</span>
              <span className="value">{avgSeniorLabel}</span>
            </div>
            <div className="kpi">
              <span className="label">Expected APY band</span>
              <span className="value">{band}</span>
            </div>
          </div>
          <p className="muted">
            Discovery, allocation, and reporting stay aligned in one decision-ready interface.
          </p>
        </aside>
      </section>

      <section className="section reveal delay-1">
        <div className="section-title">
          <h2>Operating model</h2>
        </div>
        <div className="grid grid-4">
          {WORKFLOW_STEPS.map((item) => (
            <article className="card card--spotlight ops-card" key={item.step}>
              <span className="ops-step">{item.step}</span>
              <h3>{item.title}</h3>
              <p className="muted">{item.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="section-title">
          <h2>Capital flow</h2>
        </div>
        <article className="card architecture">
          <div className="arch-node">Mandate setup</div>
          <span className="arch-arrow">→</span>
          <div className="arch-node">Vault Discovery</div>
          <span className="arch-arrow">→</span>
          <div className="arch-node">Tranche allocation</div>
          <span className="arch-arrow">→</span>
          <div className="arch-node">Yield channels</div>
        </article>
      </section>

      <section className="section reveal delay-2">
        <div className="section-title">
          <h2>Choose your lane</h2>
        </div>
        <div className="grid grid-3">
          {INVESTOR_LANES.map((lane) => (
            <article className="card" key={lane.title}>
              <p className="eyebrow">{lane.subtitle}</p>
              <h3>{lane.title}</h3>
              <p className="muted">{lane.body}</p>
              <div className="card-actions">
                <Link className="button button--ghost" href="/discover">
                  Enter discovery
                </Link>
              </div>
            </article>
          ))}
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
            <VaultCard key={vault.vaultId} vault={vault} />
          ))}
        </div>
      </section>
    </main>
  );
}
