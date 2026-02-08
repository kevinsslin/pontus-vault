import { z } from "zod";

export const OperatorJobTypeSchema = z.enum([
  "DEPLOY_VAULT",
  "CONFIGURE_VAULT",
  "PUBLISH_VAULT",
  "REBALANCE_VAULT",
]);
export type OperatorJobType = z.infer<typeof OperatorJobTypeSchema>;

export const OperatorStepKindSchema = z.enum(["ONCHAIN", "OFFCHAIN"]);
export type OperatorStepKind = z.infer<typeof OperatorStepKindSchema>;

export const OperatorOperationStatusSchema = z.enum([
  "CREATED",
  "RUNNING",
  "SUCCEEDED",
  "FAILED",
  "CANCELLED",
]);
export type OperatorOperationStatus = z.infer<typeof OperatorOperationStatusSchema>;

export const OperatorStepStatusSchema = z.enum([
  "CREATED",
  "AWAITING_SIGNATURE",
  "BROADCASTED",
  "CONFIRMED",
  "SUCCEEDED",
  "FAILED",
  "CANCELLED",
]);
export type OperatorStepStatus = z.infer<typeof OperatorStepStatusSchema>;

export const OperatorOperationSchema = z.object({
  operationId: z.string(),
  vaultId: z.string(),
  chain: z.string(),
  jobType: OperatorJobTypeSchema,
  requestedBy: z.string(),
  idempotencyKey: z.string().nullable(),
  status: OperatorOperationStatusSchema,
  options: z.record(z.string(), z.unknown()),
  createdAt: z.string(),
  updatedAt: z.string(),
});
export type OperatorOperation = z.infer<typeof OperatorOperationSchema>;

export const OperatorOperationStepSchema = z.object({
  stepId: z.string(),
  operationId: z.string(),
  stepIndex: z.number().int().nonnegative(),
  kind: OperatorStepKindSchema,
  label: z.string(),
  description: z.string().nullable(),
  toAddress: z.string().nullable(),
  calldata: z.string().nullable(),
  valueWei: z.string().nullable(),
  status: OperatorStepStatusSchema,
  txHash: z.string().nullable(),
  proof: z.string().nullable(),
  errorCode: z.string().nullable(),
  errorMessage: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  createdAt: z.string(),
  updatedAt: z.string(),
});
export type OperatorOperationStep = z.infer<typeof OperatorOperationStepSchema>;

export const OperatorOperationWithStepsSchema = z.object({
  operation: OperatorOperationSchema,
  steps: z.array(OperatorOperationStepSchema),
});
export type OperatorOperationWithSteps = z.infer<typeof OperatorOperationWithStepsSchema>;

export const OperatorCreateOperationRequestSchema = z.object({
  vaultId: z.string(),
  chain: z.string().default("pharos-atlantic"),
  jobType: OperatorJobTypeSchema,
  requestedBy: z.string(),
  idempotencyKey: z.string().optional(),
  options: z.record(z.string(), z.unknown()).optional(),
});
export type OperatorCreateOperationRequest = z.infer<
  typeof OperatorCreateOperationRequestSchema
>;

export const OperatorCreateOperationResponseSchema =
  OperatorOperationWithStepsSchema;
export type OperatorCreateOperationResponse = z.infer<
  typeof OperatorCreateOperationResponseSchema
>;

export const OperatorUpdateStepRequestSchema = z.object({
  status: OperatorStepStatusSchema,
  txHash: z.string().optional(),
  proof: z.string().optional(),
  errorCode: z.string().optional(),
  errorMessage: z.string().optional(),
});
export type OperatorUpdateStepRequest = z.infer<
  typeof OperatorUpdateStepRequestSchema
>;

export const OperatorListOperationsResponseSchema = z.object({
  operations: z.array(OperatorOperationSchema),
});
export type OperatorListOperationsResponse = z.infer<
  typeof OperatorListOperationsResponseSchema
>;

