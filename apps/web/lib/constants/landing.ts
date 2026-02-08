export type LandingPartner = {
  name: string;
  logo: string;
  href: string;
  width: number;
  height: number;
};

export const LANDING_PARTNERS: LandingPartner[] = [
  { name: "Pharos", logo: "/partners/pharos.png", href: "https://pharosnetwork.xyz", width: 190, height: 48 },
  { name: "Plume", logo: "/partners/plume-wordmark.png", href: "https://plumenetwork.xyz", width: 188, height: 64 },
  { name: "Ondo", logo: "/partners/ondo.svg", href: "https://ondo.finance", width: 184, height: 60 },
  { name: "Superstate", logo: "/partners/superstate-wordmark.png", href: "https://superstate.co", width: 220, height: 40 },
  { name: "Centrifuge", logo: "/partners/centrifuge.svg", href: "https://centrifuge.io", width: 95, height: 31 },
  { name: "Sky", logo: "/partners/sky.svg", href: "https://sky.money", width: 84, height: 35 },
  { name: "BlockTower", logo: "/partners/blocktower.svg", href: "https://blocktower.com", width: 194, height: 62 },
  { name: "Parafi", logo: "/partners/parafi.svg", href: "https://parafi.com", width: 194, height: 62 },
  { name: "Janus Henderson", logo: "/partners/janus-henderson.svg", href: "https://www.janushenderson.com", width: 194, height: 62 },
];

export const LANDING_WORKFLOW_STEPS = [
  {
    step: "01",
    title: "Open App",
    body: "Connect your wallet and load your allocator profile.",
  },
  {
    step: "02",
    title: "Vault Discovery",
    body: "Compare live vaults by APY, tranche mix, and route quality.",
  },
  {
    step: "03",
    title: "Tranche Execution",
    body: "Select senior or junior lane and execute deposit or redeem.",
  },
  {
    step: "04",
    title: "Portfolio Intelligence",
    body: "Monitor yield, APY spread, and allocation shifts in one view.",
  },
] as const;

export const LANDING_INVESTOR_LANES = [
  {
    title: "Senior Focus",
    subtitle: "Capital stability",
    body: "Target lower volatility with tighter downside exposure.",
    cta: "View senior-priority vaults",
    href: "/discover?focus=senior",
    seniorShare: 82,
    juniorShare: 18,
    signal: "Expected APY: 6% to 9%",
  },
  {
    title: "Balanced Split",
    subtitle: "Income optimization",
    body: "Blend senior carry with junior upside in one allocation policy.",
    cta: "Compare blended profiles",
    href: "/discover?focus=balanced",
    seniorShare: 64,
    juniorShare: 36,
    signal: "Expected APY: 8% to 13%",
  },
  {
    title: "Junior Focus",
    subtitle: "Return acceleration",
    body: "Take higher beta against structured downside boundaries.",
    cta: "Explore high-upside lanes",
    href: "/discover?focus=junior",
    seniorShare: 35,
    juniorShare: 65,
    signal: "Expected APY: 11% to 19%",
  },
] as const;

export const LANDING_STACK_LAYERS = [
  {
    layer: "Layer 03",
    title: "Risk Tranching Layer",
    body: "Package risk into senior and junior slices so each allocator chooses a defined payoff profile.",
    tags: ["Senior sleeve", "Junior sleeve", "Risk budgeted"],
  },
  {
    layer: "Layer 02",
    title: "Vault Orchestration Layer",
    body: "Aggregate routes, policy controls, and accounting into one coherent vault product surface.",
    tags: ["Policy engine", "Unified yield", "Execution controls"],
  },
  {
    layer: "Layer 01",
    title: "Yield Sources Layer",
    body: "Connect productive base assets across DeFi and RWA channels where real yield is generated.",
    tags: ["Lending markets", "Treasury/RWA", "Credit routes"],
  },
] as const;
