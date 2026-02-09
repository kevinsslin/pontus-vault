"use client";

import { useEffect, useState, type ComponentType } from "react";
import { HAS_DYNAMIC_CONFIG } from "../../lib/constants/dynamic";
import { PHAROS_ATLANTIC } from "@pti/shared";

function ConnectButtonShell({
  onClick,
  disabled = false,
  label = "Connect Wallet",
}: {
  onClick?: () => void;
  disabled?: boolean;
  label?: string;
}) {
  return (
    <button
      className="button button--ghost"
      type="button"
      disabled={disabled}
      onClick={onClick}
    >
      {label}
    </button>
  );
}

export default function WalletConnectButton() {
  const [WalletRuntime, setWalletRuntime] = useState<ComponentType | null>(null);
  const [loadingRuntime, setLoadingRuntime] = useState(false);

  useEffect(() => {
    if (!HAS_DYNAMIC_CONFIG) return;
    if (WalletRuntime || loadingRuntime) return;

    let cancelled = false;
    setLoadingRuntime(true);
    import("./DynamicWalletButtonRuntime")
      .then((mod) => {
        if (cancelled) return;
        const RuntimeComponent = mod.default as ComponentType;
        setWalletRuntime(() => RuntimeComponent);
      })
      .finally(() => {
        if (cancelled) return;
        setLoadingRuntime(false);
      });

    return () => {
      cancelled = true;
    };
  }, [WalletRuntime, loadingRuntime]);

  if (!HAS_DYNAMIC_CONFIG) {
    return (
      <ConnectButtonShell
        onClick={() => {
          window.alert(
            `Wallet auth is not configured yet.\n\nSet NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID and restart the app.\nPharos RPC: ${PHAROS_ATLANTIC.rpcUrl}`
          );
        }}
      />
    );
  }

  if (!WalletRuntime) {
    return (
      <ConnectButtonShell
        disabled={loadingRuntime}
        label={loadingRuntime ? "Loading..." : "Connect Wallet"}
        onClick={() => {
          // Runtime will mount automatically; this is just a noop affordance.
        }}
      />
    );
  }

  return <WalletRuntime />;
}
