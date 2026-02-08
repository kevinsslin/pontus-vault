"use client";

import { usePathname } from "next/navigation";
import type { DataSource } from "@pti/shared";
import { APP_ROUTE_PREFIXES, DATA_SOURCE_LABEL } from "../../lib/constants/navigation";
import WalletConnectButton from "./WalletConnectButton";

type SiteHeaderActionProps = {
  dataSource: DataSource;
};

function isAppRoute(pathname: string | null): boolean {
  if (!pathname) return false;
  return APP_ROUTE_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`)
  );
}

export default function SiteHeaderAction({ dataSource }: SiteHeaderActionProps) {
  const pathname = usePathname();
  const showWalletConnect = isAppRoute(pathname);

  if (showWalletConnect) {
    return (
      <>
        <span className="pill">{DATA_SOURCE_LABEL[dataSource]}</span>
        <WalletConnectButton />
      </>
    );
  }

  return <span className="pill">{DATA_SOURCE_LABEL[dataSource]}</span>;
}
