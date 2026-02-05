import VaultCard from "../components/VaultCard";
import { getVaults } from "../../lib/data/vaults";

export default async function DiscoverPage() {
  const vaults = await getVaults();
  const liveCount = vaults.filter((vault) => vault.uiConfig.status === "LIVE").length;
  const comingSoonCount = vaults.length - liveCount;

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Discover</p>
        <h1>Tranche marketplace for professional allocators.</h1>
        <p className="muted">
          Compare live products and upcoming strategies with one consistent schema for risk labels,
          route metadata, and onchain metrics.
        </p>
        <div className="card-actions">
          <span className="chip">Live: {liveCount}</span>
          <span className="chip">Coming soon: {comingSoonCount}</span>
          <span className="chip">OpenFi routes</span>
          <span className="chip">RWA catalog</span>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="grid grid-3">
          {vaults.map((vault) => (
            <VaultCard key={vault.productId} vault={vault} />
          ))}
        </div>
      </section>
    </main>
  );
}
