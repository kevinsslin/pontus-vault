import Link from "next/link";

export default function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer__inner">
        <div className="site-footer__meta">
          <p className="brand">
            <span className="brand-mark">P</span>
            Pontus <span className="muted">Vault</span>
          </p>
          <p className="muted">
            Tranche infrastructure for professional allocators on Pharos. Discover,
            allocate, and monitor structured yield vaults through one interface.
          </p>
        </div>
        <div className="site-footer__links">
          <Link href="/discover">Discover</Link>
          <Link href="/portfolio">Portfolio</Link>
          <Link href="/operator">Operator</Link>
        </div>
      </div>
    </footer>
  );
}
