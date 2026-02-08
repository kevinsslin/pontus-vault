import Image from "next/image";
import Link from "next/link";
import VaultCard from "./components/VaultCard";
import {
  LANDING_INVESTOR_LANES,
  LANDING_PARTNERS,
  LANDING_STACK_LAYERS,
  LANDING_WORKFLOW_STEPS,
} from "../lib/constants/landing";
import { getVaults } from "../lib/data/vaults";
import { formatRelativeTimestamp, formatSharePrice, formatUsd } from "../lib/format";

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
  const avgSeniorLabel = avgSenior ? formatSharePrice(avgSenior) : "—";
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
              <span>Senior Share Price</span>
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
            {[...LANDING_PARTNERS, ...LANDING_PARTNERS].map((partner, index) => (
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
          {LANDING_WORKFLOW_STEPS.map((item) => (
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
          {LANDING_STACK_LAYERS.map((stage) => (
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
          {LANDING_INVESTOR_LANES.map((lane) => (
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
