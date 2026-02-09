import Link from "next/link";
import Image from "next/image";
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
          <Link href="/" className="brand brand--logo" aria-label="Pontus Vault home">
            <Image
              src="/logo-nav.png"
              alt="Pontus Vault"
              width={140}
              height={32}
              priority
              className="brand-logo"
            />
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
