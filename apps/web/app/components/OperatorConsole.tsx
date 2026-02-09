"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import type {
  OperatorCreateOperationRequest,
  OperatorInfraResponse,
  OperatorJobType,
  OperatorOperation,
  OperatorOperationStep,
  OperatorOperationWithSteps,
  OperatorStepStatus,
  OperatorUpdateExchangeRateResponse,
  VaultRecord,
  VaultStatus,
} from "@pti/shared";
import { useDynamicContext } from "@dynamic-labs/sdk-react-core";

type OperatorConsoleProps = {
  vaults: VaultRecord[];
};

type OperatorModule =
  | "overview"
  | "vault_profile"
  | "vault_factory"
  | "accountant"
  | "risk_caps"
  | "listing"
  | "rebalance"
  | "history";

type ListingTarget = "LIVE" | "COMING_SOON";
type RebalanceIntent = "deploy-capital" | "raise-cash";

const EXECUTION_MODE =
  process.env.NEXT_PUBLIC_OPERATOR_TX_MODE === "send_transaction"
    ? "send_transaction"
    : "sign_only";

const DEFAULT_ASSET_ADDRESSES: Record<string, string> = {
  USDC: "0xE0BE08c77f415F577A1B3A9aD7a1Df1479564ec8",
  USDT: "0xE7E84B8B4f39C507499c40B4ac199B050e2882d5",
};

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const MODULES: Array<{ id: OperatorModule; label: string; helper: string }> = [
  {
    id: "overview",
    label: "Overview",
    helper: "Role boundaries, liquidity model, and execution readiness.",
  },
  {
    id: "vault_profile",
    label: "Vault Profile",
    helper: "Edit discovery metadata such as vault name, summary, labels, and status.",
  },
  {
    id: "vault_factory",
    label: "Vault Factory",
    helper: "Define supported strategy routes and prepare vault deployment intent.",
  },
  {
    id: "accountant",
    label: "Accountant",
    helper: "Trigger exchange-rate sync and keep deposit/redeem pricing fresh.",
  },
  {
    id: "risk_caps",
    label: "Risk & Caps",
    helper: "Set max senior ratio and senior carry model on controller.",
  },
  {
    id: "listing",
    label: "Listing",
    helper: "Publish vault metadata to discovery once checks are complete.",
  },
  {
    id: "rebalance",
    label: "Rebalance",
    helper: "Route capital between strategies and raise cash for redemptions when needed.",
  },
  {
    id: "history",
    label: "Job History",
    helper: "Review operation logs, trace payloads, and replay failed steps.",
  },
];

const MODULE_TO_JOB: Record<
  Exclude<OperatorModule, "overview" | "vault_profile" | "accountant" | "history">,
  OperatorJobType
> =
  {
    vault_factory: "DEPLOY_VAULT",
    risk_caps: "CONFIGURE_VAULT",
    listing: "PUBLISH_VAULT",
    rebalance: "REBALANCE_VAULT",
  };

const ROUTE_CAPABILITIES: Array<{ key: string; label: string; helper: string }> = [
  {
    key: "openfi-supply",
    label: "OpenFi supply",
    helper: "Allow manager route for conservative lending carry.",
  },
  {
    key: "openfi-withdraw",
    label: "OpenFi withdraw",
    helper: "Allow manager route to pull cash for redemptions.",
  },
  {
    key: "asseto-redeem",
    label: "Asseto redeem",
    helper: "Enable redemption route for tokenized RWA positions.",
  },
  {
    key: "erc4626",
    label: "ERC4626 route",
    helper: "Enable generic ERC4626 deposit/withdraw strategy path.",
  },
];

const REBALANCE_ROUTES: Array<{ value: string; label: string }> = [
  { value: "openfi-supply-withdraw", label: "OpenFi supply/withdraw" },
  { value: "asseto-claim-redeem", label: "Asseto claim/redeem" },
  { value: "erc4626-roll", label: "ERC4626 roll-forward" },
];

function shortHash(value: string) {
  if (value.length <= 16) return value;
  return `${value.slice(0, 8)}...${value.slice(-6)}`;
}

function parseValueWeiToHex(valueWei: string | null): `0x${string}` {
  const normalized = valueWei && valueWei.trim().length > 0 ? valueWei : "0";
  return `0x${BigInt(normalized).toString(16)}`;
}

function isStepTerminal(status: OperatorStepStatus) {
  return ["SUCCEEDED", "FAILED", "CANCELLED", "CONFIRMED"].includes(status);
}

function operationStatusLabel(status: OperatorOperation["status"]) {
  if (status === "SUCCEEDED") return "done";
  if (status === "FAILED") return "failed";
  if (status === "CANCELLED") return "cancelled";
  if (status === "RUNNING") return "running";
  return "created";
}

function summarizeProgress(steps: OperatorOperationStep[]) {
  const total = steps.length;
  if (total === 0) return { done: 0, total: 0, percent: 0 };
  const done = steps.filter((step) => isStepTerminal(step.status)).length;
  return { done, total, percent: Math.round((done / total) * 100) };
}

function useOptionalPrimaryWallet() {
  try {
    return useDynamicContext().primaryWallet ?? null;
  } catch {
    return null;
  }
}

function isAddressLike(value: string) {
  return /^0x[a-fA-F0-9]{40}$/.test(value);
}

function isReadyAddress(value: string | undefined | null) {
  if (!value) return false;
  if (!isAddressLike(value)) return false;
  return value.toLowerCase() !== ZERO_ADDRESS;
}

function resolveTxHashFromSteps(steps: OperatorOperationStep[] | undefined): string | null {
  if (!steps || steps.length === 0) return null;
  const stepWithTx = steps.find((step) => Boolean(step.txHash));
  return stepWithTx?.txHash ?? null;
}

function summarizeStepsForTable(steps: OperatorOperationStep[] | undefined): string {
  if (!steps || steps.length === 0) return "—";
  const parts = steps
    .slice(0, 4)
    .map((step) => `${step.stepIndex + 1}:${step.status}`);
  const suffix = steps.length > 4 ? ` +${steps.length - 4}` : "";
  return `${parts.join(" ")}${suffix}`;
}

