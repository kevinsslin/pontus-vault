import Link from "next/link";

type VaultActionUnavailableProps = {
  vaultId: string;
  vaultName: string;
  status: string;
  routeLabel?: string;
  actionLabel: "deposit" | "redeem";
};

export default function VaultActionUnavailable({
  vaultId,
  vaultName,
  status,
  routeLabel,
  actionLabel,
}: VaultActionUnavailableProps) {
  return (
    <section className="section reveal delay-1">
      <article className="card card--spotlight">
        <h3>{actionLabel === "deposit" ? "Deposit unavailable" : "Redeem unavailable"}</h3>
        <p className="muted">
          {vaultName} is currently {status}. You can review the vault detail and route context now,
          then execute once it is live.
        </p>
        <div className="list-rows">
          <div className="row">
            <span className="key">Vault status</span>
            <span className="value">{status}</span>
          </div>
          <div className="row">
            <span className="key">Route</span>
            <span className="value">{routeLabel ?? "N/A"}</span>
          </div>
        </div>
        <div className="card-actions">
          <Link className="button" href={`/vaults/${vaultId}`}>
            Back to vault detail
          </Link>
          <Link className="button button--ghost" href="/discover">
            Browse live vaults
          </Link>
        </div>
      </article>
    </section>
  );
}
