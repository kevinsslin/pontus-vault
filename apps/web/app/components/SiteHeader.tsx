import Link from "next/link";
import {
  PHAROS_NETWORK_LABEL,
  PHAROS_NETWORK_LABEL_MOBILE,
} from "../../lib/constants/app";
import { getDataSource } from "../../lib/data/vaults";
import SiteHeaderAction from "./SiteHeaderAction";

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
              {PHAROS_NETWORK_LABEL}
            </span>
            <span className="site-header__network-label site-header__network-label--mobile">
              {PHAROS_NETWORK_LABEL_MOBILE}
            </span>
          </span>
        </div>

        <nav className="site-header__nav" aria-label="Main">
          <Link href="/discover">Discover</Link>
          <Link href="/portfolio">Portfolio</Link>
          <Link href="/operator">Operator</Link>
        </nav>

        <div className="site-header__actions">
          <SiteHeaderAction dataSource={dataSource} />
        </div>
      </div>
    </header>
  );
}
