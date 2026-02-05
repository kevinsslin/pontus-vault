import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  Accrued,
  JuniorDeposited,
  JuniorRedeemed,
  SeniorDeposited,
  SeniorRedeemed,
  TrancheController as TrancheControllerContract,
} from "../generated/templates/TrancheController/TrancheController";
import { ERC20 } from "../generated/templates/TrancheController/ERC20";
import {
  TrancheEvent,
  TrancheSnapshot,
  Vault,
  VaultDailySnapshot,
  VaultHourlySnapshot,
} from "../generated/schema";

const ZERO = BigInt.fromI32(0);
const WAD = BigInt.fromString("1000000000000000000");
const SECONDS_PER_HOUR = BigInt.fromI32(3600);
const SECONDS_PER_DAY = BigInt.fromI32(86400);

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

function minBigInt(a: BigInt, b: BigInt): BigInt {
  if (a.lt(b)) {
    return a;
  }
  return b;
}

function maxBigInt(a: BigInt, b: BigInt): BigInt {
  if (a.gt(b)) {
    return a;
  }
  return b;
}

function saturatingSub(a: BigInt, b: BigInt): BigInt {
  if (a.lt(b) || a.equals(b)) {
    return ZERO;
  }
  return a.minus(b);
}

function refreshDerivedPrices(vault: Vault): void {
  const seniorValue = minBigInt(vault.tvl, vault.seniorDebt);

  let juniorValue = ZERO;
  if (vault.tvl.gt(vault.seniorDebt)) {
    juniorValue = vault.tvl.minus(vault.seniorDebt);
  }

  if (vault.seniorSupply.equals(ZERO)) {
    vault.seniorPrice = ZERO;
  } else {
    vault.seniorPrice = seniorValue.times(WAD).div(vault.seniorSupply);
  }

  if (vault.juniorSupply.equals(ZERO)) {
    vault.juniorPrice = ZERO;
  } else {
    vault.juniorPrice = juniorValue.times(WAD).div(vault.juniorSupply);
  }
}

function refreshOnchainState(vault: Vault, controllerAddress: Address): void {
  const controller = TrancheControllerContract.bind(controllerAddress);
  const tvlResult = controller.try_previewV();
  if (!tvlResult.reverted) {
    vault.tvl = tvlResult.value;
  }

  const debtResult = controller.try_seniorDebt();
  if (!debtResult.reverted) {
    vault.seniorDebt = debtResult.value;
  }

  const seniorToken = ERC20.bind(Address.fromBytes(vault.seniorToken));
  const seniorSupplyResult = seniorToken.try_totalSupply();
  if (!seniorSupplyResult.reverted) {
    vault.seniorSupply = seniorSupplyResult.value;
  }

  const juniorToken = ERC20.bind(Address.fromBytes(vault.juniorToken));
  const juniorSupplyResult = juniorToken.try_totalSupply();
  if (!juniorSupplyResult.reverted) {
    vault.juniorSupply = juniorSupplyResult.value;
  }
}

function writeSnapshot(
  vault: Vault,
  blockNumber: BigInt,
  timestamp: BigInt,
  txHash: Bytes,
  logIndex: BigInt,
  eventType: string
): string {
  const id = eventId(txHash.toHexString(), logIndex.toString());

  const snapshot = new TrancheSnapshot(id);
  snapshot.vault = vault.id;
  snapshot.blockNumber = blockNumber;
  snapshot.timestamp = timestamp;
  snapshot.txHash = txHash;
  snapshot.eventType = eventType;
  snapshot.totalValue = vault.tvl;
  snapshot.seniorDebt = vault.seniorDebt;
  snapshot.seniorSupply = vault.seniorSupply;
  snapshot.juniorSupply = vault.juniorSupply;
  snapshot.seniorPrice = vault.seniorPrice;
  snapshot.juniorPrice = vault.juniorPrice;
  snapshot.tvl = vault.tvl;
  snapshot.underwater = vault.tvl.lt(vault.seniorDebt);
  snapshot.save();

  return id;
}

function bucketStart(timestamp: BigInt, bucketSize: BigInt): BigInt {
  return timestamp.div(bucketSize).times(bucketSize);
}

function hourlySnapshotId(vaultId: string, periodStart: BigInt): string {
  return vaultId + "-h-" + periodStart.toString();
}

function dailySnapshotId(vaultId: string, periodStart: BigInt): string {
  return vaultId + "-d-" + periodStart.toString();
}

