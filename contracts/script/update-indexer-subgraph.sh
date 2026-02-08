#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  contracts/script/update-indexer-subgraph.sh --registry <address> --start-block <number> [--file <path>]

Options:
  --registry     TrancheRegistry address (0x-prefixed, 40 hex chars)
  --start-block  Start block for the registry datasource
  --file         Optional subgraph manifest path
                 Default: <repo>/apps/indexer/subgraph.yaml

Example:
  contracts/script/update-indexer-subgraph.sh \
    --registry 0x1234567890abcdef1234567890abcdef12345678 \
    --start-block 12950000
EOF
}

registry=""
start_block=""
manifest_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry)
      registry="${2:-}"
      shift 2
      ;;
    --start-block)
      start_block="${2:-}"
      shift 2
      ;;
    --file)
      manifest_path="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$registry" || -z "$start_block" ]]; then
  echo "Both --registry and --start-block are required." >&2
  usage
  exit 1
fi

if [[ ! "$registry" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "Invalid --registry address: $registry" >&2
  exit 1
fi

if [[ ! "$start_block" =~ ^[0-9]+$ ]]; then
  echo "Invalid --start-block: $start_block" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

if [[ -z "$manifest_path" ]]; then
  manifest_path="${repo_root}/apps/indexer/subgraph.yaml"
fi

if [[ ! -f "$manifest_path" ]]; then
  echo "subgraph manifest not found: $manifest_path" >&2
  exit 1
fi

tmp_file="$(mktemp)"

awk -v registry="$registry" -v startBlock="$start_block" '
  BEGIN {
    inRegistry = 0;
    addressUpdated = 0;
    startBlockUpdated = 0;
  }
  {
    if ($0 ~ /^[[:space:]]*name:[[:space:]]*TrancheRegistry[[:space:]]*$/) {
      inRegistry = 1;
    }

    if (inRegistry && $0 ~ /^[[:space:]]*address:[[:space:]]*"/) {
      sub(/"0x[0-9a-fA-F]{40}"/, "\"" registry "\"");
      addressUpdated = 1;
    }

    if (inRegistry && $0 ~ /^[[:space:]]*startBlock:[[:space:]]*[0-9]+[[:space:]]*$/) {
      sub(/startBlock:[[:space:]]*[0-9]+/, "startBlock: " startBlock);
      startBlockUpdated = 1;
      inRegistry = 0;
    }

    print;
  }
  END {
    if (!addressUpdated || !startBlockUpdated) {
      exit 1;
    }
  }
' "$manifest_path" > "$tmp_file" || {
  rm -f "$tmp_file"
  echo "Failed to update TrancheRegistry address/startBlock in $manifest_path" >&2
  exit 1
}

mv "$tmp_file" "$manifest_path"

echo "Updated $manifest_path"
echo "  TrancheRegistry address: $registry"
echo "  startBlock: $start_block"
