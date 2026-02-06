#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  CONTRACT_ADDRESS=<address> CONTRACT_ID=<path:Contract> ./script/verify-contract.sh
  ./script/verify-contract.sh <address> <path:Contract>

Environment:
  CHAIN_ID            default: 688689
  VERIFY_VERIFIER     default: blockscout
  VERIFY_VERIFIER_URL default: https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract
  BLOCKSCAN_API_KEY   optional api key for scan verification
  CONSTRUCTOR_ARGS    optional abi-encoded constructor args (hex string)
  VERIFY_WATCH        default: 1 (set 0 to disable --watch)

Examples:
  CONTRACT_ADDRESS=0xabc... \
  CONTRACT_ID=src/tranche/TrancheRegistry.sol:TrancheRegistry \
  ./script/verify-contract.sh

  ./script/verify-contract.sh \
  0xabc... \
  src/tranche/TrancheFactory.sol:TrancheFactory
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

address="${CONTRACT_ADDRESS:-${1:-}}"
contract_id="${CONTRACT_ID:-${2:-}}"
chain_id="${CHAIN_ID:-688689}"
verifier="${VERIFY_VERIFIER:-blockscout}"
verifier_url="${VERIFY_VERIFIER_URL:-https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract}"
watch="${VERIFY_WATCH:-1}"

if [[ -z "${address}" || -z "${contract_id}" ]]; then
  usage
  exit 1
fi

cmd=(
  forge verify-contract
  "${address}"
  "${contract_id}"
  --chain-id "${chain_id}"
  --verifier "${verifier}"
  --verifier-url "${verifier_url}"
)

if [[ -n "${BLOCKSCAN_API_KEY:-}" ]]; then
  cmd+=(--etherscan-api-key "${BLOCKSCAN_API_KEY}")
fi

if [[ -n "${CONSTRUCTOR_ARGS:-}" ]]; then
  cmd+=(--constructor-args "${CONSTRUCTOR_ARGS}")
fi

if [[ "${watch}" == "1" ]]; then
  cmd+=(--watch)
fi

printf 'Running: %q ' "${cmd[@]}"
printf '\n'
"${cmd[@]}"