function initHourlySnapshot(
  snapshot: VaultHourlySnapshot,
  vault: Vault,
  periodStart: BigInt,
  timestamp: BigInt
): void {
  snapshot.vault = vault.id;
  snapshot.periodStart = periodStart;
  snapshot.periodEnd = periodStart.plus(SECONDS_PER_HOUR);
  snapshot.updatedAt = timestamp;
  snapshot.lastTxHash = Bytes.fromHexString("0x00");

  snapshot.txCount = 0;
  snapshot.eventCount = 0;
  snapshot.depositCount = 0;
  snapshot.redeemCount = 0;
  snapshot.accrualCount = 0;

  snapshot.seniorDepositAssets = ZERO;
  snapshot.juniorDepositAssets = ZERO;
  snapshot.seniorRedeemAssets = ZERO;
  snapshot.juniorRedeemAssets = ZERO;

  snapshot.openTvl = vault.tvl;
  snapshot.highTvl = vault.tvl;
  snapshot.lowTvl = vault.tvl;
  snapshot.closeTvl = vault.tvl;

  snapshot.openSeniorPrice = vault.seniorPrice;
  snapshot.highSeniorPrice = vault.seniorPrice;
  snapshot.lowSeniorPrice = vault.seniorPrice;
  snapshot.closeSeniorPrice = vault.seniorPrice;

  snapshot.openJuniorPrice = vault.juniorPrice;
  snapshot.highJuniorPrice = vault.juniorPrice;
  snapshot.lowJuniorPrice = vault.juniorPrice;
  snapshot.closeJuniorPrice = vault.juniorPrice;

  snapshot.tvl = vault.tvl;
  snapshot.seniorDebt = vault.seniorDebt;
  snapshot.seniorSupply = vault.seniorSupply;
  snapshot.juniorSupply = vault.juniorSupply;
  snapshot.seniorPrice = vault.seniorPrice;
  snapshot.juniorPrice = vault.juniorPrice;
  snapshot.underwater = vault.tvl.lt(vault.seniorDebt);
}

function initDailySnapshot(
  snapshot: VaultDailySnapshot,
  vault: Vault,
  periodStart: BigInt,
  timestamp: BigInt
): void {
  snapshot.vault = vault.id;
  snapshot.periodStart = periodStart;
  snapshot.periodEnd = periodStart.plus(SECONDS_PER_DAY);
  snapshot.updatedAt = timestamp;
  snapshot.lastTxHash = Bytes.fromHexString("0x00");

  snapshot.txCount = 0;
  snapshot.eventCount = 0;
  snapshot.depositCount = 0;
  snapshot.redeemCount = 0;
  snapshot.accrualCount = 0;

  snapshot.seniorDepositAssets = ZERO;
  snapshot.juniorDepositAssets = ZERO;
  snapshot.seniorRedeemAssets = ZERO;
  snapshot.juniorRedeemAssets = ZERO;

  snapshot.openTvl = vault.tvl;
  snapshot.highTvl = vault.tvl;
  snapshot.lowTvl = vault.tvl;
  snapshot.closeTvl = vault.tvl;

  snapshot.openSeniorPrice = vault.seniorPrice;
  snapshot.highSeniorPrice = vault.seniorPrice;
  snapshot.lowSeniorPrice = vault.seniorPrice;
  snapshot.closeSeniorPrice = vault.seniorPrice;

  snapshot.openJuniorPrice = vault.juniorPrice;
  snapshot.highJuniorPrice = vault.juniorPrice;
  snapshot.lowJuniorPrice = vault.juniorPrice;
  snapshot.closeJuniorPrice = vault.juniorPrice;

  snapshot.tvl = vault.tvl;
  snapshot.seniorDebt = vault.seniorDebt;
  snapshot.seniorSupply = vault.seniorSupply;
  snapshot.juniorSupply = vault.juniorSupply;
  snapshot.seniorPrice = vault.seniorPrice;
  snapshot.juniorPrice = vault.juniorPrice;
  snapshot.underwater = vault.tvl.lt(vault.seniorDebt);
}

