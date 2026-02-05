import { getVaults } from "../../lib/data/vaults";

export default async function OperatorPage() {
  const vaults = await getVaults();
  const liveCount = vaults.filter((vault) => vault.uiConfig.status === "LIVE").length;

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Operator</p>
        <h1>Policy console for tranche routing.</h1>
        <p className="muted">
          Configure route permissions, caps, and safety controls for each product.
          Execution buttons are disabled in this build until live operators are wired.
        </p>
        <div className="card-actions">
          <span className="chip">Live products: {liveCount}</span>
          <span className="chip">Total products: {vaults.length}</span>
          <span className="chip">Role: Operator</span>
        </div>
      </section>

      <section className="section reveal delay-1">
        <div className="grid">
          {vaults.map((vault) => (
            <div className="card" key={vault.productId}>
              <h3>{vault.name}</h3>
              <p className="muted">Route: {vault.uiConfig.routeLabel ?? vault.route}</p>
              <p className="muted">Status: {vault.uiConfig.status}</p>
              <div className="list-rows">
                <div className="row">
                  <span className="key">Risk label</span>
                  <span className="value">{vault.uiConfig.risk ?? "N/A"}</span>
                </div>
                <div className="row">
                  <span className="key">Controller</span>
                  <span className="value">{vault.controllerAddress}</span>
                </div>
              </div>
              <div className="card-actions">
                <button className="button button--disabled" type="button" disabled>
                  Allocate to OpenFi
                </button>
                <button className="button button--ghost button--disabled" type="button" disabled>
                  Pause vault
                </button>
                <button className="button button--ghost button--disabled" type="button" disabled>
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
