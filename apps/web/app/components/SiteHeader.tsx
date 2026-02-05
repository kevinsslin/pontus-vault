import Link from "next/link";
import { getDataSource } from "../../lib/data/vaults";

export default function SiteHeader() {
  const dataSource = getDataSource();
  return (
    <header className="site-header">
      <div className="site-header__brand">
        <Link href="/" className="brand">
          Pontus Vault
        </Link>
        <span className="chip">Pharos Atlantic</span>
      </div>
      <nav className="site-header__nav">
        <Link href="/discover">Discover</Link>
        <Link href="/portfolio">Portfolio</Link>
        <Link href="/operator">Operator</Link>
      </nav>
      <div className="site-header__actions">
        <span className="pill">{dataSource === "live" ? "Live data" : "Mock data"}</span>
        <button className="button button--ghost" type="button">
          Connect
        </button>
      </div>
    </header>
  );
}
