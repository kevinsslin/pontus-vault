import { createClient } from "@supabase/supabase-js";
import {
  type OperatorCreateOperationRequest,
  type OperatorOperation,
  type OperatorOperationStep,
  type OperatorOperationWithSteps,
  type OperatorOperationStatus,
  OperatorOperationSchema,
  OperatorOperationStepSchema,
  type OperatorStepStatus,
  type OperatorUpdateStepRequest,
  SupabaseOperatorOperationRowSchema,
  SupabaseOperatorOperationStepRowSchema,
} from "@pti/shared";

type StepTemplate = Omit<
  OperatorOperationStep,
  | "stepId"
  | "operationId"
  | "stepIndex"
  | "status"
  | "txHash"
  | "proof"
  | "errorCode"
  | "errorMessage"
  | "createdAt"
  | "updatedAt"
>;

const memoryOperations = new Map<string, OperatorOperationWithSteps>();
const memoryIdempotency = new Map<string, string>();

function getSupabaseAdminClient() {
  const url =
    process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  if (!url || !serviceRole) return null;
  return createClient(url, serviceRole, {
    auth: { persistSession: false },
  });
}

function idempotencyLookupKey(
  requestedBy: string,
  key: string | undefined
): string | null {
  if (!key) return null;
  return `${requestedBy.toLowerCase()}:${key}`;
}

function deriveOperationStatus(steps: OperatorOperationStep[]): OperatorOperationStatus {
  if (steps.length === 0) return "CREATED";
  if (steps.every((step) => step.status === "CANCELLED")) return "CANCELLED";
  if (steps.some((step) => step.status === "FAILED")) return "FAILED";
  if (
    steps.every((step) =>
      ["SUCCEEDED", "CONFIRMED"].includes(step.status)
    )
  ) {
    return "SUCCEEDED";
  }
  if (
    steps.some((step) =>
      ["CREATED", "AWAITING_SIGNATURE", "BROADCASTED"].includes(step.status)
    )
  ) {
    return "RUNNING";
  }
  return "RUNNING";
}

function getInitialStepStatus(kind: OperatorOperationStep["kind"]): OperatorStepStatus {
  return kind === "ONCHAIN" ? "AWAITING_SIGNATURE" : "CREATED";
}

function fromDbOperationRow(
  row: ReturnType<typeof SupabaseOperatorOperationRowSchema.parse>
): OperatorOperation {
  return OperatorOperationSchema.parse({
    operationId: row.operation_id,
    vaultId: row.vault_id,
    chain: row.chain,
    jobType: row.job_type,
    requestedBy: row.requested_by,
    idempotencyKey: row.idempotency_key,
    status: row.status,
    options: row.options ?? {},
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  });
}

function fromDbStepRow(
  row: ReturnType<typeof SupabaseOperatorOperationStepRowSchema.parse>
): OperatorOperationStep {
  return OperatorOperationStepSchema.parse({
    stepId: row.step_id,
    operationId: row.operation_id,
    stepIndex: row.step_index,
    kind: row.kind,
    label: row.label,
    description: row.description,
    toAddress: row.to_address,
    calldata: row.calldata,
    valueWei: row.value_wei,
    status: row.status,
    txHash: row.tx_hash,
    proof: row.proof,
    errorCode: row.error_code,
    errorMessage: row.error_message,
    metadata: row.metadata ?? {},
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  });
}

function toDbOperationInsert(operation: OperatorOperation) {
  return {
    operation_id: operation.operationId,
    vault_id: operation.vaultId,
    chain: operation.chain,
    job_type: operation.jobType,
    requested_by: operation.requestedBy,
    idempotency_key: operation.idempotencyKey,
    status: operation.status,
    options: operation.options,
  };
}

function toDbStepInsert(step: OperatorOperationStep) {
  return {
    step_id: step.stepId,
    operation_id: step.operationId,
    step_index: step.stepIndex,
    kind: step.kind,
    label: step.label,
    description: step.description,
    to_address: step.toAddress,
    calldata: step.calldata,
    value_wei: step.valueWei,
    status: step.status,
    tx_hash: step.txHash,
    proof: step.proof,
    error_code: step.errorCode,
    error_message: step.errorMessage,
    metadata: step.metadata,
  };
}

function nextOperationWithSteps(
  request: OperatorCreateOperationRequest,
  templates: StepTemplate[]
): OperatorOperationWithSteps {
  const now = new Date().toISOString();
  const operationId = crypto.randomUUID();
  const operation = OperatorOperationSchema.parse({
    operationId,
    vaultId: request.vaultId,
    chain: request.chain,
    jobType: request.jobType,
    requestedBy: request.requestedBy,
    idempotencyKey: request.idempotencyKey ?? null,
    status: "CREATED",
    options: request.options ?? {},
    createdAt: now,
    updatedAt: now,
  });
  const steps = templates.map((step, stepIndex) =>
    OperatorOperationStepSchema.parse({
      stepId: crypto.randomUUID(),
      operationId,
      stepIndex,
      kind: step.kind,
      label: step.label,
      description: step.description ?? null,
      toAddress: step.toAddress ?? null,
      calldata: step.calldata ?? null,
      valueWei: step.valueWei ?? "0",
      status: getInitialStepStatus(step.kind),
      txHash: null,
      proof: null,
      errorCode: null,
      errorMessage: null,
      metadata: step.metadata ?? {},
      createdAt: now,
      updatedAt: now,
    })
  );

  operation.status = deriveOperationStatus(steps);

  return {
    operation,
    steps,
  };
}

