import { z } from "zod";

export const VaultStatusSchema = z.enum(["LIVE", "COMING_SOON"]);
export type VaultStatus = z.infer<typeof VaultStatusSchema>;

export const DataSourceSchema = z.enum(["demo", "live"]);
export type DataSource = z.infer<typeof DataSourceSchema>;

export const VaultUiConfigSchema = z.object({
  status: VaultStatusSchema,
  displayOrder: z.number().int().optional(),
  risk: z.string().optional(),
  strategyKeys: z.array(z.string().max(80)).max(16).optional(),
  routeLabel: z.string().optional(),
  summary: z.string().optional(),
  tags: z.array(z.string()).optional(),
  banner: z.string().optional(),
  owner: z.string().optional(),
  paramsHash: z.string().optional(),
  deployTxHash: z.string().optional(),
  accountantAddress: z.string().optional(),
  trancheRegistry: z.string().optional(),
  trancheFactory: z.string().optional(),
  indexerStartBlock: z.number().int().nonnegative().optional(),
});
export type VaultUiConfig = z.infer<typeof VaultUiConfigSchema>;

export const VaultMetricsSchema = z.object({
  tvl: z.string().nullable(),
  seniorApyBps: z.string().nullable().optional(),
  juniorApyBps: z.string().nullable().optional(),
  seniorPrice: z.string().nullable(),
  juniorPrice: z.string().nullable(),
  seniorDebt: z.string().nullable(),
  seniorSupply: z.string().nullable(),
  juniorSupply: z.string().nullable(),
  updatedAt: z.string().nullable(),
});
export type VaultMetrics = z.infer<typeof VaultMetricsSchema>;

export const IndexerVaultSchema = z.object({
  id: z.string(),
  controller: z.string().nullable().optional(),
  vaultId: z.string().nullable().optional(),
  paramsHash: z.string().nullable().optional(),
  asset: z.string().nullable().optional(),
  teller: z.string().nullable().optional(),
  manager: z.string().nullable().optional(),
  rateModel: z.string().nullable().optional(),
  paused: z.boolean().optional(),
  maxSeniorRatioBps: z.string().nullable().optional(),
  maxRateAge: z.string().nullable().optional(),
  seniorRatePerSecondWad: z.string().nullable().optional(),
  tvl: z.string().nullable().optional(),
  seniorApyBps: z.string().nullable().optional(),
  juniorApyBps: z.string().nullable().optional(),
  seniorPrice: z.string().nullable().optional(),
  juniorPrice: z.string().nullable().optional(),
  seniorDebt: z.string().nullable().optional(),
  seniorSupply: z.string().nullable().optional(),
  juniorSupply: z.string().nullable().optional(),
  updatedAt: z.string().nullable().optional(),
  dailySnapshots: z
    .array(
      z.object({
        periodStart: z.string().nullable().optional(),
        closeTvl: z.string().nullable().optional(),
        closeSeniorPrice: z.string().nullable().optional(),
        closeJuniorPrice: z.string().nullable().optional(),
        txCount: z.number().int().optional(),
      })
    )
    .optional(),
});
export type IndexerVault = z.infer<typeof IndexerVaultSchema>;

export const IndexerVaultsResponseSchema = z.object({
  data: z
    .object({
      vaults: z.array(IndexerVaultSchema).optional(),
    })
    .optional(),
  errors: z.array(z.object({ message: z.string() })).optional(),
});
export type IndexerVaultsResponse = z.infer<typeof IndexerVaultsResponseSchema>;

export const SupabaseVaultRegistryRowSchema = z.object({
  vault_id: z.string(),
  chain: z.string(),
  name: z.string(),
  // Legacy single-route marker kept for compatibility with existing rows.
  // Newer clients should use ui_config.strategyKeys for multi-strategy vaults.
  route: z.string().optional(),
  asset_symbol: z.string(),
  asset_address: z.string(),
  controller_address: z.string(),
  senior_token_address: z.string(),
  junior_token_address: z.string(),
  vault_address: z.string(),
  teller_address: z.string(),
  manager_address: z.string(),
  ui_config: z.record(z.string(), z.unknown()).nullable(),
});
export type SupabaseVaultRegistryRow = z.infer<typeof SupabaseVaultRegistryRowSchema>;

export const VaultRecordSchema = z.object({
  vaultId: z.string(),
  chain: z.string(),
  name: z.string(),
  assetSymbol: z.string(),
  assetAddress: z.string(),
  controllerAddress: z.string(),
  seniorTokenAddress: z.string(),
  juniorTokenAddress: z.string(),
  vaultAddress: z.string(),
  tellerAddress: z.string(),
  managerAddress: z.string(),
  uiConfig: VaultUiConfigSchema,
  metrics: VaultMetricsSchema,
});
export type VaultRecord = z.infer<typeof VaultRecordSchema>;

export const ActivityEventSchema = z.object({
  id: z.string(),
  type: z.enum(["DEPOSIT", "REDEEM", "ACCRUE"]),
  tranche: z.enum(["SENIOR", "JUNIOR", "SYSTEM"]),
  amount: z.string(),
  time: z.string(),
  actor: z.string(),
});
export type ActivityEvent = z.infer<typeof ActivityEventSchema>;

export const PortfolioSnapshotSchema = z.object({
  totalValue: z.string(),
  dayChange: z.string(),
  positions: z.array(
    z.object({
      vaultId: z.string(),
      name: z.string(),
      tranche: z.enum(["SENIOR", "JUNIOR"]),
      shares: z.string(),
      value: z.string(),
      pnl: z.string(),
    })
  ),
});
export type PortfolioSnapshot = z.infer<typeof PortfolioSnapshotSchema>;

export const VaultsApiResponseSchema = z.object({
  generatedAt: z.string().optional(),
  source: z
    .object({
      supabase: z.string().optional(),
      indexer: z.string().nullable().optional(),
    })
    .optional(),
  errors: z.array(z.string()).optional(),
  vaults: z.array(VaultRecordSchema),
});
export type VaultsApiResponse = z.infer<typeof VaultsApiResponseSchema>;

export const OperatorEditableVaultUiConfigSchema = z.object({
  status: VaultStatusSchema.optional(),
  displayOrder: z.number().int().min(0).max(10_000).optional(),
  risk: z.string().max(80).optional(),
  routeLabel: z.string().max(80).optional(),
  summary: z.string().max(320).optional(),
  tags: z.array(z.string().max(40)).max(16).optional(),
  banner: z.string().max(320).optional(),
});
export type OperatorEditableVaultUiConfig = z.infer<
  typeof OperatorEditableVaultUiConfigSchema
>;

export const OperatorUpdateVaultRequestSchema = z.object({
  requestedBy: z.string().min(1).max(120),
  name: z.string().max(140).optional(),
  uiConfig: OperatorEditableVaultUiConfigSchema.optional(),
});
export type OperatorUpdateVaultRequest = z.infer<
  typeof OperatorUpdateVaultRequestSchema
>;

export const OperatorUpdateVaultResponseSchema = z.object({
  vault: VaultRecordSchema,
});
export type OperatorUpdateVaultResponse = z.infer<
  typeof OperatorUpdateVaultResponseSchema
>;

const VaultUiConfigPartialSchema = VaultUiConfigSchema.partial().extend({
  status: VaultStatusSchema.optional(),
});

export function normalizeVaultUiConfig(input: unknown): VaultUiConfig {
  const parsed = VaultUiConfigPartialSchema.safeParse(input);
  if (!parsed.success) {
    return { status: "COMING_SOON" };
  }
  return {
    status: parsed.data.status ?? "COMING_SOON",
    ...parsed.data,
  };
}
