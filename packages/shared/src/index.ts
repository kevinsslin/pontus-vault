export const PHAROS_ATLANTIC = {
  chainId: 688689,
  rpcUrl: "https://atlantic.dplabs-internal.com",
  explorerUrl: "https://atlantic.pharosscan.xyz",
  blockscoutVerifierUrl:
    "https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract",
  pontusInfra: {
    trancheFactory: "0x7fBaFFA7fba0C6b141cf06B01e1ba1f6FB2350F8",
    trancheRegistry: "0x341A376b59c86A26324229cd467A5E3b930792C6"
  },
  tokens: {
    USDC: "0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8",
    USDT: "0xE7E84B8B4f39C507499c40B4ac199B050e2882d5",
    WETH: "0x7d211F77525ea39A0592794f793cC1036eEaccD5",
    WBTC: "0x0c64F03EEa5c30946D5c55B4b532D08ad74638a4",
    WPHRS: "0x838800b758277CC111B2d48Ab01e5E164f8E9471"
  },
  protocols: {
    openFi: {
      pool: "0xEC86f142E7334d99EEEF2c43298413299D919B30",
      addressesProvider: "0xeD3A193799f2cFDF086cc8b35d6AA539E6054B82",
      aTokenUsdc: "0x8ea288619d7e0497f2b90d598ee2764cb0118c90",
      aTokenUsdt: "0xd972b3da6c6bf4e8e7b61f14970663ff2151659f"
    },
    asseto: {
      usdtClaim: "0x56f4add11d723412D27A9e9433315401B351d6E3"
    },
    aquaFlux: {
      core: "0x62FdBc600E8bADf8127E6298DD12B961eDf08b5f",
      tokenFactory: "0x4006c3d13Cae97Bb9fd3338e97E4a682234683Ed",
      tokenFaucet: "0x69ea30AB859ff2a51e41a85426e4C0Ea10c2D9f5",
      nft: "0x11bD621cD17130152b167C1381e9Fa69D580169e"
    }
  }
} as const;

export * from "./vaults";
export * from "./operator";
