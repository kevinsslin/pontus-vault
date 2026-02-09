"use client";

import dynamic from "next/dynamic";
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

const DynamicWalletButtonRuntime = dynamic(
  () => import("./DynamicWalletButtonRuntime"),
  {
    ssr: false,
    loading: () => <ConnectButtonShell disabled label="Loading..." />,
  }
);

export default function WalletConnectButton() {
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

  return <DynamicWalletButtonRuntime />;
}

