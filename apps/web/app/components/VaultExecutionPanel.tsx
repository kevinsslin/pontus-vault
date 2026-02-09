"use client";

import { useId, useState } from "react";
import type { VaultRecord } from "@pti/shared";
import { PHAROS_ATLANTIC } from "@pti/shared";
import { useDynamicContext } from "@dynamic-labs/sdk-react-core";
import { formatBps } from "../../lib/format";
import { parseNetworkChainId, PHAROS_CHAIN_ID, PHAROS_VIEM_CHAIN } from "../../lib/constants/network";
import WalletConnectButton from "./WalletConnectButton";

type ExecutionMode = "deposit" | "redeem";
type TrancheMode = "senior" | "junior";

type VaultExecutionPanelProps = {
  vault: VaultRecord;
  defaultMode?: ExecutionMode;
};

export default function VaultExecutionPanel({
  vault,
  defaultMode = "deposit",
}: VaultExecutionPanelProps) {
  const dynamic = useOptionalDynamicContext();
  const [mode, setMode] = useState<ExecutionMode>(defaultMode);
  const [tranche, setTranche] = useState<TrancheMode>("senior");
  const [amount, setAmount] = useState("");
  const [submitMessage, setSubmitMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const amountId = useId();

  const isDeposit = mode === "deposit";
  const actionLabel = isDeposit ? "Deposit" : "Redeem";
  const inputLabel = isDeposit ? `Amount (${vault.assetSymbol})` : "Shares";
  const submitLabel = isDeposit ? "Submit deposit" : "Submit redeem";

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitMessage(null);
    const raw = amount.trim();
    if (!raw) {
      setSubmitMessage("Please enter a valid amount.");
      return;
    }

    if (!dynamic?.primaryWallet) {
      setSubmitMessage("Connect your wallet first (then retry).");
      return;
    }

    const wallet = dynamic.primaryWallet;
    const walletAddress = wallet.address;
    if (!walletAddress) {
      setSubmitMessage("Wallet address unavailable. Reconnect your wallet and retry.");
      return;
    }

    const controller = vault.controllerAddress;
    if (!isReadyAddress(controller)) {
      setSubmitMessage("Vault controller address is missing. This vault is not ready for execution.");
      return;
    }

    const assetAddress = vault.assetAddress;
    if (!isReadyAddress(assetAddress)) {
      setSubmitMessage("Vault asset address is missing. This vault is not ready for execution.");
      return;
    }

    const trancheToken =
      tranche === "senior" ? vault.seniorTokenAddress : vault.juniorTokenAddress;
    if (!isDeposit && !isReadyAddress(trancheToken)) {
      setSubmitMessage("Tranche token address is missing. This vault is not ready for execution.");
      return;
    }

    const chainIdRaw = await wallet.getNetwork().catch(() => null);
    const chainId = parseNetworkChainId(chainIdRaw ?? undefined);
    if (chainId !== PHAROS_CHAIN_ID) {
      setSubmitMessage(
        `Wrong network (chainId=${chainId ?? "unknown"}). Switch to Pharos Atlantic (${PHAROS_CHAIN_ID}) and retry.`
      );
      return;
    }

    const decimals = guessAssetDecimals(assetAddress);
    let parsedAmount: bigint;
    try {
      parsedAmount = parseUnits(raw, decimals);
    } catch (err) {
      setSubmitMessage(err instanceof Error ? err.message : "Invalid amount format.");
      return;
    }
    if (parsedAmount <= 0n) {
      setSubmitMessage("Please enter a positive amount.");
      return;
    }

    setSubmitting(true);
    try {
      if (isDeposit) {
        setSubmitMessage("Step 1/2: Approve asset spend (wallet signature required)...");
        await sendTx(wallet, {
          from: walletAddress,
          to: assetAddress,
          data: encodeErc20Approve(controller, parsedAmount),
        });

        setSubmitMessage("Step 2/2: Submit deposit (wallet signature required)...");
        const txHash = await sendTx(wallet, {
          from: walletAddress,
          to: controller,
          data:
            tranche === "senior"
              ? encodeDepositSenior(parsedAmount, walletAddress)
              : encodeDepositJunior(parsedAmount, walletAddress),
        });

        setSubmitMessage(
          `Deposit submitted. Tx: ${txHash}\nExplorer: ${PHAROS_ATLANTIC.explorerUrl}/tx/${txHash}`
        );
      } else {
        // Redeem requires tranche token approval because controller burns via burnFrom().
        setSubmitMessage("Step 1/2: Approve tranche token burn (wallet signature required)...");
        await sendTx(wallet, {
          from: walletAddress,
          to: trancheToken,
          data: encodeErc20Approve(controller, parsedAmount),
        });

        setSubmitMessage("Step 2/2: Submit redeem (wallet signature required)...");
        const txHash = await sendTx(wallet, {
          from: walletAddress,
          to: controller,
          data:
            tranche === "senior"
              ? encodeRedeemSenior(parsedAmount, walletAddress)
              : encodeRedeemJunior(parsedAmount, walletAddress),
        });

        setSubmitMessage(
          `Redeem submitted. Tx: ${txHash}\nExplorer: ${PHAROS_ATLANTIC.explorerUrl}/tx/${txHash}`
        );
      }
    } catch (err) {
      setSubmitMessage(err instanceof Error ? err.message : "Transaction failed.");
    } finally {
      setSubmitting(false);
    }
  }
  const routeLabel =
    vault.uiConfig.routeLabel ??
    (vault.uiConfig.strategyKeys && vault.uiConfig.strategyKeys.length > 0
      ? vault.uiConfig.strategyKeys.join(" + ")
      : "Multi-strategy");
  const selectedApy = formatBps(
    tranche === "senior" ? vault.metrics.seniorApyBps ?? null : vault.metrics.juniorApyBps ?? null
  );

  return (
    <article className="card execution-panel" id="execute">
      <div className="execution-panel__header">
        <p className="eyebrow">Trade ticket</p>
        <h3>{isDeposit ? "Deposit into vault" : "Redeem from vault"}</h3>
      </div>

      <div className="execution-segment" role="tablist" aria-label="Execution mode">
        <button
          className={`segment-button ${isDeposit ? "segment-button--active" : ""}`}
          onClick={() => setMode("deposit")}
          role="tab"
          aria-selected={isDeposit}
          type="button"
        >
          Deposit
        </button>
        <button
          className={`segment-button ${!isDeposit ? "segment-button--active" : ""}`}
          onClick={() => setMode("redeem")}
          role="tab"
          aria-selected={!isDeposit}
          type="button"
        >
          Redeem
        </button>
      </div>

      <form className="execution-form" aria-label={`${actionLabel} form`} onSubmit={handleSubmit}>
        <label className="field-label" htmlFor={amountId}>
          {inputLabel}
        </label>
        <input
          id={amountId}
          name="amount"
          type="number"
          placeholder="0.00"
          className="input"
          inputMode="decimal"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />

        <div>
          <p className="field-label">Tranche</p>
          <div className="radio-group">
            <label className="radio-chip">
              <input
                type="radio"
                name="tranche"
                checked={tranche === "senior"}
                onChange={() => setTranche("senior")}
              />
              Senior
            </label>
            <label className="radio-chip">
              <input
                type="radio"
                name="tranche"
                checked={tranche === "junior"}
                onChange={() => setTranche("junior")}
              />
              Junior
            </label>
          </div>
        </div>

        <div className="execution-actions">
          <button className="button" type="submit" disabled={submitting}>
            {submitting ? "Submitting..." : submitLabel}
          </button>
          <WalletConnectButton />
        </div>
        {submitMessage ? (
          <p className="execution-form__message" role="status">
            {submitMessage}
          </p>
        ) : null}
      </form>

      <div className="execution-summary">
        <div className="execution-summary__row">
          <span className="execution-summary__label">Action</span>
          <span className="execution-summary__value">{actionLabel}</span>
        </div>
        <div className="execution-summary__row">
          <span className="execution-summary__label">Tranche</span>
          <span className="execution-summary__value">{tranche === "senior" ? "Senior" : "Junior"}</span>
        </div>
        <div className="execution-summary__row">
          <span className="execution-summary__label">Selected APY</span>
          <span className="execution-summary__value">{selectedApy}</span>
        </div>
        <div className="execution-summary__row">
          <span className="execution-summary__label">Route</span>
          <span className="execution-summary__value">{routeLabel}</span>
        </div>
      </div>
    </article>
  );
}

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

