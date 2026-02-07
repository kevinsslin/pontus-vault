"use client";

import { usePathname } from "next/navigation";
import type { DataSource } from "@pti/shared";
import WalletConnectButton from "./WalletConnectButton";

type SiteHeaderActionProps = {
  dataSource: DataSource;
};

const APP_ROUTE_PREFIXES = ["/discover", "/portfolio", "/operator", "/vaults"];

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
    return <WalletConnectButton />;
  }

  return <span className="pill">{dataSource === "live" ? "Live data" : "Demo data"}</span>;
}
