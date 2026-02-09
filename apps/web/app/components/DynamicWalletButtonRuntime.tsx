"use client";

import { DynamicWidget, useDynamicContext } from "@dynamic-labs/sdk-react-core";
import DynamicBoundary from "./DynamicBoundary";

function DynamicWalletButtonInner() {
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

export default function DynamicWalletButtonRuntime() {
  return (
    <DynamicBoundary>
      <DynamicWalletButtonInner />
    </DynamicBoundary>
  );
}

