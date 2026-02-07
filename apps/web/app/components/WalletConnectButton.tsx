"use client";

import dynamic from "next/dynamic";

const DYNAMIC_ENVIRONMENT_ID = process.env.NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID ?? "";

const DynamicWidget = dynamic(
  () =>
    import("@dynamic-labs/sdk-react-core").then((module) => ({
      default: module.DynamicWidget,
    })),
  { ssr: false }
);

export default function WalletConnectButton() {
  if (!DYNAMIC_ENVIRONMENT_ID) {
    return (
      <button className="button button--ghost button--disabled" type="button" disabled>
        Connect wallet
      </button>
    );
  }

  return <DynamicWidget buttonClassName="button button--ghost" />;
}