export default function OperatorConsole({ vaults }: OperatorConsoleProps) {
  const primaryWallet = useOptionalPrimaryWallet();
  const walletAddress = primaryWallet?.address ?? "";

  const [vaultRecords, setVaultRecords] = useState<VaultRecord[]>(vaults);
  const defaultVaultId =
    vaults.find((vault) => vault.uiConfig.status === "LIVE")?.vaultId ??
    vaults[0]?.vaultId ??
    "";
  const [selectedVaultId, setSelectedVaultId] = useState<string>(defaultVaultId);
  const [activeModule, setActiveModule] = useState<OperatorModule>("overview");

  const [maxSeniorRatioBps, setMaxSeniorRatioBps] = useState("8000");
  const [seniorRatePerSecondWad, setSeniorRatePerSecondWad] = useState("0");
  const [rateModel, setRateModel] = useState("");
  const [listingTarget, setListingTarget] = useState<ListingTarget>("LIVE");
  const [listingNote, setListingNote] = useState("");
  const [rebalanceRoute, setRebalanceRoute] = useState("openfi-supply-withdraw");
  const [rebalanceIntent, setRebalanceIntent] = useState<RebalanceIntent>("deploy-capital");
  const [rebalanceNotionalUsd, setRebalanceNotionalUsd] = useState("250000");
  const [minCashBufferBps, setMinCashBufferBps] = useState("500");
  const [deploymentNote, setDeploymentNote] = useState("");
  const [deploymentOwner, setDeploymentOwner] = useState("");
  const [deploySeniorTokenName, setDeploySeniorTokenName] = useState("Pontus Vault Senior");
  const [deploySeniorTokenSymbol, setDeploySeniorTokenSymbol] = useState("ptS");
  const [deployJuniorTokenName, setDeployJuniorTokenName] = useState("Pontus Vault Junior");
  const [deployJuniorTokenSymbol, setDeployJuniorTokenSymbol] = useState("ptJ");
  const [deployBoringVaultName, setDeployBoringVaultName] = useState("Pontus Vault Base");
  const [deployBoringVaultSymbol, setDeployBoringVaultSymbol] = useState("PTVB");
  const [deployBoringVaultDecimals, setDeployBoringVaultDecimals] = useState("18");
  const [rateUpdateAccountant, setRateUpdateAccountant] = useState("");
  const [rateUpdateMinBps, setRateUpdateMinBps] = useState("1");
  const [rateUpdateAllowPause, setRateUpdateAllowPause] = useState(false);
  const [profileName, setProfileName] = useState("");
  const [profileRoute, setProfileRoute] = useState("");
  const [profileStatus, setProfileStatus] = useState<VaultStatus>("COMING_SOON");
  const [profileSummary, setProfileSummary] = useState("");
  const [profileRisk, setProfileRisk] = useState("");
  const [profileRouteLabel, setProfileRouteLabel] = useState("");
  const [profileBanner, setProfileBanner] = useState("");
  const [profileDisplayOrder, setProfileDisplayOrder] = useState("");
  const [profileTags, setProfileTags] = useState("");
  const [routeCapabilities, setRouteCapabilities] = useState<Record<string, boolean>>({
    "openfi-supply": true,
    "openfi-withdraw": true,
    "asseto-redeem": false,
    erc4626: false,
  });

  const [operations, setOperations] = useState<OperatorOperation[]>([]);
  const [activeOperation, setActiveOperation] = useState<OperatorOperationWithSteps | null>(null);
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<string | null>(null);
  const [infraInfo, setInfraInfo] = useState<OperatorInfraResponse | null>(null);
  const [historyStepsByOperationId, setHistoryStepsByOperationId] = useState<
    Record<string, OperatorOperationStep[]>
  >({});
  const [showDraftVaultForm, setShowDraftVaultForm] = useState(false);
  const [draftVaultName, setDraftVaultName] = useState("");
  const [draftVaultRoute, setDraftVaultRoute] = useState("");
  const [draftVaultStatus, setDraftVaultStatus] = useState<VaultStatus>("COMING_SOON");
  const [draftVaultAssetSymbol, setDraftVaultAssetSymbol] = useState("USDC");
  const [draftVaultAssetAddress, setDraftVaultAssetAddress] = useState(
    DEFAULT_ASSET_ADDRESSES.USDC
  );

  const selectedVault = useMemo(
    () => vaultRecords.find((vault) => vault.vaultId === selectedVaultId) ?? null,
    [vaultRecords, selectedVaultId]
  );

  const moduleMeta = useMemo(
    () => MODULES.find((module) => module.id === activeModule) ?? MODULES[0],
    [activeModule]
  );

  const activeJobType = useMemo(() => {
    if (
      activeModule === "overview" ||
      activeModule === "vault_profile" ||
      activeModule === "accountant" ||
      activeModule === "history"
    ) {
      return null;
    }
    return MODULE_TO_JOB[activeModule];
  }, [activeModule]);

  const selectedCapabilityKeys = useMemo(
    () =>
      ROUTE_CAPABILITIES.filter((capability) => routeCapabilities[capability.key]).map(
        (capability) => capability.key
      ),
    [routeCapabilities]
  );

  useEffect(() => {
    setVaultRecords(vaults);
  }, [vaults]);

  const loadOperations = useCallback(
    async (vaultId = selectedVaultId) => {
      if (!vaultId) return;
      const response = await fetch(
        `/api/operator/operations?vaultId=${vaultId}&detail=1`,
        {
          cache: "no-store",
        }
      );
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Failed to load operator operations.");
      }
      setOperations(payload.operations ?? []);
      setHistoryStepsByOperationId(payload.stepsByOperationId ?? {});
    },
    [selectedVaultId]
  );

  const loadOperation = useCallback(async (operationId: string) => {
    const response = await fetch(`/api/operator/operations/${operationId}`, {
      cache: "no-store",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error ?? "Failed to load operation details.");
    }
    setActiveOperation(payload);
  }, []);

  useEffect(() => {
    if (!selectedVaultId) return;
    void loadOperations(selectedVaultId).catch((error) => {
      setErrorMessage(error instanceof Error ? error.message : "Load failed.");
    });
  }, [loadOperations, selectedVaultId]);

  useEffect(() => {
    if (!selectedVault) return;
    setProfileName(selectedVault.name);
    setProfileRoute(selectedVault.route);
    setProfileStatus(selectedVault.uiConfig.status);
    setProfileSummary(selectedVault.uiConfig.summary ?? "");
    setProfileRisk(selectedVault.uiConfig.risk ?? "");
    setProfileRouteLabel(selectedVault.uiConfig.routeLabel ?? "");
    setProfileBanner(selectedVault.uiConfig.banner ?? "");
    setProfileDisplayOrder(
      selectedVault.uiConfig.displayOrder !== undefined
        ? String(selectedVault.uiConfig.displayOrder)
        : ""
    );
    setProfileTags((selectedVault.uiConfig.tags ?? []).join(", "));
    setRateUpdateAccountant(selectedVault.uiConfig.accountantAddress ?? "");
  }, [selectedVault]);

  useEffect(() => {
    let cancelled = false;
    async function loadInfra() {
      try {
        const response = await fetch("/api/operator/infra", { cache: "no-store" });
        const payload = await response.json();
        if (!response.ok) {
          throw new Error(payload.error ?? "Failed to load infra settings.");
        }
        if (!cancelled) {
          setInfraInfo(payload as OperatorInfraResponse);
        }
      } catch {
        if (!cancelled) {
          setInfraInfo(null);
        }
      }
    }
    void loadInfra();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    setDeploymentOwner(walletAddress || "");
  }, [walletAddress, selectedVaultId]);

  useEffect(() => {
    const key = draftVaultAssetSymbol.trim().toUpperCase();
    const preset = DEFAULT_ASSET_ADDRESSES[key];
    if (preset) {
      setDraftVaultAssetAddress(preset);
    }
  }, [draftVaultAssetSymbol]);

  useEffect(() => {
    if (!activeOperation) return;
    const exists = operations.some(
      (operation) => operation.operationId === activeOperation.operation.operationId
    );
    if (!exists) {
      setActiveOperation(null);
    }
  }, [activeOperation, operations]);

  function buildRequestPayload(): OperatorCreateOperationRequest {
    if (!activeJobType) {
      throw new Error("Select a module that creates an operation.");
    }
    if (!selectedVault) {
      throw new Error("Select a vault first.");
    }

    const options: Record<string, unknown> = {};

    if (activeModule === "vault_factory") {
      options.supportedRoutes = selectedCapabilityKeys;
      options.managerMode = "allowlist";
      options.assetSymbol = selectedVault.assetSymbol;
      options.deployScript = "DeployTrancheVault.s.sol";
      const deployOwner = deploymentOwner.trim();
      if (deployOwner.length > 0) {
        if (!isAddressLike(deployOwner)) {
          throw new Error("Owner address is invalid.");
        }
        options.owner = deployOwner;
      }
      const boringVaultDecimals = Number(deployBoringVaultDecimals.trim() || "18");
      if (
        !Number.isFinite(boringVaultDecimals) ||
        boringVaultDecimals < 0 ||
        boringVaultDecimals > 255
      ) {
        throw new Error("BoringVault decimals must be an integer between 0 and 255.");
      }
      options.deployConfig = {
        seniorTokenName: deploySeniorTokenName.trim(),
        seniorTokenSymbol: deploySeniorTokenSymbol.trim(),
        juniorTokenName: deployJuniorTokenName.trim(),
        juniorTokenSymbol: deployJuniorTokenSymbol.trim(),
        boringVaultName: deployBoringVaultName.trim(),
        boringVaultSymbol: deployBoringVaultSymbol.trim(),
        boringVaultDecimals: Math.floor(boringVaultDecimals),
      };
      if (deploymentNote.trim()) options.note = deploymentNote.trim();
    } else if (activeModule === "risk_caps") {
      options.maxSeniorRatioBps = Number(maxSeniorRatioBps || "8000");
      options.seniorRatePerSecondWad = seniorRatePerSecondWad || "0";
      if (rateModel.trim()) {
        if (!isAddressLike(rateModel.trim())) {
          throw new Error("Rate model address is invalid.");
        }
        options.rateModel = rateModel.trim();
      }
    } else if (activeModule === "listing") {
      options.targetStatus = listingTarget;
      if (listingNote.trim()) options.note = listingNote.trim();
    } else if (activeModule === "rebalance") {
      options.route = rebalanceRoute;
      options.intent = rebalanceIntent;
      options.notionalUsd = Number(rebalanceNotionalUsd || "0");
      options.minCashBufferBps = Number(minCashBufferBps || "0");
    }

    return {
      vaultId: selectedVault.vaultId,
      chain: selectedVault.chain,
      jobType: activeJobType,
      requestedBy: walletAddress || "unconnected-operator",
      idempotencyKey: crypto.randomUUID(),
      options,
    };
  }

  async function createOperation() {
    if (!activeJobType) return;

    setBusyAction("create");
    setErrorMessage(null);
    setInfoMessage(null);
    try {
      const requestPayload = buildRequestPayload();
      const response = await fetch("/api/operator/operations", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(requestPayload),
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Failed to create operation.");
      }
      setActiveOperation(payload);
      setActiveModule("history");
      await loadOperations(selectedVaultId);
      setInfoMessage("Operation prepared. Execute steps in order and capture wallet proof.");
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Create operation failed.");
    } finally {
      setBusyAction(null);
    }
  }

  async function saveVaultProfile() {
    if (!selectedVault) return;

    if (!walletAddress) {
      setErrorMessage("Connect an operator wallet before saving vault profile.");
      return;
    }

    const actionKey = `save-profile:${selectedVault.vaultId}`;
    setBusyAction(actionKey);
    setErrorMessage(null);
    setInfoMessage(null);

    try {
      const displayOrder = profileDisplayOrder.trim().length
        ? Number(profileDisplayOrder)
        : undefined;
      if (displayOrder !== undefined && (!Number.isFinite(displayOrder) || displayOrder < 0)) {
        throw new Error("Display order must be a non-negative integer.");
      }

      const tags = profileTags
        .split(",")
        .map((tag) => tag.trim())
        .filter((tag) => tag.length > 0);

      const response = await fetch(`/api/operator/vaults/${selectedVault.vaultId}`, {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          requestedBy: walletAddress,
          name: profileName,
          route: profileRoute,
          uiConfig: {
            status: profileStatus,
            summary: profileSummary,
            risk: profileRisk,
            routeLabel: profileRouteLabel,
            banner: profileBanner,
            displayOrder: displayOrder !== undefined ? Math.floor(displayOrder) : undefined,
            tags,
          },
        }),
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Failed to update vault profile.");
      }

      const updatedVault = payload.vault as VaultRecord;
      setVaultRecords((previous) =>
        previous.map((vault) =>
          vault.vaultId === updatedVault.vaultId ? updatedVault : vault
        )
      );
      setInfoMessage("Vault profile updated. Discovery and detail pages now use the new metadata.");
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Vault profile save failed.");
    } finally {
      setBusyAction(null);
    }
  }

  async function runAccountantUpdateRate() {
    if (!selectedVault) {
      setErrorMessage("Select a vault first.");
      return;
    }
    if (!walletAddress) {
      setErrorMessage("Connect an operator wallet first.");
      return;
    }

    const accountantAddress = rateUpdateAccountant.trim();
    if (!isAddressLike(accountantAddress)) {
      setErrorMessage("Accountant address is invalid.");
      return;
    }
    if (!isAddressLike(selectedVault.vaultAddress)) {
      setErrorMessage("Vault address is invalid.");
      return;
    }
    if (!isAddressLike(selectedVault.assetAddress)) {
      setErrorMessage("Asset address is invalid.");
      return;
    }

    const minUpdateBps = Number(rateUpdateMinBps.trim() || "1");
    if (!Number.isFinite(minUpdateBps) || minUpdateBps < 0 || minUpdateBps > 10_000) {
      setErrorMessage("Min update bps must be between 0 and 10000.");
      return;
    }

    setBusyAction("accountant:update-rate");
    setErrorMessage(null);
    setInfoMessage(null);
    try {
      const response = await fetch("/api/operator/accountant/update-rate", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          requestedBy: walletAddress,
          vaultAddress: selectedVault.vaultAddress,
          accountantAddress,
          assetAddress: selectedVault.assetAddress,
          minUpdateBps: Math.floor(minUpdateBps),
          allowPauseUpdate: rateUpdateAllowPause,
        }),
      });

      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Failed to update exchange rate.");
      }

      const result = payload as OperatorUpdateExchangeRateResponse;
      if (result.skipped) {
        setInfoMessage(
          `Exchange-rate update skipped: ${result.skipReason ?? "threshold or supply guard"}.`
        );
      } else if (result.txHash) {
        setInfoMessage(`Exchange-rate updated onchain: ${shortHash(result.txHash)}.`);
      } else {
        setInfoMessage("Exchange-rate update executed.");
      }
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Update exchange rate failed.");
    } finally {
      setBusyAction(null);
    }
  }

  async function createDraftVault() {
    if (!walletAddress) {
      setErrorMessage("Connect an operator wallet first.");
      return;
    }

    const name = draftVaultName.trim();
    const route = draftVaultRoute.trim();
    const assetSymbol = draftVaultAssetSymbol.trim();
    const assetAddress = draftVaultAssetAddress.trim();

    if (!name) {
      setErrorMessage("Vault name is required.");
      return;
    }
    if (!route) {
      setErrorMessage("Route key is required.");
      return;
    }
    if (!assetSymbol) {
      setErrorMessage("Asset symbol is required.");
      return;
    }
    if (!isAddressLike(assetAddress)) {
      setErrorMessage("Asset address is invalid.");
      return;
    }

    setBusyAction("draft:create");
    setErrorMessage(null);
    setInfoMessage(null);

    try {
      const response = await fetch("/api/operator/vaults", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          requestedBy: walletAddress,
          chain: selectedVault?.chain ?? "pharos-atlantic",
          name,
          route,
          assetSymbol,
          assetAddress,
          status: draftVaultStatus,
        }),
      });
      const payload = await response.json();
      if (!response.ok) {
        throw new Error(payload.error ?? "Failed to create vault.");
      }

      const vaultRecord = payload.vault as VaultRecord | undefined;
      if (!vaultRecord) {
        throw new Error("Create vault response is missing vault record.");
      }

      setVaultRecords((previous) => [...previous, vaultRecord]);
      setSelectedVaultId(vaultRecord.vaultId);
      setActiveModule("vault_profile");
      setShowDraftVaultForm(false);
      setDraftVaultName("");
      setDraftVaultRoute("");
      setDraftVaultStatus("COMING_SOON");
      setDraftVaultAssetSymbol("USDC");
      setDraftVaultAssetAddress(DEFAULT_ASSET_ADDRESSES.USDC);
      setInfoMessage("Draft vault created. Update metadata and deploy via Vault Factory.");
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "Create vault failed.");
    } finally {
      setBusyAction(null);
    }
  }

  async function signMessage(message: string): Promise<string> {
    if (!primaryWallet) {
      throw new Error("Connect an operator wallet first.");
    }

    const connector = primaryWallet.connector as {
      getSigner?: () => Promise<{
        signMessage?: (value: string | { message: string }) => Promise<string>;
      }>;
    };

    if (connector?.getSigner) {
      const signer = await connector.getSigner();
      if (signer?.signMessage) {
        try {
          return await signer.signMessage(message);
        } catch {
          return await signer.signMessage({ message });
        }
      }
    }

    if (typeof window !== "undefined") {
      const ethereum = (
        window as Window & {
          ethereum?: {
            request?: (args: { method: string; params?: unknown[] }) => Promise<string>;
          };
        }
      ).ethereum;
      if (ethereum?.request) {
        return ethereum.request({
          method: "personal_sign",
          params: [message, primaryWallet.address],
        });
      }
    }

    throw new Error("Wallet signer is unavailable.");
  }

  async function sendOnchainStep(step: OperatorOperationStep): Promise<string> {
    if (!primaryWallet) {
      throw new Error("Connect an operator wallet first.");
    }
    if (!step.toAddress || !step.calldata) {
      throw new Error("Step is missing to/data payload.");
    }

    const connector = primaryWallet.connector as {
      getWalletClient?: () => {
        sendTransaction?: (params: {
          account?: string;
          to: string;
          data?: `0x${string}`;
          value?: bigint;
        }) => Promise<string>;
      };
      getSigner?: () => Promise<{
        sendTransaction?: (params: {
          to: string;
          data?: string;
          value?: bigint;
        }) => Promise<{ hash?: string } | string>;
      }>;
    };

    const value = BigInt(step.valueWei ?? "0");
    const txData = step.calldata as `0x${string}`;

    const walletClient = connector?.getWalletClient?.();
    if (walletClient?.sendTransaction) {
      const txHash = await walletClient.sendTransaction({
        account: primaryWallet.address,
        to: step.toAddress,
        data: txData,
        value,
      });
      if (txHash) return txHash;
    }

    if (connector?.getSigner) {
      const signer = await connector.getSigner();
      if (signer?.sendTransaction) {
        const tx = await signer.sendTransaction({
          to: step.toAddress,
          data: txData,
          value,
        });
        if (typeof tx === "string") return tx;
        if (tx?.hash) return tx.hash;
      }
    }

    if (typeof window !== "undefined") {
      const ethereum = (
        window as Window & {
          ethereum?: {
            request?: (args: { method: string; params?: unknown[] }) => Promise<string>;
          };
        }
      ).ethereum;
      if (ethereum?.request) {
        return ethereum.request({
          method: "eth_sendTransaction",
          params: [
            {
              from: primaryWallet.address,
              to: step.toAddress,
              data: step.calldata,
              value: parseValueWeiToHex(step.valueWei),
            },
          ],
        });
      }
    }

    throw new Error("Wallet transaction transport is unavailable.");
  }

  async function patchStep(
    operationId: string,
    stepIndex: number,
    patch: {
      status: OperatorStepStatus;
      txHash?: string;
      proof?: string;
      errorCode?: string;
      errorMessage?: string;
    }
  ) {
    if (!walletAddress) {
      throw new Error("Connect an operator wallet first.");
    }
    const response = await fetch(
      `/api/operator/operations/${operationId}/steps/${stepIndex}`,
      {
        method: "PATCH",
        headers: {
          "content-type": "application/json",
          "x-operator-address": walletAddress,
        },
        body: JSON.stringify(patch),
      }
    );
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error ?? "Failed to update step.");
    }
    setActiveOperation(payload);
    await loadOperations(selectedVaultId);
  }

  async function executeStep(step: OperatorOperationStep) {
    if (!activeOperation) return;
    const actionKey = `${activeOperation.operation.operationId}:${step.stepIndex}`;
    setBusyAction(actionKey);
    setErrorMessage(null);
    setInfoMessage(null);
    try {
      const isServerDeployStep =
        activeOperation.operation.jobType === "DEPLOY_VAULT" &&
        step.kind === "OFFCHAIN" &&
        step.label === "Execute deployment transaction";

      if (isServerDeployStep) {
        if (!walletAddress) {
          throw new Error("Connect an operator wallet first.");
        }
        if (["BROADCASTED", "RUNNING"].includes(step.status)) {
          setInfoMessage("Deployment is already queued.");
          return;
        }

        const priorStep = activeOperation.steps.find(
          (candidate) => candidate.stepIndex === step.stepIndex - 1
        );
        if (priorStep && !["SUCCEEDED", "CONFIRMED"].includes(priorStep.status)) {
          throw new Error("Sign deployment intent before queueing execution.");
        }

        await patchStep(activeOperation.operation.operationId, step.stepIndex, {
          status: "BROADCASTED",
        });
        setInfoMessage("Deployment queued. Keeper will execute and sync results.");
        return;
      }

      if (step.kind === "ONCHAIN" && EXECUTION_MODE === "send_transaction") {
        const txHash = await sendOnchainStep(step);
        await patchStep(activeOperation.operation.operationId, step.stepIndex, {
          status: "CONFIRMED",
          txHash,
        });
        setInfoMessage(`Step confirmed onchain: ${shortHash(txHash)}`);
        return;
      }

      const signature = await signMessage(
        [
          "Pontus Operator Step",
          `Operation: ${activeOperation.operation.operationId}`,
          `Step: ${step.stepIndex}`,
          `Label: ${step.label}`,
          `Vault: ${activeOperation.operation.vaultId}`,
          `Timestamp: ${new Date().toISOString()}`,
        ].join("\n")
      );

      await patchStep(activeOperation.operation.operationId, step.stepIndex, {
        status: "SUCCEEDED",
        proof: signature,
      });
      setInfoMessage(`Step signed and recorded: ${shortHash(signature)}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Step execution failed.";
      setErrorMessage(message);
      try {
        await patchStep(activeOperation.operation.operationId, step.stepIndex, {
          status: "FAILED",
          errorCode: "EXECUTION_ERROR",
          errorMessage: message,
        });
      } catch {
        // keep original error in UI
      }
    } finally {
      setBusyAction(null);
    }
  }

  const liveCount = vaultRecords.filter((vault) => vault.uiConfig.status === "LIVE").length;
  const hasCashSupport =
    routeCapabilities["openfi-withdraw"] ||
    routeCapabilities["asseto-redeem"] ||
    routeCapabilities["erc4626"];
  const selectedOperationProgress = activeOperation ? summarizeProgress(activeOperation.steps) : null;
  const prepareActionLabel =
    activeJobType === "DEPLOY_VAULT" ? "Prepare deployment" : "Prepare operation";
  const infraReady = Boolean(infraInfo?.trancheFactory && infraInfo?.trancheRegistry);
  const hasDeployedAddresses = Boolean(selectedVault && isReadyAddress(selectedVault.vaultAddress));

  return (
    <>
      <section className="reveal">
        <p className="eyebrow">Operator</p>
        <h1>Manager admin console.</h1>
        <p className="muted">
          Operator sets vault policy and listing. Manager executes strategy routes.
          Every action is captured as resumable steps with wallet proof.
        </p>
        <div className="card-actions">
          <span className="chip">Live vaults: {liveCount}</span>
          <span className="chip">Total vaults: {vaultRecords.length}</span>
          <span className="chip">Mode: {EXECUTION_MODE === "send_transaction" ? "Send tx" : "Sign only"}</span>
          <span className="chip">Wallet: {walletAddress ? shortHash(walletAddress) : "Not connected"}</span>
        </div>
      </section>

      <section className="section section--tight reveal delay-1">
        <div className="operator-shell">
          <div className="card operator-panel">
            <h3>Module selection</h3>
            <div className="segment">
              {MODULES.map((module) => (
                <button
                  key={module.id}
                  type="button"
                  className={`segment-button ${activeModule === module.id ? "segment-button--active" : ""}`}
                  onClick={() => setActiveModule(module.id)}
                >
                  {module.label}
                </button>
              ))}
            </div>
            <p className="muted">{moduleMeta.helper}</p>

            <label className="field">
              <span>Vault</span>
              <select
                value={selectedVaultId}
                onChange={(event) => setSelectedVaultId(event.target.value)}
              >
                {vaultRecords.length === 0 ? (
                  <option value="">No vaults yet</option>
                ) : (
                  vaultRecords.map((vault) => (
                    <option key={vault.vaultId} value={vault.vaultId}>
                      {vault.name}
                    </option>
                  ))
                )}
              </select>
            </label>

            <div className="card-actions">
              <button
                className="button button--ghost"
                type="button"
                onClick={() => setShowDraftVaultForm((prev) => !prev)}
                disabled={busyAction !== null}
              >
                {showDraftVaultForm ? "Cancel draft" : "New vault draft"}
              </button>
              <span className="chip">Create a new vault entry before deploying</span>
            </div>

            {showDraftVaultForm ? (
              <>
                <div className="operator-grid">
                  <label className="field operator-grid__full">
                    <span>Vault name</span>
                    <input
                      value={draftVaultName}
                      onChange={(event) => setDraftVaultName(event.target.value)}
                      placeholder="Pontus Vault USDT Cash+ S1"
                    />
                  </label>
                  <label className="field operator-grid__full">
                    <span>Route key</span>
                    <input
                      value={draftVaultRoute}
                      onChange={(event) => setDraftVaultRoute(event.target.value)}
                      placeholder="asseto-cash-plus"
                    />
                  </label>
                  <label className="field">
                    <span>Initial status</span>
                    <select
                      value={draftVaultStatus}
                      onChange={(event) => setDraftVaultStatus(event.target.value as VaultStatus)}
                    >
                      <option value="LIVE">LIVE</option>
                      <option value="COMING_SOON">COMING_SOON</option>
                    </select>
                  </label>
                  <label className="field">
                    <span>Asset symbol</span>
                    <input
                      value={draftVaultAssetSymbol}
                      onChange={(event) => setDraftVaultAssetSymbol(event.target.value)}
                      placeholder="USDT"
                    />
                  </label>
                  <label className="field operator-grid__full">
                    <span>Asset address</span>
                    <input
                      value={draftVaultAssetAddress}
                      onChange={(event) => setDraftVaultAssetAddress(event.target.value)}
                      placeholder="0x..."
                    />
                  </label>
                </div>
                <div className="card-actions">
                  <button
                    className="button"
                    type="button"
                    onClick={() => void createDraftVault()}
                    disabled={busyAction !== null}
                  >
                    {busyAction === "draft:create" ? "Creating..." : "Create draft"}
                  </button>
                  <span className="chip">Writes to Supabase in live mode</span>
                </div>
              </>
            ) : null}

            {activeModule === "vault_profile" ? (
              <div className="operator-grid">
                <label className="field operator-grid__full">
                  <span>Vault name</span>
                  <input
                    value={profileName}
                    onChange={(event) => setProfileName(event.target.value)}
                    placeholder="Pontus Vault USDC Lending Sr"
                  />
                </label>
                <label className="field operator-grid__full">
                  <span>Description</span>
                  <textarea
                    value={profileSummary}
                    onChange={(event) => setProfileSummary(event.target.value)}
                    rows={4}
                    placeholder="Short vault summary shown in discovery and detail views."
                  />
                </label>
                <label className="field">
                  <span>Status</span>
                  <select
                    value={profileStatus}
                    onChange={(event) => setProfileStatus(event.target.value as VaultStatus)}
                  >
                    <option value="LIVE">LIVE</option>
                    <option value="COMING_SOON">COMING_SOON</option>
                  </select>
                </label>
                <label className="field">
                  <span>Display order</span>
                  <input
                    value={profileDisplayOrder}
                    onChange={(event) => setProfileDisplayOrder(event.target.value)}
                    inputMode="numeric"
                    placeholder="0"
                  />
                </label>
                <label className="field">
                  <span>Route key</span>
                  <input
                    value={profileRoute}
                    onChange={(event) => setProfileRoute(event.target.value)}
                    placeholder="openfi-lending"
                  />
                </label>
                <label className="field">
                  <span>Route label</span>
                  <input
                    value={profileRouteLabel}
                    onChange={(event) => setProfileRouteLabel(event.target.value)}
                    placeholder="OpenFi lending"
                  />
                </label>
                <label className="field">
                  <span>Risk label</span>
                  <input
                    value={profileRisk}
                    onChange={(event) => setProfileRisk(event.target.value)}
                    placeholder="LOW"
                  />
                </label>
                <label className="field">
                  <span>Policy banner</span>
                  <input
                    value={profileBanner}
                    onChange={(event) => setProfileBanner(event.target.value)}
                    placeholder="Senior cap 8% APR - Junior absorbs tail risk"
                  />
                </label>
                <label className="field operator-grid__full">
                  <span>Tags (comma separated)</span>
                  <input
                    value={profileTags}
                    onChange={(event) => setProfileTags(event.target.value)}
                    placeholder="OPENFI LENDING, RISK: LOW, USDC"
                  />
                </label>
              </div>
            ) : null}

            {activeModule === "vault_factory" ? (
              <>
                <div className="operator-capabilities">
                  {ROUTE_CAPABILITIES.map((capability) => (
                    <label className="operator-capability" key={capability.key}>
                      <input
                        type="checkbox"
                        checked={Boolean(routeCapabilities[capability.key])}
                        onChange={(event) =>
                          setRouteCapabilities((prev) => ({
                            ...prev,
                            [capability.key]: event.target.checked,
                          }))
                        }
                      />
                      <div>
                        <strong>{capability.label}</strong>
                        <p className="muted">{capability.helper}</p>
                      </div>
                    </label>
                  ))}
                </div>
                <label className="field">
                  <span>Deployment note (optional)</span>
                  <input
                    value={deploymentNote}
                    onChange={(event) => setDeploymentNote(event.target.value)}
                    placeholder="e.g. Demo day vault for OpenFi USDC route"
                  />
                </label>
                <label className="field">
                  <span>Owner address (optional)</span>
                  <input
                    value={deploymentOwner}
                    onChange={(event) => setDeploymentOwner(event.target.value)}
                    placeholder={walletAddress || "0x..."}
                  />
                </label>
                <div className="operator-grid">
                  <label className="field operator-grid__full">
                    <span>Onchain token config</span>
                    <p className="muted">
                      These values are baked into the deployed ERC20 tokens and the BoringVault
                      share token.
                    </p>
                  </label>
                  <label className="field">
                    <span>Senior token name</span>
                    <input
                      value={deploySeniorTokenName}
                      onChange={(event) => setDeploySeniorTokenName(event.target.value)}
                      placeholder="Pontus Vault Senior"
                    />
                  </label>
                  <label className="field">
                    <span>Senior token symbol</span>
                    <input
                      value={deploySeniorTokenSymbol}
                      onChange={(event) => setDeploySeniorTokenSymbol(event.target.value)}
                      placeholder="ptS"
                    />
                  </label>
                  <label className="field">
                    <span>Junior token name</span>
                    <input
                      value={deployJuniorTokenName}
                      onChange={(event) => setDeployJuniorTokenName(event.target.value)}
                      placeholder="Pontus Vault Junior"
                    />
                  </label>
                  <label className="field">
                    <span>Junior token symbol</span>
                    <input
                      value={deployJuniorTokenSymbol}
                      onChange={(event) => setDeployJuniorTokenSymbol(event.target.value)}
                      placeholder="ptJ"
                    />
                  </label>
                  <label className="field">
                    <span>BoringVault name</span>
                    <input
                      value={deployBoringVaultName}
                      onChange={(event) => setDeployBoringVaultName(event.target.value)}
                      placeholder="Pontus Vault Base"
                    />
                  </label>
                  <label className="field">
                    <span>BoringVault symbol</span>
                    <input
                      value={deployBoringVaultSymbol}
                      onChange={(event) => setDeployBoringVaultSymbol(event.target.value)}
                      placeholder="PTVB"
                    />
                  </label>
                  <label className="field">
                    <span>BoringVault decimals</span>
                    <input
                      value={deployBoringVaultDecimals}
                      onChange={(event) => setDeployBoringVaultDecimals(event.target.value)}
                      inputMode="numeric"
                      placeholder="18"
                    />
                  </label>
                  {selectedVault && isReadyAddress(selectedVault.vaultAddress) ? (
                    <div className="card-actions operator-grid__full">
                      <Link className="button" href={`/vaults/${selectedVault.vaultId}/deposit`}>
                        Supply (deposit)
                      </Link>
                      <Link
                        className="button button--ghost"
                        href={`/vaults/${selectedVault.vaultId}/redeem`}
                      >
                        Redeem
                      </Link>
                      <span className="chip">Uses connected wallet</span>
                    </div>
                  ) : (
                    <p className="muted operator-grid__full">
                      Supply becomes available after the vault is deployed and addresses are synced.
                    </p>
                  )}
                </div>
              </>
            ) : null}

            {activeModule === "risk_caps" ? (
              <div className="operator-grid">
                <label className="field">
                  <span>Max senior ratio (bps)</span>
                  <input
                    value={maxSeniorRatioBps}
                    onChange={(event) => setMaxSeniorRatioBps(event.target.value)}
                    inputMode="numeric"
                  />
                </label>
                <label className="field">
                  <span>Senior rate per second (wad)</span>
                  <input
                    value={seniorRatePerSecondWad}
                    onChange={(event) => setSeniorRatePerSecondWad(event.target.value)}
                    inputMode="numeric"
                  />
                </label>
                <label className="field operator-grid__full">
                  <span>Rate model address (optional)</span>
                  <input
                    value={rateModel}
                    onChange={(event) => setRateModel(event.target.value)}
                    placeholder="0x..."
                  />
                </label>
              </div>
            ) : null}

            {activeModule === "accountant" ? (
              <div className="operator-grid">
                <label className="field">
                  <span>Vault</span>
                  <input value={selectedVault?.vaultAddress ?? ""} readOnly />
                </label>
                <label className="field">
                  <span>Asset</span>
                  <input value={selectedVault?.assetAddress ?? ""} readOnly />
                </label>
                <label className="field operator-grid__full">
                  <span>Accountant</span>
                  <input
                    value={rateUpdateAccountant}
                    onChange={(event) => setRateUpdateAccountant(event.target.value)}
                    placeholder="0x..."
                  />
                </label>
                <label className="field">
                  <span>Min update threshold (bps)</span>
                  <input
                    value={rateUpdateMinBps}
                    onChange={(event) => setRateUpdateMinBps(event.target.value)}
                    inputMode="numeric"
                  />
                </label>
                <label className="field">
                  <span>Allow pause update</span>
                  <select
                    value={rateUpdateAllowPause ? "true" : "false"}
                    onChange={(event) => setRateUpdateAllowPause(event.target.value === "true")}
                  >
                    <option value="false">false</option>
                    <option value="true">true</option>
                  </select>
                </label>
              </div>
            ) : null}

            {activeModule === "listing" ? (
              <>
                <label className="field">
                  <span>Target listing status</span>
                  <select
                    value={listingTarget}
                    onChange={(event) => setListingTarget(event.target.value as ListingTarget)}
                  >
                    <option value="LIVE">LIVE</option>
                    <option value="COMING_SOON">COMING_SOON</option>
                  </select>
                </label>
                <label className="field">
                  <span>Listing note (optional)</span>
                  <input
                    value={listingNote}
                    onChange={(event) => setListingNote(event.target.value)}
                    placeholder="Readiness checklist reference, governance ticket, etc."
                  />
                </label>
              </>
            ) : null}

            {activeModule === "rebalance" ? (
              <div className="operator-grid">
                <label className="field">
                  <span>Route</span>
                  <select
                    value={rebalanceRoute}
                    onChange={(event) => setRebalanceRoute(event.target.value)}
                  >
                    {REBALANCE_ROUTES.map((route) => (
                      <option key={route.value} value={route.value}>
                        {route.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span>Intent</span>
                  <select
                    value={rebalanceIntent}
                    onChange={(event) => setRebalanceIntent(event.target.value as RebalanceIntent)}
                  >
                    <option value="deploy-capital">Deploy capital</option>
                    <option value="raise-cash">Raise cash for redemptions</option>
                  </select>
                </label>
                <label className="field">
                  <span>Notional USD</span>
                  <input
                    value={rebalanceNotionalUsd}
                    onChange={(event) => setRebalanceNotionalUsd(event.target.value)}
                    inputMode="numeric"
                  />
                </label>
                <label className="field">
                  <span>Min cash buffer (bps)</span>
                  <input
                    value={minCashBufferBps}
                    onChange={(event) => setMinCashBufferBps(event.target.value)}
                    inputMode="numeric"
                  />
                </label>
              </div>
            ) : null}

            {activeModule === "vault_profile" ? (
              <div className="card-actions">
                <button
                  className="button"
                  type="button"
                  onClick={() => void saveVaultProfile()}
                  disabled={busyAction !== null}
                >
                  {busyAction === `save-profile:${selectedVaultId}`
                    ? "Saving..."
                    : "Save vault profile"}
                </button>
                <span className="chip">Updates discovery + detail copy</span>
              </div>
            ) : null}

            {activeModule === "accountant" ? (
              <div className="card-actions">
                <button
                  className="button"
                  type="button"
                  onClick={() => void runAccountantUpdateRate()}
                  disabled={busyAction !== null}
                >
                  {busyAction === "accountant:update-rate"
                    ? "Updating..."
                    : "Update exchange rate"}
                </button>
                <span className="chip">script/UpdateExchangeRate.s.sol</span>
              </div>
            ) : null}

            {activeModule !== "overview" &&
            activeModule !== "vault_profile" &&
            activeModule !== "accountant" &&
            activeModule !== "history" ? (
              <div className="card-actions">
                <button
                  className="button"
                  type="button"
                  onClick={() => void createOperation()}
                  disabled={busyAction !== null}
                >
                  {busyAction === "create" ? "Preparing..." : prepareActionLabel}
                </button>
                {activeJobType ? <span className="chip">Job: {activeJobType}</span> : null}
              </div>
            ) : null}

            {errorMessage ? <p className="operator-error">{errorMessage}</p> : null}
            {infoMessage ? <p className="operator-info">{infoMessage}</p> : null}
          </div>

          <div className="card operator-sidecard">
            <h3>Execution readiness</h3>
            <div className="operator-kv">
              <span>Selected vault</span>
              <strong>{selectedVault?.name ?? "—"}</strong>
            </div>
            <div className="operator-kv">
              <span>Vault status</span>
              <strong>{selectedVault?.uiConfig.status ?? "—"}</strong>
            </div>
            <div className="operator-kv">
              <span>Asset</span>
              <strong>{selectedVault?.assetSymbol ?? "—"}</strong>
            </div>
            <div className="operator-kv">
              <span>Controller</span>
              <strong>{selectedVault ? shortHash(selectedVault.controllerAddress) : "—"}</strong>
            </div>
            <div className="operator-kv">
              <span>Infra configured</span>
              <strong>{infraReady ? "yes" : "no"}</strong>
            </div>
            <div className="operator-kv">
              <span>Deployed</span>
              <strong>{hasDeployedAddresses ? "yes" : "no"}</strong>
            </div>
            <div className="operator-kv">
              <span>Manager route support</span>
              <strong>{selectedCapabilityKeys.length === 0 ? "None selected" : `${selectedCapabilityKeys.length} enabled`}</strong>
            </div>

            {!hasCashSupport ? (
              <p className="operator-warning">
                No cash-raising route is enabled. Redemptions can fail during stress if
                capital is fully deployed in strategies.
              </p>
            ) : null}

            <p className="muted">
              Redemptions are direct, not queued. If vault cash is low, operator should run
              rebalance with <strong>raise cash</strong> intent before large exits.
            </p>
          </div>
        </div>
      </section>

      <section className="section section--tight reveal delay-2">
        <div className="card operator-history">
          <h3>Recent operations</h3>
          {operations.length === 0 ? (
            <p className="muted">No operations logged for this vault yet.</p>
          ) : (
            <div className="operator-table">
              <div className="operator-table__row operator-table__row--head">
                <span>Job</span>
                <span>Status</span>
                <span>Tx hash</span>
                <span>Steps</span>
              </div>
              {operations.map((operation) => {
                const steps = historyStepsByOperationId[operation.operationId];
                const txHash = resolveTxHashFromSteps(steps);
                return (
                  <button
                    key={operation.operationId}
                    type="button"
                    className="operator-table__row"
                    onClick={() => void loadOperation(operation.operationId)}
                    title={operation.operationId}
                  >
                    <span>{operation.jobType}</span>
                    <span>{operationStatusLabel(operation.status)}</span>
                    <span className="operator-mono">{txHash ? shortHash(txHash) : "—"}</span>
                    <span className="operator-mono">{summarizeStepsForTable(steps)}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </section>

      {activeOperation ? (
        <section className="section section--tight reveal delay-3">
          <div className="card operator-steps">
            <h3>Operation detail</h3>
            <p className="muted">
              {activeOperation.operation.jobType} · {activeOperation.operation.operationId}
            </p>
            {selectedOperationProgress ? (
              <div className="operator-progress">
                <div className="operator-progress__bar">
                  <span
                    className="operator-progress__fill"
                    style={{ width: `${selectedOperationProgress.percent}%` }}
                  />
                </div>
                <span className="chip">
                  {selectedOperationProgress.done}/{selectedOperationProgress.total} completed
                </span>
              </div>
            ) : null}
            <div className="operator-step-list">
              {activeOperation.steps.map((step) => {
                const isBusy = busyAction === `${activeOperation.operation.operationId}:${step.stepIndex}`;
                const isServerDeployStep =
                  activeOperation.operation.jobType === "DEPLOY_VAULT" &&
                  step.kind === "OFFCHAIN" &&
                  step.label === "Execute deployment transaction";
                const isServerDeployQueued =
                  isServerDeployStep && ["BROADCASTED", "RUNNING"].includes(step.status);
                const disableExecute =
                  isBusy || isStepTerminal(step.status) || isServerDeployQueued;
                return (
                  <article className="operator-step" key={step.stepId}>
                    <div className="operator-step__head">
                      <h4>
                        #{step.stepIndex + 1} {step.label}
                      </h4>
                      <span className="chip">{step.status.toLowerCase()}</span>
                    </div>
                    <p className="muted">{step.description ?? "No description."}</p>
                    {step.toAddress ? (
                      <p className="operator-mono">
                        to: {step.toAddress}
                        <br />
                        data: {step.calldata ?? "0x"}
                      </p>
                    ) : null}
                    {step.metadata ? (
                      <p className="operator-mono">metadata: {JSON.stringify(step.metadata)}</p>
                    ) : null}
                    {step.txHash ? <p className="operator-mono">tx: {shortHash(step.txHash)}</p> : null}
                    {step.proof ? <p className="operator-mono">proof: {shortHash(step.proof)}</p> : null}
                    {step.errorMessage ? <p className="operator-error">{step.errorMessage}</p> : null}
                    <div className="card-actions">
                      <button
                        className="button"
                        type="button"
                        disabled={disableExecute}
                        onClick={() => void executeStep(step)}
                      >
                        {isBusy
                          ? "Executing..."
                          : isServerDeployStep
                            ? step.status === "CREATED"
                              ? "Queue deployment"
                              : step.status === "RUNNING"
                                ? "Running..."
                                : "Queued"
                          : step.kind === "ONCHAIN" && EXECUTION_MODE === "send_transaction"
                            ? "Sign & send"
                            : "Sign & record"}
                      </button>
                      <span className="chip">{step.kind.toLowerCase()}</span>
                    </div>
                  </article>
                );
              })}
            </div>
          </div>
        </section>
      ) : null}
    </>
  );
}
