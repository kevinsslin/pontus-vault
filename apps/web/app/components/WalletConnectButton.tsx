"use client";

import { DynamicWidget, useDynamicContext } from "@dynamic-labs/sdk-react-core";
import { HAS_DYNAMIC_CONFIG } from "../../lib/constants/dynamic";

function DynamicWalletButton() {
  const { primaryWallet, setShowAuthFlow } = useDynamicContext();

  if (!primaryWallet) {
    return (
      <button
        className="button button--ghost"
        type="button"
        onClick={() => setShowAuthFlow(true)}
      >
        Connect Wallet
      </button>
    );
  }

  return <DynamicWidget buttonClassName="button button--ghost" />;
}

export default function WalletConnectButton() {
  if (!HAS_DYNAMIC_CONFIG) {
    return (
      <button className="button button--ghost button--disabled" type="button" disabled>
        Connect Wallet
      </button>
    );
  }

  return <DynamicWalletButton />;
}
