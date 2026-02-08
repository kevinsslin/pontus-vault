"use client";

import { useState, type ComponentType } from "react";
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

  const handleConnectClick = async () => {
    if (!HAS_DYNAMIC_CONFIG) {
      window.alert(
        `Wallet auth is not configured yet.\n\nSet NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID and restart the app.\nPharos RPC: ${PHAROS_ATLANTIC.rpcUrl}`
      );
      return;
    }

    if (WalletRuntime || loadingRuntime) return;

    setLoadingRuntime(true);
    try {
      const mod = await import("./DynamicWalletButtonRuntime");
      const RuntimeComponent = mod.default as ComponentType;
      setWalletRuntime(() => RuntimeComponent);
    } finally {
      setLoadingRuntime(false);
    }
  };

  if (!WalletRuntime) {
    return (
      <ConnectButtonShell
        onClick={() => {
          void handleConnectClick();
        }}
        disabled={loadingRuntime}
        label={loadingRuntime ? "Connecting..." : "Connect Wallet"}
      />
    );
  }

  if (!HAS_DYNAMIC_CONFIG) {
    return (
      <ConnectButtonShell
        onClick={() => {
          void handleConnectClick();
        }}
      />
    );
  }

  return <WalletRuntime />;
}
