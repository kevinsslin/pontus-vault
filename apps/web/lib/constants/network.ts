import { PHAROS_ATLANTIC } from "@pti/shared";

export const PHAROS_CHAIN_ID = PHAROS_ATLANTIC.chainId;
export const PHAROS_CHAIN_ID_HEX = `0x${PHAROS_CHAIN_ID.toString(16)}`;
export const PHAROS_NETWORK_NAME = "Pharos Atlantic Testnet";

const PHAROS_NATIVE_CURRENCY = {
  decimals: 18,
  name: "Pharos",
  symbol: "PHRS",
};

export const PHAROS_EVM_NETWORK = {
  blockExplorerUrls: [PHAROS_ATLANTIC.explorerUrl],
  chainId: PHAROS_CHAIN_ID,
  chainName: PHAROS_NETWORK_NAME,
  iconUrls: ["/partners/pharos.png"],
  isTestnet: true,
  name: "Pharos Atlantic",
  nativeCurrency: PHAROS_NATIVE_CURRENCY,
  networkId: PHAROS_CHAIN_ID,
  rpcUrls: [PHAROS_ATLANTIC.rpcUrl],
  vanityName: "Pharos Atlantic",
};

export const PHAROS_WALLET_CONNECT_CHAIN: `eip155:${number}` = `eip155:${PHAROS_CHAIN_ID}`;

export function parseNetworkChainId(network: number | string | undefined): number | null {
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

async function addEthereumChain(
  request: (args: { method: string; params?: unknown[] }) => Promise<unknown>
): Promise<boolean> {
  try {
    await request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: PHAROS_CHAIN_ID_HEX,
          chainName: PHAROS_NETWORK_NAME,
          rpcUrls: [PHAROS_ATLANTIC.rpcUrl],
          nativeCurrency: PHAROS_NATIVE_CURRENCY,
          blockExplorerUrls: [PHAROS_ATLANTIC.explorerUrl],
        },
      ],
    });
    return true;
  } catch {
    return false;
  }
}

export async function addPharosNetworkToInjectedWallet(): Promise<boolean> {
  if (typeof window === "undefined") {
    return false;
  }

  const injected = (
    window as Window & {
      ethereum?: {
        request?: (args: { method: string; params?: unknown[] }) => Promise<unknown>;
      };
    }
  ).ethereum;

  if (!injected?.request) {
    return false;
  }

  return addEthereumChain(injected.request);
}
