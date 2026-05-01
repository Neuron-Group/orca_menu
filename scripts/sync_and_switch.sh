#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HM_DIR="${HM_DIR:-/home/neuron/.config/home-manager}"

cd "$ROOT_DIR"

./scripts/sync_hm_mirror.sh copy

if [[ "${1:-}" == "--no-switch" ]]; then
  echo "Skipped home-manager switch"
  exit 0
fi

home-manager switch --impure --flake "$HM_DIR#neuron"
