import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import {
  Accrued,
  JuniorDeposited,
  JuniorRedeemed,
  SeniorDeposited,
  SeniorRedeemed,
  TrancheController as TrancheControllerContract,
} from "../generated/templates/TrancheController/TrancheController";
import { ERC20 } from "../generated/templates/TrancheController/ERC20";
import { TrancheEvent, TrancheSnapshot, Vault } from "../generated/schema";

const ZERO = BigInt.fromI32(0);
const WAD = BigInt.fromString("1000000000000000000");

function getVault(controller: Address): Vault | null {
  return Vault.load(controller.toHexString());
}

function fallbackBigInt(value: BigInt | null): BigInt {
  return value == null ? ZERO : value;
}

function readTotalSupply(token: Address, fallback: BigInt | null): BigInt {
  const contract = ERC20.bind(token);
  const result = contract.try_totalSupply();
  if (result.reverted) {
    return fallback == null ? ZERO : fallback;
  }
  return result.value;
}

function updateSnapshot(
  vault: Vault,
  controller: Address,
  eventType: string,
  event: ethereum.Event,
  fallbackDebt: BigInt | null
): void {
  const contract = TrancheControllerContract.bind(controller);

  const totalValueResult = contract.try_previewV();
  const totalValue = totalValueResult.reverted ? fallbackBigInt(vault.tvl) : totalValueResult.value;

  const debtResult = contract.try_seniorDebt();
  let seniorDebt = debtResult.reverted ? fallbackBigInt(vault.seniorDebt) : debtResult.value;
  if (debtResult.reverted && fallbackDebt != null) {
    seniorDebt = fallbackDebt;
  }

  const seniorToken = Address.fromBytes(vault.seniorToken);
  const juniorToken = Address.fromBytes(vault.juniorToken);
  const seniorSupply = readTotalSupply(seniorToken, vault.seniorSupply);
  const juniorSupply = readTotalSupply(juniorToken, vault.juniorSupply);

  let seniorValue = totalValue;
  if (totalValue.gt(seniorDebt)) {
    seniorValue = seniorDebt;
  }
  const juniorValue = totalValue.minus(seniorValue);

  const underwater = totalValue.lt(seniorDebt);
  const seniorPrice = seniorSupply.equals(ZERO) ? ZERO : seniorValue.times(WAD).div(seniorSupply);
  const juniorPrice = juniorSupply.equals(ZERO) ? ZERO : juniorValue.times(WAD).div(juniorSupply);

  const snapshotId =
    vault.id + "-" + event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  const snapshot = new TrancheSnapshot(snapshotId);
  snapshot.vault = vault.id;
  snapshot.blockNumber = event.block.number;
  snapshot.timestamp = event.block.timestamp;
  snapshot.txHash = event.transaction.hash;
  snapshot.eventType = eventType;
  snapshot.totalValue = totalValue;
  snapshot.seniorDebt = seniorDebt;
  snapshot.seniorSupply = seniorSupply;
  snapshot.juniorSupply = juniorSupply;
  snapshot.seniorPrice = seniorPrice;
  snapshot.juniorPrice = juniorPrice;
  snapshot.tvl = totalValue;
  snapshot.underwater = underwater;
  snapshot.save();

  vault.lastSnapshot = snapshot.id;
  vault.tvl = totalValue;
  vault.seniorPrice = seniorPrice;
  vault.juniorPrice = juniorPrice;
  vault.seniorDebt = seniorDebt;
  vault.seniorSupply = seniorSupply;
  vault.juniorSupply = juniorSupply;
  vault.updatedAt = event.block.timestamp;
  vault.save();
}

function createEventId(event: ethereum.Event): string {
  return event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
}

export function handleSeniorDeposited(event: SeniorDeposited): void {
  const vault = getVault(event.address);
  if (vault == null) return;

  const entry = new TrancheEvent(createEventId(event));
  entry.vault = vault.id;
  entry.type = "SENIOR_DEPOSIT";
  entry.blockNumber = event.block.number;
  entry.timestamp = event.block.timestamp;
  entry.txHash = event.transaction.hash;
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  updateSnapshot(vault, event.address, entry.type, event, null);
}

export function handleJuniorDeposited(event: JuniorDeposited): void {
  const vault = getVault(event.address);
  if (vault == null) return;

  const entry = new TrancheEvent(createEventId(event));
  entry.vault = vault.id;
  entry.type = "JUNIOR_DEPOSIT";
  entry.blockNumber = event.block.number;
  entry.timestamp = event.block.timestamp;
  entry.txHash = event.transaction.hash;
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  updateSnapshot(vault, event.address, entry.type, event, null);
}

export function handleSeniorRedeemed(event: SeniorRedeemed): void {
  const vault = getVault(event.address);
  if (vault == null) return;

  const entry = new TrancheEvent(createEventId(event));
  entry.vault = vault.id;
  entry.type = "SENIOR_REDEEM";
  entry.blockNumber = event.block.number;
  entry.timestamp = event.block.timestamp;
  entry.txHash = event.transaction.hash;
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  updateSnapshot(vault, event.address, entry.type, event, null);
}

export function handleJuniorRedeemed(event: JuniorRedeemed): void {
  const vault = getVault(event.address);
  if (vault == null) return;

  const entry = new TrancheEvent(createEventId(event));
  entry.vault = vault.id;
  entry.type = "JUNIOR_REDEEM";
  entry.blockNumber = event.block.number;
  entry.timestamp = event.block.timestamp;
  entry.txHash = event.transaction.hash;
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  updateSnapshot(vault, event.address, entry.type, event, null);
}

export function handleAccrued(event: Accrued): void {
  const vault = getVault(event.address);
  if (vault == null) return;

  const entry = new TrancheEvent(createEventId(event));
  entry.vault = vault.id;
  entry.type = "ACCRUE";
  entry.blockNumber = event.block.number;
  entry.timestamp = event.block.timestamp;
  entry.txHash = event.transaction.hash;
  entry.seniorDebt = event.params.newSeniorDebt;
  entry.dt = event.params.dt;
  entry.save();

  updateSnapshot(vault, event.address, entry.type, event, event.params.newSeniorDebt);
}
