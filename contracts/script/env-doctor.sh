#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-infra}"
ENV_FILE=".env"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

lookup_in_env_file() {
  local key="$1"
  [ -f "$ENV_FILE" ] || return 0

  local line
  line="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" | tail -n 1 || true)"
  [ -n "$line" ] || return 0

  local value="${line#*=}"
  trim "$value"
}

get_value() {
  local key="$1"
  local from_shell="${!key:-}"
  if [ -n "$from_shell" ]; then
    printf '%s' "$from_shell"
    return 0
  fi
  lookup_in_env_file "$key"
}

require_non_empty() {
  local key="$1"
  local value
  value="$(get_value "$key")"
  if [ -z "$value" ]; then
    echo "[env] Missing ${key}. Fill contracts/.env (or export ${key})." >&2
    exit 1
  fi
}

validate_rpc_url() {
  local rpc
  rpc="$(get_value "PHAROS_ATLANTIC_RPC_URL")"
  if [[ ! "$rpc" =~ ^https?:// ]]; then
    echo "[env] PHAROS_ATLANTIC_RPC_URL must start with http:// or https://." >&2
    exit 1
  fi

  if command -v cast >/dev/null 2>&1; then
    if ! cast chain-id --rpc-url "$rpc" >/dev/null 2>&1; then
      echo "[env] RPC check failed. Verify PHAROS_ATLANTIC_RPC_URL is reachable." >&2
      exit 1
    fi
  fi
}

case "$MODE" in
  infra)
    require_non_empty "PHAROS_ATLANTIC_RPC_URL"
    require_non_empty "PRIVATE_KEY"
    validate_rpc_url
    echo "[env] OK for deploy:infra"
    ;;
  vault)
    require_non_empty "PHAROS_ATLANTIC_RPC_URL"
    require_non_empty "PRIVATE_KEY"
    require_non_empty "TRANCHE_FACTORY"
    require_non_empty "ASSET"
    validate_rpc_url
    echo "[env] OK for deploy:vault"
    ;;
  keeper)
    require_non_empty "PHAROS_ATLANTIC_RPC_URL"
    require_non_empty "PRIVATE_KEY"
    require_non_empty "VAULT"
    require_non_empty "ACCOUNTANT"
    require_non_empty "ASSET"
    validate_rpc_url
    echo "[env] OK for keeper:update-rate"
    ;;
  *)
    echo "Usage: ./script/env-doctor.sh [infra|vault|keeper]" >&2
    exit 1
    ;;
esac
