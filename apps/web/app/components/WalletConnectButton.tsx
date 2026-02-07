"use client";

import dynamic from "next/dynamic";
import { useDynamicContext } from "@dynamic-labs/sdk-react-core";

const DYNAMIC_ENVIRONMENT_ID = process.env.NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID ?? "";

const DynamicWidget = dynamic(
  () =>
    import("@dynamic-labs/sdk-react-core").then((module) => ({
      default: module.DynamicWidget,
    })),
  { ssr: false }
);

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
  if (!DYNAMIC_ENVIRONMENT_ID) {
    return (
      <button className="button button--ghost button--disabled" type="button" disabled>
        Connect Wallet
      </button>
    );
  }

  return <DynamicWalletButton />;
}