function sortByStepIndex(steps: OperatorOperationStep[]): OperatorOperationStep[] {
  return [...steps].sort((a, b) => a.stepIndex - b.stepIndex);
}

export async function listOperatorOperations(vaultId?: string, limit = 50) {
  const supabase = getSupabaseAdminClient();

  if (!supabase) {
    return [...memoryOperations.values()]
      .map((item) => item.operation)
      .filter((operation) => (vaultId ? operation.vaultId === vaultId : true))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .slice(0, limit);
  }

  let query = supabase
    .from("operator_operations")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (vaultId) {
    query = query.eq("vault_id", vaultId);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(error.message);
  }

  return SupabaseOperatorOperationRowSchema.array()
    .parse(data ?? [])
    .map(fromDbOperationRow);
}

export async function getOperatorOperation(
  operationId: string
): Promise<OperatorOperationWithSteps | null> {
  const supabase = getSupabaseAdminClient();

  if (!supabase) {
    return memoryOperations.get(operationId) ?? null;
  }

  const [operationResult, stepsResult] = await Promise.all([
    supabase
      .from("operator_operations")
      .select("*")
      .eq("operation_id", operationId)
      .maybeSingle(),
    supabase
      .from("operator_operation_steps")
      .select("*")
      .eq("operation_id", operationId)
      .order("step_index", { ascending: true }),
  ]);

  if (operationResult.error) throw new Error(operationResult.error.message);
  if (stepsResult.error) throw new Error(stepsResult.error.message);
  if (!operationResult.data) return null;

  return {
    operation: fromDbOperationRow(
      SupabaseOperatorOperationRowSchema.parse(operationResult.data)
    ),
    steps: SupabaseOperatorOperationStepRowSchema.array()
      .parse(stepsResult.data ?? [])
      .map(fromDbStepRow),
  };
}

export async function createOperatorOperation(
  request: OperatorCreateOperationRequest,
  templates: StepTemplate[]
): Promise<OperatorOperationWithSteps> {
  const idempotencyKey = idempotencyLookupKey(
    request.requestedBy,
    request.idempotencyKey
  );
  const supabase = getSupabaseAdminClient();

  if (!supabase) {
    if (idempotencyKey && memoryIdempotency.has(idempotencyKey)) {
      const existingId = memoryIdempotency.get(idempotencyKey)!;
      const existing = memoryOperations.get(existingId);
      if (existing) return existing;
    }

    const payload = nextOperationWithSteps(request, templates);
    memoryOperations.set(payload.operation.operationId, payload);
    if (idempotencyKey) {
      memoryIdempotency.set(idempotencyKey, payload.operation.operationId);
    }
    return payload;
  }

  if (request.idempotencyKey) {
    const existing = await supabase
      .from("operator_operations")
      .select("operation_id")
      .eq("requested_by", request.requestedBy)
      .eq("idempotency_key", request.idempotencyKey)
      .maybeSingle();
    if (existing.error) throw new Error(existing.error.message);
    if (existing.data?.operation_id) {
      const loaded = await getOperatorOperation(existing.data.operation_id);
      if (loaded) return loaded;
    }
  }

  const payload = nextOperationWithSteps(request, templates);

  const insertOperation = await supabase
    .from("operator_operations")
    .insert(toDbOperationInsert(payload.operation));
  if (insertOperation.error) throw new Error(insertOperation.error.message);

  const insertSteps = await supabase
    .from("operator_operation_steps")
    .insert(payload.steps.map(toDbStepInsert));
  if (insertSteps.error) throw new Error(insertSteps.error.message);

  return payload;
}

export async function updateOperatorOperationStep(
  operationId: string,
  stepIndex: number,
  patch: OperatorUpdateStepRequest
): Promise<OperatorOperationWithSteps> {
  const supabase = getSupabaseAdminClient();
  const now = new Date().toISOString();

  if (!supabase) {
    const current = memoryOperations.get(operationId);
    if (!current) {
      throw new Error("Operation not found.");
    }
    const steps = current.steps.map((step) =>
      step.stepIndex === stepIndex
        ? {
            ...step,
            status: patch.status,
            txHash: patch.txHash ?? step.txHash,
            proof: patch.proof ?? step.proof,
            errorCode: patch.errorCode ?? null,
            errorMessage: patch.errorMessage ?? null,
            updatedAt: now,
          }
        : step
    );
    const operation = {
      ...current.operation,
      status: deriveOperationStatus(steps),
      updatedAt: now,
    };
    const next = { operation, steps: sortByStepIndex(steps) };
    memoryOperations.set(operationId, next);
    return next;
  }

  const update = await supabase
    .from("operator_operation_steps")
    .update({
      status: patch.status,
      tx_hash: patch.txHash ?? null,
      proof: patch.proof ?? null,
      error_code: patch.errorCode ?? null,
      error_message: patch.errorMessage ?? null,
      updated_at: now,
    })
    .eq("operation_id", operationId)
    .eq("step_index", stepIndex);
  if (update.error) throw new Error(update.error.message);

  const loaded = await getOperatorOperation(operationId);
  if (!loaded) throw new Error("Operation not found.");

  const nextStatus = deriveOperationStatus(loaded.steps);
  const opUpdate = await supabase
    .from("operator_operations")
    .update({
      status: nextStatus,
      updated_at: now,
    })
    .eq("operation_id", operationId);
  if (opUpdate.error) throw new Error(opUpdate.error.message);

  return {
    operation: {
      ...loaded.operation,
      status: nextStatus,
      updatedAt: now,
    },
    steps: sortByStepIndex(loaded.steps),
  };
}
