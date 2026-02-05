import Link from "next/link";
import { notFound } from "next/navigation";
import { getVaultById } from "../../../../lib/vaults";

export default async function RedeemPage({ params }: { params: { id: string } }) {
  const vault = await getVaultById(params.id);
  if (!vault) {
    notFound();
  }

  const isLive = vault.uiConfig.status === "LIVE";

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Redeem</p>
        <h1>{vault.name}</h1>
        <p className="muted">Select tranche and shares to redeem.</p>
      </section>

      <section className="section reveal delay-1">
        <div className="grid grid-3">
          <form className="card" style={{ gridColumn: "span 2" }}>
            <h3>Redeem form</h3>
            <label className="muted" htmlFor="shares">
              Shares
            </label>
            <input
              id="shares"
              name="shares"
              type="number"
              placeholder="0.00"
              className="input"
            />
            <div className="section">
              <p className="muted">Tranche</p>
              <div className="card-actions">
                <label className="chip">
                  <input type="radio" name="tranche" defaultChecked /> Senior
                </label>
                <label className="chip">
                  <input type="radio" name="tranche" /> Junior
                </label>
              </div>
            </div>
            <div className="card-actions">
              <button
                className={`button ${!isLive ? "button--disabled" : ""}`}
                type="button"
                disabled={!isLive}
              >
                Preview
              </button>
              <button
                className={`button button--ghost ${!isLive ? "button--disabled" : ""}`}
                type="button"
                disabled={!isLive}
              >
                Submit redeem
              </button>
            </div>
          </form>
          <div className="card">
            <h3>Summary</h3>
            <p className="muted">Status: {vault.uiConfig.status}</p>
            <p className="muted">Route: {vault.uiConfig.routeLabel}</p>
            <p className="muted">Risk: {vault.uiConfig.risk}</p>
            <p className="muted">Note: {vault.uiConfig.banner}</p>
            <div className="card-actions">
              <Link className="button button--ghost" href={`/vaults/${vault.productId}`}>
                Back to vault
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
