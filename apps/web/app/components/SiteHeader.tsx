import Link from "next/link";
import { getDataSource } from "../../lib/data/vaults";

export default function SiteHeader() {
  const dataSource = getDataSource();

  return (
    <header className="site-header">
      <div className="site-header__inner">
        <div className="site-header__brand">
          <Link href="/" className="brand" aria-label="Pontus Vault home">
            <span className="brand-mark">P</span>
            <span>
              Pontus <span className="muted">Vault</span>
            </span>
          </Link>
          <span className="chip chip--soft site-header__network">
            <span className="live-dot" />
            <span className="site-header__network-label site-header__network-label--desktop">
              Pharos Atlantic
            </span>
            <span className="site-header__network-label site-header__network-label--mobile">
              Atlantic
            </span>
          </span>
        </div>

        <nav className="site-header__nav" aria-label="Main">
          <Link href="/discover">Discover</Link>
          <Link href="/portfolio">Portfolio</Link>
          <Link href="/operator">Operator</Link>
        </nav>

        <div className="site-header__actions">
          <span className="pill">{dataSource === "live" ? "Live data" : "Demo data"}</span>
        </div>
      </div>
    </header>
  );
}
