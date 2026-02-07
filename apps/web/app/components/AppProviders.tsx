"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { PHAROS_ATLANTIC } from "@pti/shared";
import {
  DynamicContextProvider,
  mergeNetworks,
  useDynamicContext,
  useSwitchNetwork,
} from "@dynamic-labs/sdk-react-core";
import { EthereumWalletConnectors } from "@dynamic-labs/ethereum";

type AppProvidersProps = {
  children: ReactNode;
};

const DYNAMIC_ENVIRONMENT_ID = process.env.NEXT_PUBLIC_DYNAMIC_ENVIRONMENT_ID ?? "";
const PHAROS_CHAIN_ID = PHAROS_ATLANTIC.chainId;
const PHAROS_CHAIN_ID_HEX = `0x${PHAROS_CHAIN_ID.toString(16)}`;
const PHAROS_EVM_NETWORK = {
  blockExplorerUrls: [PHAROS_ATLANTIC.explorerUrl],
  chainId: PHAROS_CHAIN_ID,
  chainName: "Pharos Atlantic Testnet",
  iconUrls: ["/partners/pharos.png"],
  isTestnet: true,
  name: "Pharos Atlantic",
  nativeCurrency: {
    decimals: 18,
    name: "Pharos",
    symbol: "PHRS",
  },
  networkId: PHAROS_CHAIN_ID,
  rpcUrls: [PHAROS_ATLANTIC.rpcUrl],
  vanityName: "Pharos Atlantic",
};

function mergePharosEvmNetwork(dashboardNetworks: Parameters<typeof mergeNetworks>[1]) {
  return mergeNetworks([PHAROS_EVM_NETWORK], dashboardNetworks);
}

function parseNetworkChainId(network: number | string | undefined): number | null {
  if (typeof network === "number" && Number.isFinite(network)) {
    return network;
  }

  if (typeof network === "string") {
    const trimmed = network.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith("0x")) {
      const parsedHex = Number.parseInt(trimmed, 16);
      return Number.isFinite(parsedHex) ? parsedHex : null;
    }
    const parsed = Number.parseInt(trimmed, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

async function addPharosNetworkToInjectedWallet(): Promise<boolean> {
  if (typeof window === "undefined") return false;

  const ethereum = (
    window as Window & {
      ethereum?: {
        request?: (args: { method: string; params?: unknown[] }) => Promise<unknown>;
      };
    }
  ).ethereum;

  if (!ethereum?.request) return false;

  try {
    await ethereum.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: PHAROS_CHAIN_ID_HEX,
          chainName: "Pharos Atlantic Testnet",
          rpcUrls: [PHAROS_ATLANTIC.rpcUrl],
          nativeCurrency: {
            name: "Pharos",
            symbol: "PHRS",
            decimals: 18,
          },
          blockExplorerUrls: [PHAROS_ATLANTIC.explorerUrl],
        },
      ],
    });
    return true;
  } catch {
    return false;
  }
}

function DynamicAutoNetworkSwitch() {
  const { primaryWallet } = useDynamicContext();
  const switchNetwork = useSwitchNetwork();
  const attemptedWalletRef = useRef<string | null>(null);

  useEffect(() => {
    if (!primaryWallet) {
      attemptedWalletRef.current = null;
      return;
    }

    let cancelled = false;
    const walletKey = `${primaryWallet.id}:${primaryWallet.address}`;

    const switchToPharos = async () => {
      const currentNetwork = parseNetworkChainId(await primaryWallet.getNetwork());
      if (cancelled) return;

      if (currentNetwork === PHAROS_CHAIN_ID) {
        attemptedWalletRef.current = null;
        return;
      }

      if (attemptedWalletRef.current === walletKey) {
        return;
      }

      attemptedWalletRef.current = walletKey;

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

        if (code !== 4902) {
          return;
        }
      }

      const added = await addPharosNetworkToInjectedWallet();
      if (!added || cancelled) return;

      try {
        await switchNetwork({
          wallet: primaryWallet,
          network: PHAROS_CHAIN_ID,
        });
      } catch {
        // Ignore; user might reject network switch in wallet UI.
      }
    };

    void switchToPharos();

    return () => {
      cancelled = true;
    };
  }, [primaryWallet, switchNetwork]);

  return null;
}

export default function AppProviders({ children }: AppProvidersProps) {
  if (!DYNAMIC_ENVIRONMENT_ID) {
    return <>{children}</>;
  }

  return (
    <DynamicContextProvider
      settings={{
        environmentId: DYNAMIC_ENVIRONMENT_ID,
        networkValidationMode: "always",
        overrides: {
          evmNetworks: mergePharosEvmNetwork,
        },
        walletConnectPreferredChains: [`eip155:${PHAROS_CHAIN_ID}`],
        walletConnectors: [EthereumWalletConnectors],
      }}
    >
      <DynamicAutoNetworkSwitch />
      {children}
    </DynamicContextProvider>
  );
}
