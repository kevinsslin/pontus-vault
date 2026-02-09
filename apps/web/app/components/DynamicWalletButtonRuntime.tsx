"use client";

import { DynamicWidget, useDynamicContext } from "@dynamic-labs/sdk-react-core";

export default function DynamicWalletButtonRuntime() {
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