const AddressSchema = z.string().regex(/^0x[a-fA-F0-9]{40}$/, "Invalid address");
const Hash32Schema = z.string().regex(/^0x[a-fA-F0-9]{64}$/, "Invalid bytes32 hash");

export const OperatorDeployVaultRequestSchema = z.object({
  requestedBy: AddressSchema,
  owner: AddressSchema.optional(),
  vaultId: z.string().min(1).max(120),
  chain: z.string().default("pharos-atlantic"),
  name: z.string().min(1).max(140),
  route: z.string().min(1).max(120),
  assetSymbol: z.string().min(1).max(40),
  assetAddress: AddressSchema,
  uiConfig: z.record(z.string(), z.unknown()).optional(),
});
export type OperatorDeployVaultRequest = z.infer<
  typeof OperatorDeployVaultRequestSchema
>;

export const OperatorDeployVaultResponseSchema = z.object({
  vaultId: z.string(),
  paramsHash: Hash32Schema,
  txHash: z.string().regex(/^0x[a-fA-F0-9]{64}$/).nullable(),
  chain: z.string(),
  addresses: z.object({
    trancheRegistry: AddressSchema,
    trancheController: AddressSchema,
    seniorToken: AddressSchema,
    juniorToken: AddressSchema,
    boringVault: AddressSchema,
    teller: AddressSchema,
    manager: AddressSchema,
    accountant: AddressSchema,
  }),
  command: z.string(),
});
export type OperatorDeployVaultResponse = z.infer<
  typeof OperatorDeployVaultResponseSchema
>;

export const OperatorUpdateExchangeRateRequestSchema = z.object({
  requestedBy: AddressSchema,
  vaultAddress: AddressSchema,
  accountantAddress: AddressSchema,
  assetAddress: AddressSchema,
  minUpdateBps: z.number().int().nonnegative().max(10_000).optional(),
  allowPauseUpdate: z.boolean().optional(),
});
export type OperatorUpdateExchangeRateRequest = z.infer<
  typeof OperatorUpdateExchangeRateRequestSchema
>;

export const OperatorUpdateExchangeRateResponseSchema = z.object({
  vaultAddress: AddressSchema,
  accountantAddress: AddressSchema,
  assetAddress: AddressSchema,
  command: z.string(),
  txHash: z.string().regex(/^0x[a-fA-F0-9]{64}$/).nullable(),
  skipped: z.boolean(),
  skipReason: z.string().nullable(),
  currentRate: z.string().nullable(),
  nextRate: z.string().nullable(),
});
export type OperatorUpdateExchangeRateResponse = z.infer<
  typeof OperatorUpdateExchangeRateResponseSchema
>;

export const OperatorInfraResponseSchema = z.object({
  chainId: z.number().int().positive(),
  trancheFactory: z.string().nullable(),
  trancheRegistry: z.string().nullable(),
});
export type OperatorInfraResponse = z.infer<typeof OperatorInfraResponseSchema>;

export const SupabaseOperatorOperationRowSchema = z.object({
  operation_id: z.string(),
  vault_id: z.string(),
  chain: z.string(),
  job_type: OperatorJobTypeSchema,
  requested_by: z.string(),
  idempotency_key: z.string().nullable(),
  status: OperatorOperationStatusSchema,
  options: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type SupabaseOperatorOperationRow = z.infer<
  typeof SupabaseOperatorOperationRowSchema
>;

export const SupabaseOperatorOperationStepRowSchema = z.object({
  step_id: z.string(),
  operation_id: z.string(),
  step_index: z.number().int().nonnegative(),
  kind: OperatorStepKindSchema,
  label: z.string(),
  description: z.string().nullable(),
  to_address: z.string().nullable(),
  calldata: z.string().nullable(),
  value_wei: z.string().nullable(),
  status: OperatorStepStatusSchema,
  tx_hash: z.string().nullable(),
  proof: z.string().nullable(),
  error_code: z.string().nullable(),
  error_message: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type SupabaseOperatorOperationStepRow = z.infer<
  typeof SupabaseOperatorOperationStepRowSchema
>;
