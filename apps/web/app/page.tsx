import Image from "next/image";
import Link from "next/link";
import VaultCard from "./components/VaultCard";
import { getVaults } from "../lib/data/vaults";
import { formatRelativeTimestamp, formatUsd, formatWad } from "../lib/format";

const PARTNERS = [
  { name: "Pharos", logo: "/partners/pharos.png", href: "https://pharosnetwork.xyz", width: 190, height: 48 },
  { name: "Plume", logo: "/partners/plume-wordmark.png", href: "https://plumenetwork.xyz", width: 188, height: 64 },
  { name: "Ondo", logo: "/partners/ondo.svg", href: "https://ondo.finance", width: 184, height: 60 },
  { name: "Superstate", logo: "/partners/superstate-wordmark.png", href: "https://superstate.co", width: 220, height: 40 },
  { name: "Centrifuge", logo: "/partners/centrifuge.svg", href: "https://centrifuge.io", width: 95, height: 31 },
  { name: "Sky", logo: "/partners/sky.svg", href: "https://sky.money", width: 84, height: 35 },
  { name: "BlockTower", logo: "/partners/blocktower.svg", href: "https://blocktower.com", width: 194, height: 62 },
  { name: "Parafi", logo: "/partners/parafi.svg", href: "https://parafi.com", width: 194, height: 62 },
  { name: "Janus Henderson", logo: "/partners/janus-henderson.svg", href: "https://www.janushenderson.com", width: 194, height: 62 },
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
    body: "Monitor yield, APY spread, and allocation shifts in one view.",
  },
];

const INVESTOR_LANES = [
  {
    title: "Senior Focus",
    subtitle: "Capital stability",
    body: "Target lower volatility with tighter downside exposure.",
    cta: "View senior-priority vaults",
    href: "/discover?focus=senior",
    seniorShare: 82,
    juniorShare: 18,
    signal: "Expected APY: 6% to 9%",
  },
  {
    title: "Balanced Split",
    subtitle: "Income optimization",
    body: "Blend senior carry with junior upside in one allocation policy.",
    cta: "Compare blended profiles",
    href: "/discover?focus=balanced",
    seniorShare: 64,
    juniorShare: 36,
    signal: "Expected APY: 8% to 13%",
  },
  {
    title: "Junior Focus",
    subtitle: "Return acceleration",
    body: "Take higher beta against structured downside boundaries.",
    cta: "Explore high-upside lanes",
    href: "/discover?focus=junior",
    seniorShare: 35,
    juniorShare: 65,
    signal: "Expected APY: 11% to 19%",
  },
];

