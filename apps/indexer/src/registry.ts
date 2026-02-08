import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";

import {
  FactoryUpdated,
  TrancheRegistry as TrancheRegistryContract,
  TrancheVaultCreated,
} from "../generated/TrancheRegistry/TrancheRegistry";
import { RegistryConfig, Vault } from "../generated/schema";
import { TrancheController as TrancheControllerTemplate } from "../generated/templates";

const ZERO = BigInt.fromI32(0);
const ZERO_ADDRESS = Address.fromString("0x0000000000000000000000000000000000000000");

function loadOrCreateRegistryConfig(
  registry: Address,
  timestamp: BigInt,
  blockNumber: BigInt,
  txHash: Bytes
): RegistryConfig {
  const id = registry.toHexString();
  let config = RegistryConfig.load(id);
  if (config != null) {
    return config;
  }

  config = new RegistryConfig(id);
  config.registry = registry;
  config.factory = ZERO_ADDRESS;
  config.vaultCount = 0;
  config.createdAt = timestamp;
  config.createdAtBlock = blockNumber;
  config.createdTx = txHash;
  config.updatedAt = timestamp;
  config.updatedAtBlock = blockNumber;
  config.updatedTx = txHash;
  return config;
}

function refreshFactory(config: RegistryConfig, registry: Address): void {
  const contract = TrancheRegistryContract.bind(registry);
  const factoryResult = contract.try_factory();
  if (!factoryResult.reverted) {
    config.factory = factoryResult.value;
  }
}

export function handleTrancheVaultCreated(event: TrancheVaultCreated): void {
  const id = event.params.controller.toHexString();
  let vault = Vault.load(id);
  const isNew = vault == null;
  let config = loadOrCreateRegistryConfig(
    event.address,
    event.block.timestamp,
    event.block.number,
    event.transaction.hash
  );

  if (vault == null) {
    vault = new Vault(id);
  }

  vault.vaultId = event.params.paramsHash;
  vault.controller = event.params.controller;
  vault.seniorToken = event.params.seniorToken;
  vault.juniorToken = event.params.juniorToken;
  vault.vault = event.params.vault;
  vault.teller = event.params.teller;
  vault.accountant = event.params.accountant;
  vault.manager = event.params.manager;
  vault.asset = event.params.asset;
  vault.paramsHash = event.params.paramsHash;
  vault.rateModel = ZERO_ADDRESS;
  vault.seniorRatePerSecondWad = ZERO;
  vault.maxSeniorRatioBps = ZERO;
  vault.maxRateAge = ZERO;
  vault.paused = false;

  if (isNew) {
    vault.createdAt = event.block.timestamp;
    vault.createdAtBlock = event.block.number;
    vault.createdTx = event.transaction.hash;
    vault.tvl = ZERO;
    vault.seniorPrice = ZERO;
    vault.juniorPrice = ZERO;
    vault.seniorDebt = ZERO;
    vault.seniorSupply = ZERO;
    vault.juniorSupply = ZERO;
    vault.seniorApyBps = null;
    vault.juniorApyBps = null;
  }

  vault.updatedAt = event.block.timestamp;
  vault.save();

  if (isNew) {
    config.vaultCount = config.vaultCount + 1;
  }
  refreshFactory(config, event.address);
  config.updatedAt = event.block.timestamp;
  config.updatedAtBlock = event.block.number;
  config.updatedTx = event.transaction.hash;
  config.save();

  TrancheControllerTemplate.create(event.params.controller);
}

export function handleFactoryUpdated(event: FactoryUpdated): void {
  let config = loadOrCreateRegistryConfig(
    event.address,
    event.block.timestamp,
    event.block.number,
    event.transaction.hash
  );
  config.factory = event.params.newFactory;
  config.updatedAt = event.block.timestamp;
  config.updatedAtBlock = event.block.number;
  config.updatedTx = event.transaction.hash;
  config.save();
}
