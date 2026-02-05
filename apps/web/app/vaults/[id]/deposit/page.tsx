import Link from "next/link";
import { notFound } from "next/navigation";
import { getVaultById } from "../../../../lib/data/vaults";
import VaultActionUnavailable from "../../../components/VaultActionUnavailable";
import WalletConnectButton from "../../../components/WalletConnectButton";

export default async function DepositPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const vault = await getVaultById(id);
  if (!vault) {
    notFound();
  }

  const isLive = vault.uiConfig.status === "LIVE";

  return (
    <main className="page">
      <section className="reveal">
        <p className="eyebrow">Deposit</p>
        <h1>Allocate into {vault.name}</h1>
        <p className="muted">
          Select tranche and amount. Preview output before signing the final transaction.
        </p>
      </section>

      {!isLive ? (
        <VaultActionUnavailable
          vaultId={vault.vaultId}
          vaultName={vault.name}
          status={vault.uiConfig.status}
          routeLabel={vault.uiConfig.routeLabel ?? vault.route}
          actionLabel="deposit"
        />
      ) : (
      <section className="section reveal delay-1">
        <div className="form-layout">
          <form className="card" aria-label="Deposit form">
            <h3>Deposit form</h3>

            <label className="field-label" htmlFor="amount">
              Amount ({vault.assetSymbol})
            </label>
            <input id="amount" name="amount" type="number" placeholder="0.00" className="input" />

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
                Submit deposit
              </button>
            </div>
            <div className="card-actions">
              <WalletConnectButton />
            </div>
            <p className="micro">
              Wallet connection is requested only when you are ready to execute.
            </p>
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
