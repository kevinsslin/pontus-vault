#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
contracts_dir="$(cd -- "${script_dir}/.." && pwd)"
env_file="${contracts_dir}/.env"
anvil_log_file="${contracts_dir}/.anvil-fork.log"

read_env_value() {
  local key="$1"
  local file="$2"
  [[ -f "${file}" ]] || return 0
  awk -F= -v key="${key}" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "${file}"
}

rpc_url="${PHAROS_ATLANTIC_RPC_URL:-}"
if [[ -z "${rpc_url}" ]]; then
  rpc_url="$(read_env_value "PHAROS_ATLANTIC_RPC_URL" "${env_file}")"
fi

if [[ -z "${rpc_url}" ]]; then
  echo "Missing PHAROS_ATLANTIC_RPC_URL."
  echo "Set it in environment, or in contracts/.env."
  exit 1
fi

fork_block_number="12950000"

anvil_port="${PHAROS_ATLANTIC_FORK_ANVIL_PORT:-8547}"
anvil_host="${PHAROS_ATLANTIC_FORK_ANVIL_HOST:-127.0.0.1}"
local_fork_url="http://${anvil_host}:${anvil_port}"

anvil --fork-url "${rpc_url}" --fork-block-number "${fork_block_number}" --port "${anvil_port}" \
  >"${anvil_log_file}" 2>&1 &
anvil_pid=$!

cleanup() {
  if kill -0 "${anvil_pid}" 2>/dev/null; then
    kill "${anvil_pid}" >/dev/null 2>&1 || true
    wait "${anvil_pid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 30); do
  if cast chain-id --rpc-url "${local_fork_url}" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "${ready}" -ne 1 ]]; then
  echo "Local anvil fork failed to boot."
  echo "Tail of ${anvil_log_file}:"
  tail -n 80 "${anvil_log_file}" || true
  exit 1
fi

echo "Running fork tests via local anvil snapshot"
echo "Upstream RPC: ${rpc_url}"
echo "Fork block: ${fork_block_number}"
echo "Local RPC: ${local_fork_url}"

cd "${contracts_dir}"
PHAROS_ATLANTIC_RPC_URL="${local_fork_url}" \
forge test --match-path "test/fork/*.t.sol" -vv "$@"
