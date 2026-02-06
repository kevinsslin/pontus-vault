import type {
  OperatorCreateOperationRequest,
  OperatorOperationStep,
  OperatorStepKind,
  OperatorStepStatus,
  VaultRecord,
} from "@pti/shared";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

type StepBlueprint = {
  kind: OperatorStepKind;
  label: string;
  description: string;
  toAddress?: string | null;
  calldata?: string | null;
  valueWei?: string | null;
  metadata?: Record<string, unknown>;
};

function isReadyAddress(value: string | null | undefined): value is string {
  return !!value && value !== ZERO_ADDRESS;
}

function toHexPaddedWord(input: bigint): string {
  return input.toString(16).padStart(64, "0");
}

function encodeUintSelector(selector: string, value: bigint): string {
  return `${selector}${toHexPaddedWord(value)}`;
}

function encodeAddressSelector(selector: string, address: string): string {
  const normalized = address.toLowerCase().replace(/^0x/, "");
  return `${selector}${normalized.padStart(64, "0")}`;
}

function buildConfigureSteps(
  vault: VaultRecord,
  request: OperatorCreateOperationRequest
): StepBlueprint[] {
  const controller = vault.controllerAddress;
  const options = request.options ?? {};
  const maxSeniorRatioBps = Number(options.maxSeniorRatioBps ?? 8000);
  const seniorRatePerSecondWad = BigInt(
    String(options.seniorRatePerSecondWad ?? "0")
  );
  const rateModel = String(options.rateModel ?? "");

  if (!isReadyAddress(controller)) {
    return [
      {
        kind: "OFFCHAIN",
        label: "Controller address unavailable",
        description:
          "Controller is not configured on this vault record yet. Update metadata or deploy the vault before submitting onchain config calls.",
        metadata: { vaultId: vault.vaultId },
      },
    ];
  }

  const steps: StepBlueprint[] = [
    {
      kind: "ONCHAIN",
      label: "Set senior ratio cap",
      description: "Call TrancheController.setMaxSeniorRatioBps(uint256).",
      toAddress: controller,
      calldata: encodeUintSelector(
        "0x3caaccfe",
        BigInt(Math.max(0, maxSeniorRatioBps))
      ),
      valueWei: "0",
      metadata: { method: "setMaxSeniorRatioBps", maxSeniorRatioBps },
    },
    {
      kind: "ONCHAIN",
      label: "Set senior rate",
      description: "Call TrancheController.setSeniorRatePerSecondWad(uint256).",
      toAddress: controller,
      calldata: encodeUintSelector("0x875eb422", seniorRatePerSecondWad),
      valueWei: "0",
      metadata: {
        method: "setSeniorRatePerSecondWad",
        seniorRatePerSecondWad: seniorRatePerSecondWad.toString(),
      },
    },
  ];

  if (isReadyAddress(rateModel)) {
    steps.push({
      kind: "ONCHAIN",
      label: "Set rate model",
      description: "Call TrancheController.setRateModel(address).",
      toAddress: controller,
      calldata: encodeAddressSelector("0x7f9028c8", rateModel),
      valueWei: "0",
      metadata: { method: "setRateModel", rateModel },
    });
  }

  return steps;
}

function buildDeploySteps(
  vault: VaultRecord,
  request: OperatorCreateOperationRequest
): StepBlueprint[] {
  return [
    {
      kind: "OFFCHAIN",
      label: "Sign deployment intent",
      description:
        "Sign deployment intent with Operator wallet to approve the deployment plan and parameters.",
      metadata: {
        vaultId: vault.vaultId,
        params: request.options ?? {},
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Execute deployment transaction",
      description:
        "Run per-vault deployment via script/backend executor and attach resulting transaction hash for audit.",
      metadata: {
        command: "forge script script/DeployTrancheVault.s.sol --broadcast",
      },
    },
  ];
}

function buildPublishSteps(vault: VaultRecord): StepBlueprint[] {
  return [
    {
      kind: "OFFCHAIN",
      label: "Publish vault listing",
      description:
        "Move vault status to LIVE in metadata (DRAFT/READY -> LIVE) after final operator review.",
      metadata: {
        vaultId: vault.vaultId,
        targetStatus: "LIVE",
      },
    },
  ];
}

function buildRebalanceSteps(
  vault: VaultRecord,
  request: OperatorCreateOperationRequest
): StepBlueprint[] {
  return [
    {
      kind: "OFFCHAIN",
      label: "Sign rebalance plan",
      description:
        "Sign manager route, limits, and calldata bundle before execution.",
      metadata: {
        manager: vault.managerAddress,
        route: request.options?.route ?? vault.route,
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Execute manager rebalance",
      description:
        "Execute allowlisted manager route and record transaction hash.",
      metadata: {
        manager: vault.managerAddress,
      },
    },
  ];
}

export function buildOperationSteps(
  vault: VaultRecord,
  request: OperatorCreateOperationRequest
): Omit<
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
>[] {
  const blueprints =
    request.jobType === "DEPLOY_VAULT"
      ? buildDeploySteps(vault, request)
      : request.jobType === "CONFIGURE_VAULT"
      ? buildConfigureSteps(vault, request)
      : request.jobType === "PUBLISH_VAULT"
      ? buildPublishSteps(vault)
      : buildRebalanceSteps(vault, request);

  return blueprints.map((step) => ({
    kind: step.kind,
    label: step.label,
    description: step.description,
    toAddress: step.toAddress ?? null,
    calldata: step.calldata ?? null,
    valueWei: step.valueWei ?? "0",
    metadata: step.metadata ?? {},
  }));
}

export function getInitialStepStatus(kind: OperatorStepKind): OperatorStepStatus {
  return kind === "ONCHAIN" ? "AWAITING_SIGNATURE" : "CREATED";
}
