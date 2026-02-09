import VaultCard from "../components/VaultCard";
import { getVaults } from "../../lib/data/vaults";

type DiscoverPageProps = {
  searchParams?: Promise<{
    focus?: string;
  }>;
};

function toNumber(value: string | null | undefined): number {
  if (!value) return 0;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

export default async function DiscoverPage({ searchParams }: DiscoverPageProps) {
  const params = searchParams ? await searchParams : {};
  const focus = params.focus?.toLowerCase() ?? "";
  const vaults = await getVaults();
  const rankedVaults = [...vaults];

  if (focus === "senior") {
    const riskScore = (risk: string | null | undefined) => {
      if (risk === "LOW") return 0;
      if (risk === "MEDIUM") return 1;
      return 2;
    };
    rankedVaults.sort((a, b) => {
      const score = riskScore(a.uiConfig.risk) - riskScore(b.uiConfig.risk);
      if (score !== 0) return score;
      return toNumber(b.metrics.seniorApyBps) - toNumber(a.metrics.seniorApyBps);
    });
  } else if (focus === "junior") {
    rankedVaults.sort(
      (a, b) => toNumber(b.metrics.juniorApyBps) - toNumber(a.metrics.juniorApyBps)
    );
  } else if (focus === "balanced") {
    rankedVaults.sort((a, b) => {
      const aSpread = Math.abs(toNumber(a.metrics.juniorApyBps) - toNumber(a.metrics.seniorApyBps));
      const bSpread = Math.abs(toNumber(b.metrics.juniorApyBps) - toNumber(b.metrics.seniorApyBps));
      return aSpread - bSpread;
    });
  }

  const liveCount = vaults.filter((vault) => vault.uiConfig.status === "LIVE").length;
  const comingSoonCount = vaults.length - liveCount;
  const focusLabel =
    focus === "senior"
      ? "Senior stability lens"
      : focus === "balanced"
        ? "Balanced income lens"
        : focus === "junior"
          ? "Junior upside lens"
          : null;

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Discover</p>
        <h1>Tranche marketplace for professional allocators.</h1>
        <p className="muted">
          Compare live vaults and upcoming strategies with one consistent schema for risk labels,
          route metadata, and onchain metrics.
        </p>
        <div className="card-actions">
          <span className="chip">Live: {liveCount}</span>
          <span className="chip">Coming soon: {comingSoonCount}</span>
          <span className="chip">OpenFi routes</span>
          <span className="chip">RWA catalog</span>
          {focusLabel ? <span className="pill">{focusLabel}</span> : null}
        </div>
      </section>

      <section className="section reveal">
        <div className="grid grid-3">
          {rankedVaults.map((vault) => (
            <VaultCard key={vault.vaultId} vault={vault} />
          ))}
        </div>
      </section>
    </main>
  );
}
