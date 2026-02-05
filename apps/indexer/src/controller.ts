import { BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  Accrued,
  JuniorDeposited,
  JuniorRedeemed,
  SeniorDeposited,
  SeniorRedeemed,
} from "../generated/templates/TrancheController/TrancheController";
import { TrancheEvent, Vault } from "../generated/schema";

function loadVault(id: string): Vault | null {
  return Vault.load(id);
}

function createEvent(id: string, eventType: string): TrancheEvent {
  const entry = new TrancheEvent(id);
  entry.type = eventType;
  return entry;
}

function eventId(hash: string, logIndex: string): string {
  return hash + "-" + logIndex;
}

function applyCommonEventFields(
  entry: TrancheEvent,
  vaultId: string,
  blockNumber: BigInt,
  timestamp: BigInt,
  txHash: Bytes
): void {
  entry.vault = vaultId;
  entry.blockNumber = blockNumber;
  entry.timestamp = timestamp;
  entry.txHash = txHash;
}

export function handleSeniorDeposited(event: SeniorDeposited): void {
  const vault = loadVault(event.address.toHexString());
  if (vault == null) return;

  const id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  const entry = createEvent(id, "SENIOR_DEPOSIT");
  applyCommonEventFields(entry, vault.id, event.block.number, event.block.timestamp, event.transaction.hash);
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  vault.updatedAt = event.block.timestamp;
  vault.save();
}

export function handleJuniorDeposited(event: JuniorDeposited): void {
  const vault = loadVault(event.address.toHexString());
  if (vault == null) return;

  const id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  const entry = createEvent(id, "JUNIOR_DEPOSIT");
  applyCommonEventFields(entry, vault.id, event.block.number, event.block.timestamp, event.transaction.hash);
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  vault.updatedAt = event.block.timestamp;
  vault.save();
}

export function handleSeniorRedeemed(event: SeniorRedeemed): void {
  const vault = loadVault(event.address.toHexString());
  if (vault == null) return;

  const id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  const entry = createEvent(id, "SENIOR_REDEEM");
  applyCommonEventFields(entry, vault.id, event.block.number, event.block.timestamp, event.transaction.hash);
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  vault.updatedAt = event.block.timestamp;
  vault.save();
}

export function handleJuniorRedeemed(event: JuniorRedeemed): void {
  const vault = loadVault(event.address.toHexString());
  if (vault == null) return;

  const id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  const entry = createEvent(id, "JUNIOR_REDEEM");
  applyCommonEventFields(entry, vault.id, event.block.number, event.block.timestamp, event.transaction.hash);
  entry.caller = event.params.caller;
  entry.receiver = event.params.receiver;
  entry.assets = event.params.assets;
  entry.shares = event.params.shares;
  entry.save();

  vault.updatedAt = event.block.timestamp;
  vault.save();
}

export function handleAccrued(event: Accrued): void {
  const vault = loadVault(event.address.toHexString());
  if (vault == null) return;

  const id = eventId(event.transaction.hash.toHexString(), event.logIndex.toString());
  const entry = createEvent(id, "ACCRUE");
  applyCommonEventFields(entry, vault.id, event.block.number, event.block.timestamp, event.transaction.hash);
  entry.seniorDebt = event.params.newSeniorDebt;
  entry.dt = event.params.dt;
  entry.save();

  vault.seniorDebt = event.params.newSeniorDebt;
  vault.updatedAt = event.block.timestamp;
  vault.save();
}