function useOptionalDynamicContext() {
  try {
    return useDynamicContext();
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

function guessAssetDecimals(assetAddress: string): number {
  const normalized = assetAddress.toLowerCase();
  if (normalized === PHAROS_ATLANTIC.tokens.USDT.toLowerCase()) return 6;
  if (normalized === PHAROS_ATLANTIC.tokens.USDC.toLowerCase()) return 6;
  return 18;
}

function parseUnits(input: string, decimals: number): bigint {
  const raw = input.trim();
  if (!/^[0-9]+(\.[0-9]+)?$/.test(raw)) {
    throw new Error("Invalid amount format. Use digits with optional decimals (e.g., 12.34).");
  }
  const [wholeRaw, fracRaw = ""] = raw.split(".");
  const whole = wholeRaw === "" ? "0" : wholeRaw;
  if (fracRaw.length > decimals) {
    throw new Error(`Too many decimal places (max ${decimals}).`);
  }
  const fracPadded = (fracRaw + "0".repeat(decimals)).slice(0, decimals);
  const base = 10n ** BigInt(decimals);
  return BigInt(whole) * base + BigInt(fracPadded || "0");
}

function pad32(hex: string): string {
  return hex.padStart(64, "0");
}

function encodeAddress(addr: string): string {
  return pad32(addr.toLowerCase().replace(/^0x/, ""));
}

function encodeUint256(value: bigint): string {
  return pad32(value.toString(16));
}

// ERC20 approve(address spender,uint256 amount) => 0x095ea7b3
function encodeErc20Approve(spender: string, amount: bigint): `0x${string}` {
  const selector = "095ea7b3";
  const data = selector + encodeAddress(spender) + encodeUint256(amount);
  return `0x${data}`;
}

// TrancheController selectors (computed from signatures):
// depositSenior(uint256,address)
const DEPOSIT_SENIOR_SELECTOR = "8a2ba9d2";
// depositJunior(uint256,address)
const DEPOSIT_JUNIOR_SELECTOR = "8097be04";
// redeemSenior(uint256,address)
const REDEEM_SENIOR_SELECTOR = "51e364c3";
// redeemJunior(uint256,address)
const REDEEM_JUNIOR_SELECTOR = "abda961a";

function encodeDepositSenior(assetsIn: bigint, receiver: string): `0x${string}` {
  return `0x${DEPOSIT_SENIOR_SELECTOR}${encodeUint256(assetsIn)}${encodeAddress(receiver)}`;
}

function encodeDepositJunior(assetsIn: bigint, receiver: string): `0x${string}` {
  return `0x${DEPOSIT_JUNIOR_SELECTOR}${encodeUint256(assetsIn)}${encodeAddress(receiver)}`;
}

function encodeRedeemSenior(sharesIn: bigint, receiver: string): `0x${string}` {
  return `0x${REDEEM_SENIOR_SELECTOR}${encodeUint256(sharesIn)}${encodeAddress(receiver)}`;
}

function encodeRedeemJunior(sharesIn: bigint, receiver: string): `0x${string}` {
  return `0x${REDEEM_JUNIOR_SELECTOR}${encodeUint256(sharesIn)}${encodeAddress(receiver)}`;
}

async function sendTx(
  primaryWallet: { address: string; connector?: unknown },
  params: { from: string; to: string; data: `0x${string}`; valueWei?: bigint }
): Promise<string> {
  const connector = (primaryWallet.connector ?? {}) as {
    getWalletClient?: () => {
      sendTransaction?: (p: {
        account?: string;
        to: string;
        data?: `0x${string}`;
        value?: bigint;
      }) => Promise<string>;
    };
    getSigner?: () => Promise<{
      sendTransaction?: (p: { to: string; data?: string; value?: bigint }) => Promise<{ hash?: string } | string>;
    }>;
  };

  const value = params.valueWei ?? 0n;
  const walletClient = connector.getWalletClient?.();
  if (walletClient?.sendTransaction) {
    // Connector types omit `chain` but viem WalletClient requires it at runtime
    const txParams = {
      chain: PHAROS_VIEM_CHAIN,
      account: params.from,
      to: params.to,
      data: params.data,
      value,
    };
    const txHash = await walletClient.sendTransaction(
      txParams as { account?: string; to: string; data?: `0x${string}`; value?: bigint }
    );
    if (txHash) return typeof txHash === "string" ? txHash : String(txHash);
  }

  if (connector.getSigner) {
    const signer = await connector.getSigner();
    if (signer?.sendTransaction) {
      const tx = await signer.sendTransaction({
        to: params.to,
        data: params.data,
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
      const valueHex = `0x${value.toString(16)}`;
      return ethereum.request({
        method: "eth_sendTransaction",
        params: [
          {
            from: params.from,
            to: params.to,
            data: params.data,
            value: valueHex,
          },
        ],
      });
    }
  }

  throw new Error("Wallet transaction transport is unavailable.");
}