const STACK_LAYERS = [
  {
    layer: "Layer 03",
    title: "Risk Tranching Layer",
    body: "Package risk into senior and junior slices so each allocator chooses a defined payoff profile.",
    tags: ["Senior sleeve", "Junior sleeve", "Risk budgeted"],
  },
  {
    layer: "Layer 02",
    title: "Vault Orchestration Layer",
    body: "Aggregate routes, policy controls, and accounting into one coherent vault product surface.",
    tags: ["Policy engine", "Unified yield", "Execution controls"],
  },
  {
    layer: "Layer 01",
    title: "Yield Sources Layer",
    body: "Connect productive base assets across DeFi and RWA channels where real yield is generated.",
    tags: ["Lending markets", "Treasury/RWA", "Credit routes"],
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

function latestUpdatedAt(vaults: Awaited<ReturnType<typeof getVaults>>): string {
  const freshest = vaults.reduce((latest, vault) => {
    const ts = Number(vault.metrics.updatedAt ?? 0);
    if (!Number.isFinite(ts)) return latest;
    return ts > latest ? ts : latest;
  }, 0);
  return freshest > 0 ? formatRelativeTimestamp(String(freshest)) : "—";
}

export default async function HomePage() {
  const vaults = await getVaults();
  const featured = vaults.slice(0, 3);
  const liveVaults = vaults.filter((vault) => vault.uiConfig.status === "LIVE");
  const tvl = totalTvl(vaults);
  const avgSenior = averageSeniorPrice(liveVaults);
  const avgSeniorLabel = avgSenior ? `${formatWad(avgSenior)}x` : "—";
  const liveCountLabel = `${liveVaults.length} vault${liveVaults.length === 1 ? "" : "s"} live`;
  const updateLabel = latestUpdatedAt(liveVaults);

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
        </div>

        <aside className="hero__panel hero__panel--compact reveal delay-1">
          <p className="eyebrow">Platform snapshot</p>
          <h3>Capital routing with tranche-native controls.</h3>
          <div className="hero__aum-card">
            <span className="label">Total AUM</span>
            <span className="hero__aum-value">{formatUsd(tvl)}</span>
            <span className="hero__aum-note">{liveCountLabel}</span>
          </div>
          <div className="hero__mini">
            <div className="mini">
              <span>Live vaults</span>
              <strong>{liveVaults.length}</strong>
            </div>
            <div className="mini">
              <span>Senior Yield</span>
              <strong>{avgSeniorLabel}</strong>
            </div>
            <div className="mini">
              <span>Last update</span>
              <strong>{updateLabel}</strong>
            </div>
          </div>
          <p className="muted">
            Discovery, allocation, and reporting stay aligned in one decision-ready interface.
          </p>
        </aside>

        <div className="partner-marquee hero__marquee" aria-label="Featured ecosystem integrations">
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
                  alt={`${partner.name} wordmark`}
                  width={partner.width}
                  height={partner.height}
                  className="partner-logo"
                />
                <span className="sr-only">{partner.name}</span>
              </a>
            ))}
          </div>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="section-copy">
          <p className="eyebrow">Operating model</p>
          <h2>Operating model</h2>
          <p className="muted">
            Pontus keeps each stage explicit: profile the allocator, compare routes, execute by
            tranche, then monitor performance with one consistent interpretation layer.
          </p>
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
        <div className="section-copy">
          <p className="eyebrow">Vault stack</p>
          <h2>Three layers, one investable product surface.</h2>
          <p className="muted">
            Pontus separates where yield is produced, how vaults orchestrate that yield, and how
            risk is finally distributed to users. This makes the product understandable and auditable.
          </p>
        </div>
        <div className="stack-rail">
          {STACK_LAYERS.map((stage) => (
            <article className="card stack-tier" key={stage.title}>
              <span className="stack-tier__layer">{stage.layer}</span>
              <h3>{stage.title}</h3>
              <p className="muted">{stage.body}</p>
              <div className="card-actions">
                {stage.tags.map((tag) => (
                  <span className="chip chip--soft" key={tag}>
                    {tag}
                  </span>
                ))}
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="section reveal delay-2">
        <div className="section-copy">
          <p className="eyebrow">Allocation styles</p>
          <h2>Choose your lane</h2>
          <p className="muted">
            Pick the mandate shape that matches your risk appetite, then jump directly into
            discovery with that lens applied.
          </p>
        </div>
        <div className="grid grid-3">
          {INVESTOR_LANES.map((lane) => (
            <article className="card" key={lane.title}>
              <p className="eyebrow">{lane.subtitle}</p>
              <h3>{lane.title}</h3>
              <p className="muted">{lane.body}</p>
              <div className="lane-split" aria-hidden="true">
                <span className="lane-split__senior" style={{ width: `${lane.seniorShare}%` }} />
                <span className="lane-split__junior" style={{ width: `${lane.juniorShare}%` }} />
              </div>
              <div className="lane-metrics">
                <span>{`Senior ${lane.seniorShare}%`}</span>
                <span>{`Junior ${lane.juniorShare}%`}</span>
              </div>
              <p className="micro lane-signal">{lane.signal}</p>
              <div className="card-actions">
                <Link className="button button--ghost" href={lane.href}>
                  {lane.cta}
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
