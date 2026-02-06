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
