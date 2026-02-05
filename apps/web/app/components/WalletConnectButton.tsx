"use client";

import { DynamicWidget } from "@dynamic-labs/sdk-react-core";

const DYNAMIC_ENVIRONMENT_ID = process.env.NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID ?? "";

export default function WalletConnectButton() {
  if (!DYNAMIC_ENVIRONMENT_ID) {
    return (
      <button className="button button--ghost button--disabled" type="button" disabled>
        Configure Dynamic
      </button>
    );
  }

  return <DynamicWidget buttonClassName="button button--ghost" />;
}
