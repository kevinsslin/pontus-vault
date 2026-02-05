import { getVaults } from "../../lib/data/vaults";

export default async function OperatorPage() {
  const vaults = await getVaults();

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Operator</p>
        <h1>Management console</h1>
        <p className="muted">
          Configure routing and watch tranche health. Actions are mocked for the hackathon
          build.
        </p>
      </section>

      <section className="section reveal delay-1">
        <div className="grid">
          {vaults.map((vault) => (
            <div className="card" key={vault.productId}>
              <h3>{vault.name}</h3>
              <p className="muted">Route: {vault.uiConfig.routeLabel}</p>
              <p className="muted">Status: {vault.uiConfig.status}</p>
              <div className="card-actions">
                <button className="button" type="button">
                  Allocate to OpenFi
                </button>
                <button className="button button--ghost" type="button">
                  Pause vault
                </button>
                <button className="button button--ghost" type="button">
                  Update caps
                </button>
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