function updateHourlySnapshot(
  vault: Vault,
  timestamp: BigInt,
  txHash: Bytes,
  seniorDepositAssets: BigInt,
  juniorDepositAssets: BigInt,
  seniorRedeemAssets: BigInt,
  juniorRedeemAssets: BigInt,
  isAccrual: boolean
): void {
  const start = bucketStart(timestamp, SECONDS_PER_HOUR);
  const id = hourlySnapshotId(vault.id, start);
  let snapshot = VaultHourlySnapshot.load(id);

  if (snapshot == null) {
    snapshot = new VaultHourlySnapshot(id);
    initHourlySnapshot(snapshot, vault, start, timestamp);
  }

  if (snapshot.lastTxHash.toHexString() != txHash.toHexString()) {
    snapshot.txCount = snapshot.txCount + 1;
    snapshot.lastTxHash = txHash;
  }
  snapshot.eventCount = snapshot.eventCount + 1;

  let hasDeposit = false;
  if (!seniorDepositAssets.equals(ZERO)) {
    hasDeposit = true;
  }
  if (!juniorDepositAssets.equals(ZERO)) {
    hasDeposit = true;
  }
  if (hasDeposit) {
    snapshot.depositCount = snapshot.depositCount + 1;
  }

  let hasRedeem = false;
  if (!seniorRedeemAssets.equals(ZERO)) {
    hasRedeem = true;
  }
  if (!juniorRedeemAssets.equals(ZERO)) {
    hasRedeem = true;
  }
  if (hasRedeem) {
    snapshot.redeemCount = snapshot.redeemCount + 1;
  }

  if (isAccrual) {
    snapshot.accrualCount = snapshot.accrualCount + 1;
  }

  snapshot.seniorDepositAssets = snapshot.seniorDepositAssets.plus(seniorDepositAssets);
  snapshot.juniorDepositAssets = snapshot.juniorDepositAssets.plus(juniorDepositAssets);
  snapshot.seniorRedeemAssets = snapshot.seniorRedeemAssets.plus(seniorRedeemAssets);
  snapshot.juniorRedeemAssets = snapshot.juniorRedeemAssets.plus(juniorRedeemAssets);

  snapshot.highTvl = maxBigInt(snapshot.highTvl, vault.tvl);
  snapshot.lowTvl = minBigInt(snapshot.lowTvl, vault.tvl);
  snapshot.closeTvl = vault.tvl;
  snapshot.highSeniorPrice = maxBigInt(snapshot.highSeniorPrice, vault.seniorPrice);
  snapshot.lowSeniorPrice = minBigInt(snapshot.lowSeniorPrice, vault.seniorPrice);
  snapshot.closeSeniorPrice = vault.seniorPrice;
  snapshot.highJuniorPrice = maxBigInt(snapshot.highJuniorPrice, vault.juniorPrice);
  snapshot.lowJuniorPrice = minBigInt(snapshot.lowJuniorPrice, vault.juniorPrice);
  snapshot.closeJuniorPrice = vault.juniorPrice;

  snapshot.tvl = snapshot.closeTvl;
  snapshot.seniorDebt = vault.seniorDebt;
  snapshot.seniorSupply = vault.seniorSupply;
  snapshot.juniorSupply = vault.juniorSupply;
  snapshot.seniorPrice = snapshot.closeSeniorPrice;
  snapshot.juniorPrice = snapshot.closeJuniorPrice;
  snapshot.underwater = vault.tvl.lt(vault.seniorDebt);
  snapshot.updatedAt = timestamp;
  snapshot.save();
}

function updateDailySnapshot(
  vault: Vault,
  timestamp: BigInt,
  txHash: Bytes,
  seniorDepositAssets: BigInt,
  juniorDepositAssets: BigInt,
  seniorRedeemAssets: BigInt,
  juniorRedeemAssets: BigInt,
  isAccrual: boolean
): void {
  const start = bucketStart(timestamp, SECONDS_PER_DAY);
  const id = dailySnapshotId(vault.id, start);
  let snapshot = VaultDailySnapshot.load(id);

  if (snapshot == null) {
    snapshot = new VaultDailySnapshot(id);
    initDailySnapshot(snapshot, vault, start, timestamp);
  }

  if (snapshot.lastTxHash.toHexString() != txHash.toHexString()) {
    snapshot.txCount = snapshot.txCount + 1;
    snapshot.lastTxHash = txHash;
  }
  snapshot.eventCount = snapshot.eventCount + 1;

  let hasDeposit = false;
  if (!seniorDepositAssets.equals(ZERO)) {
    hasDeposit = true;
  }
  if (!juniorDepositAssets.equals(ZERO)) {
    hasDeposit = true;
  }
  if (hasDeposit) {
    snapshot.depositCount = snapshot.depositCount + 1;
  }

  let hasRedeem = false;
  if (!seniorRedeemAssets.equals(ZERO)) {
    hasRedeem = true;
  }
  if (!juniorRedeemAssets.equals(ZERO)) {
    hasRedeem = true;
  }
  if (hasRedeem) {
    snapshot.redeemCount = snapshot.redeemCount + 1;
  }

  if (isAccrual) {
    snapshot.accrualCount = snapshot.accrualCount + 1;
  }

  snapshot.seniorDepositAssets = snapshot.seniorDepositAssets.plus(seniorDepositAssets);
  snapshot.juniorDepositAssets = snapshot.juniorDepositAssets.plus(juniorDepositAssets);
  snapshot.seniorRedeemAssets = snapshot.seniorRedeemAssets.plus(seniorRedeemAssets);
  snapshot.juniorRedeemAssets = snapshot.juniorRedeemAssets.plus(juniorRedeemAssets);

  snapshot.highTvl = maxBigInt(snapshot.highTvl, vault.tvl);
  snapshot.lowTvl = minBigInt(snapshot.lowTvl, vault.tvl);
  snapshot.closeTvl = vault.tvl;
  snapshot.highSeniorPrice = maxBigInt(snapshot.highSeniorPrice, vault.seniorPrice);
  snapshot.lowSeniorPrice = minBigInt(snapshot.lowSeniorPrice, vault.seniorPrice);
  snapshot.closeSeniorPrice = vault.seniorPrice;
  snapshot.highJuniorPrice = maxBigInt(snapshot.highJuniorPrice, vault.juniorPrice);
  snapshot.lowJuniorPrice = minBigInt(snapshot.lowJuniorPrice, vault.juniorPrice);
  snapshot.closeJuniorPrice = vault.juniorPrice;

  snapshot.tvl = snapshot.closeTvl;
  snapshot.seniorDebt = vault.seniorDebt;
  snapshot.seniorSupply = vault.seniorSupply;
  snapshot.juniorSupply = vault.juniorSupply;
  snapshot.seniorPrice = snapshot.closeSeniorPrice;
  snapshot.juniorPrice = snapshot.closeJuniorPrice;
  snapshot.underwater = vault.tvl.lt(vault.seniorDebt);
  snapshot.updatedAt = timestamp;
  snapshot.save();
}

