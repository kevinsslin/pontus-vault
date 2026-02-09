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

function asPositiveInteger(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.floor(parsed));
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
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
  const maxSeniorRatioBps = Math.min(
    10_000,
    asPositiveInteger(options.maxSeniorRatioBps, 8000)
  );
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
  const options = request.options ?? {};
  const supportedRoutes = asStringArray(options.supportedRoutes);
  const deploymentNote =
    typeof options.note === "string" ? options.note.trim() : "";

  return [
    {
      kind: "OFFCHAIN",
      label: "Sign deployment intent",
      description:
        "Sign deployment intent with Operator wallet to approve capability routes, role boundaries, and deployment parameters.",
      metadata: {
        vaultId: vault.vaultId,
        managerMode: options.managerMode ?? "allowlist",
        supportedRoutes,
        assetSymbol: options.assetSymbol ?? vault.assetSymbol,
        note: deploymentNote || null,
        params: options,
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Execute deployment transaction",
      description:
        "Run per-vault deployment via backend deploy executor and attach resulting transaction hash for audit.",
      metadata: {
        api: "/api/operator/deploy",
        command: "forge script script/DeployTrancheVault.s.sol --broadcast --verify",
        script: String(options.deployScript ?? "DeployTrancheVault.s.sol"),
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Register deployment outputs",
      description:
        "Record deployed addresses plus registry/factory metadata for operator replay and indexer wiring.",
      metadata: {
        requires: [
          "controller",
          "seniorToken",
          "juniorToken",
          "accountant",
          "paramsHash",
          "trancheRegistry",
          "trancheFactory",
        ],
      },
    },
  ];
}

function buildPublishSteps(
  vault: VaultRecord,
  request: OperatorCreateOperationRequest
): StepBlueprint[] {
  const options = request.options ?? {};
  const targetStatus =
    String(options.targetStatus ?? "LIVE").toUpperCase() === "COMING_SOON"
      ? "COMING_SOON"
      : "LIVE";

  return [
    {
      kind: "OFFCHAIN",
      label: "Publish vault listing",
      description:
        "Move vault status to LIVE in metadata (DRAFT/READY -> LIVE) after final operator review.",
      metadata: {
        vaultId: vault.vaultId,
        targetStatus,
        note:
          typeof options.note === "string" && options.note.trim().length > 0
            ? options.note.trim()
            : null,
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Sync discovery cache",
      description:
        "Confirm listing update is visible in /discover and indexer-derived APIs.",
      metadata: {
        endpoint: "/api/vaults",
      },
    },
  ];
}

function buildRebalanceSteps(
  vault: VaultRecord,
  request: OperatorCreateOperationRequest
): StepBlueprint[] {
  const options = request.options ?? {};
  const defaultRouteKey =
    vault.uiConfig.strategyKeys?.[0] ?? vault.uiConfig.routeLabel ?? "multi-strategy";
  const route = String(options.route ?? defaultRouteKey);
  const intent =
    String(options.intent ?? "deploy-capital") === "raise-cash"
      ? "raise-cash"
      : "deploy-capital";
  const notionalUsd = asPositiveInteger(options.notionalUsd, 0);
  const minCashBufferBps = Math.min(
    10_000,
    asPositiveInteger(options.minCashBufferBps, 0)
  );

  if (!isReadyAddress(vault.managerAddress)) {
    return [
      {
        kind: "OFFCHAIN",
        label: "Manager address unavailable",
        description:
          "Manager is not configured on this vault record yet. Complete deployment/wiring before running rebalance.",
        metadata: {
          vaultId: vault.vaultId,
          route,
          intent,
        },
      },
    ];
  }

  return [
    {
      kind: "OFFCHAIN",
      label: "Sign rebalance plan",
      description:
        "Sign manager route, limits, and calldata bundle before execution.",
      metadata: {
        manager: vault.managerAddress,
        route,
        intent,
        notionalUsd,
        minCashBufferBps,
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Execute manager rebalance",
      description:
        "Execute allowlisted manager route and record transaction hash.",
      metadata: {
        manager: vault.managerAddress,
        route,
        intent,
      },
    },
    {
      kind: "OFFCHAIN",
      label: "Validate redemption readiness",
      description:
        "Run preview checks after rebalance and verify cash buffer against redemption policy.",
      metadata: {
        minCashBufferBps,
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
      ? buildPublishSteps(vault, request)
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
