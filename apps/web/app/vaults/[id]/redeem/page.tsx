import Link from "next/link";
import { notFound } from "next/navigation";
import { getVaultById } from "../../../../lib/data/vaults";
import VaultActionUnavailable from "../../../components/VaultActionUnavailable";

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
        <h1>Redeem from {vault.name}</h1>
        <p className="muted">
          Choose tranche and share amount. Preview redeem output before executing.
        </p>
      </section>

      {!isLive ? (
        <VaultActionUnavailable
          vaultId={vault.vaultId}
          vaultName={vault.name}
          status={vault.uiConfig.status}
          routeLabel={vault.uiConfig.routeLabel ?? vault.route}
          actionLabel="redeem"
        />
      ) : (
      <section className="section reveal delay-1">
        <div className="form-layout">
          <form className="card" aria-label="Redeem form">
            <h3>Redeem form</h3>

            <label className="field-label" htmlFor="shares">
              Shares
            </label>
            <input id="shares" name="shares" type="number" placeholder="0.00" className="input" />

            <div>
              <p className="field-label">Tranche</p>
              <div className="radio-group">
                <label className="radio-chip">
                  <input type="radio" name="tranche" defaultChecked />
                  Senior
                </label>
                <label className="radio-chip">
                  <input type="radio" name="tranche" />
                  Junior
                </label>
              </div>
            </div>

            <div className="card-actions">
              <button className="button" type="button">
                Preview output
              </button>
              <button className="button button--ghost" type="button">
                Submit redeem
              </button>
            </div>
          </form>

          <aside className="card card--spotlight">
            <h3>Execution notes</h3>
            <div className="list-rows">
              <div className="row">
                <span className="key">Status</span>
                <span className="value">{vault.uiConfig.status}</span>
              </div>
              <div className="row">
                <span className="key">Route</span>
                <span className="value">{vault.uiConfig.routeLabel ?? vault.route}</span>
              </div>
              <div className="row">
                <span className="key">Risk profile</span>
                <span className="value">{vault.uiConfig.risk ?? "N/A"}</span>
              </div>
              <div className="row">
                <span className="key">Policy</span>
                <span className="value">{vault.uiConfig.banner ?? "N/A"}</span>
              </div>
            </div>
            <div className="card-actions">
              <Link className="button button--ghost" href={`/vaults/${vault.vaultId}`}>
                Back to vault
              </Link>
            </div>
          </aside>
        </div>
      </section>
      )}
    </main>
  );
}
