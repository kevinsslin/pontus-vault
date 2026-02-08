import { Address, BigInt } from "@graphprotocol/graph-ts";

import { TrancheVaultCreated } from "../generated/TrancheRegistry/TrancheRegistry";
import { Vault } from "../generated/schema";
import { TrancheController as TrancheControllerTemplate } from "../generated/templates";

const ZERO = BigInt.fromI32(0);
const ZERO_ADDRESS = Address.fromString("0x0000000000000000000000000000000000000000");

export function handleTrancheVaultCreated(event: TrancheVaultCreated): void {
  const id = event.params.controller.toHexString();
  let vault = Vault.load(id);
  const isNew = vault == null;

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

  TrancheControllerTemplate.create(event.params.controller);
}