function updateRollups(
  vault: Vault,
  timestamp: BigInt,
  txHash: Bytes,
  seniorDepositAssets: BigInt,
  juniorDepositAssets: BigInt,
  seniorRedeemAssets: BigInt,
  juniorRedeemAssets: BigInt,
  isAccrual: boolean
): void {
  updateHourlySnapshot(
    vault,
    timestamp,
    txHash,
    seniorDepositAssets,
    juniorDepositAssets,
    seniorRedeemAssets,
    juniorRedeemAssets,
    isAccrual
  );

  updateDailySnapshot(
    vault,
    timestamp,
    txHash,
    seniorDepositAssets,
    juniorDepositAssets,
    seniorRedeemAssets,
    juniorRedeemAssets,
    isAccrual
  );
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

  vault.tvl = vault.tvl.plus(event.params.assets);
  vault.seniorDebt = vault.seniorDebt.plus(event.params.assets);
  vault.seniorSupply = vault.seniorSupply.plus(event.params.shares);
  refreshOnchainState(vault, event.address);
  refreshDerivedPrices(vault);

  vault.lastSnapshot = writeSnapshot(
    vault,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash,
    event.logIndex,
    "SENIOR_DEPOSIT"
  );

  updateRollups(vault, event.block.timestamp, event.transaction.hash, event.params.assets, ZERO, ZERO, ZERO, false);
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

  vault.tvl = vault.tvl.plus(event.params.assets);
  vault.juniorSupply = vault.juniorSupply.plus(event.params.shares);
  refreshOnchainState(vault, event.address);
  refreshDerivedPrices(vault);

  vault.lastSnapshot = writeSnapshot(
    vault,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash,
    event.logIndex,
    "JUNIOR_DEPOSIT"
  );

  updateRollups(vault, event.block.timestamp, event.transaction.hash, ZERO, event.params.assets, ZERO, ZERO, false);
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

  vault.tvl = saturatingSub(vault.tvl, event.params.assets);
  vault.seniorDebt = saturatingSub(vault.seniorDebt, event.params.assets);
  vault.seniorSupply = saturatingSub(vault.seniorSupply, event.params.shares);
  refreshOnchainState(vault, event.address);
  refreshDerivedPrices(vault);

  vault.lastSnapshot = writeSnapshot(
    vault,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash,
    event.logIndex,
    "SENIOR_REDEEM"
  );

  updateRollups(vault, event.block.timestamp, event.transaction.hash, ZERO, ZERO, event.params.assets, ZERO, false);
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

  vault.tvl = saturatingSub(vault.tvl, event.params.assets);
  vault.juniorSupply = saturatingSub(vault.juniorSupply, event.params.shares);
  refreshOnchainState(vault, event.address);
  refreshDerivedPrices(vault);

  vault.lastSnapshot = writeSnapshot(
    vault,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash,
    event.logIndex,
    "JUNIOR_REDEEM"
  );

  updateRollups(vault, event.block.timestamp, event.transaction.hash, ZERO, ZERO, ZERO, event.params.assets, false);
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
  refreshDerivedPrices(vault);

  vault.lastSnapshot = writeSnapshot(
    vault,
    event.block.number,
    event.block.timestamp,
    event.transaction.hash,
    event.logIndex,
    "ACCRUE"
  );

  updateRollups(vault, event.block.timestamp, event.transaction.hash, ZERO, ZERO, ZERO, ZERO, true);
  vault.updatedAt = event.block.timestamp;
  vault.save();
}
