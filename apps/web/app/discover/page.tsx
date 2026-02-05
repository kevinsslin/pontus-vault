import VaultCard from "../components/VaultCard";
import { getVaults } from "../../lib/data/vaults";

export default async function DiscoverPage() {
  const vaults = await getVaults();

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Discover</p>
        <h1>Tranche vaults on Pharos</h1>
        <p className="muted">
          Browse live and upcoming products. Metrics update from the indexer, while metadata
          and status are curated in Supabase.
        </p>
        <div className="card-actions">
          <span className="chip">LIVE</span>
          <span className="chip">COMING SOON</span>
          <span className="chip">OpenFi</span>
          <span className="chip">RWA</span>
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
