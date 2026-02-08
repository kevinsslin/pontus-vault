"use client";

import { useEffect, type ReactNode } from "react";
import {
  DynamicContextProvider,
  useDynamicContext,
  useSwitchNetwork,
} from "@dynamic-labs/sdk-react-core";
import { EthereumWalletConnectors } from "@dynamic-labs/ethereum";
import { DYNAMIC_ENVIRONMENT_ID, HAS_DYNAMIC_CONFIG } from "../../lib/constants/dynamic";
import {
  addPharosNetworkToInjectedWallet,
  parseNetworkChainId,
  PHAROS_CHAIN_ID,
  PHAROS_EVM_NETWORK,
} from "../../lib/constants/network";

type DynamicBoundaryProps = {
  children: ReactNode;
};

const attemptedWalletSwitches = new Set<string>();

function DynamicAutoNetworkSwitch() {
  const { primaryWallet } = useDynamicContext();
  const switchNetwork = useSwitchNetwork();

  useEffect(() => {
    if (!primaryWallet) return;

    let cancelled = false;
    const walletKey = `${primaryWallet.id}:${primaryWallet.address}`;

    const switchToPharos = async () => {
      if (attemptedWalletSwitches.has(walletKey)) return;

      const currentNetwork = parseNetworkChainId(await primaryWallet.getNetwork());
      if (cancelled || currentNetwork === PHAROS_CHAIN_ID) return;

      attemptedWalletSwitches.add(walletKey);

      try {
        await switchNetwork({
          wallet: primaryWallet,
          network: PHAROS_CHAIN_ID,
        });
        return;
      } catch (error) {
        const code =
          typeof error === "object" && error !== null && "code" in error
            ? Number((error as { code?: unknown }).code)
            : null;

        if (code !== 4902) return;
      }

      const added = await addPharosNetworkToInjectedWallet();
      if (!added || cancelled) return;

      try {
        await switchNetwork({
          wallet: primaryWallet,
          network: PHAROS_CHAIN_ID,
        });
      } catch {
        // User can reject the wallet prompt.
      }
    };

    void switchToPharos();

    return () => {
      cancelled = true;
    };
  }, [primaryWallet, switchNetwork]);

  return null;
}

export default function DynamicBoundary({ children }: DynamicBoundaryProps) {
  if (!HAS_DYNAMIC_CONFIG) {
    return <>{children}</>;
  }

  return (
    <DynamicContextProvider
      settings={{
        environmentId: DYNAMIC_ENVIRONMENT_ID,
        networkValidationMode: "always",
        walletConnectors: [EthereumWalletConnectors],
        overrides: {
          evmNetworks: () => [PHAROS_EVM_NETWORK],
        },
      }}
    >
      <DynamicAutoNetworkSwitch />
      {children}
    </DynamicContextProvider>
  );
}
