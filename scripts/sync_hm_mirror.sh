#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HM_MIRROR_DIR="${HM_MIRROR_DIR:-/home/neuron/.config/home-manager/pkgs/orca-menu}"

FILES=(
  "doc/orca_menu.txt"
  "plugin/orca_menu.lua"
  "lua/orca_menu/actions.lua"
  "lua/orca_menu/config.lua"
  "lua/orca_menu/hydra_mode.lua"
  "lua/orca_menu/init.lua"
  "lua/orca_menu/input.lua"
  "lua/orca_menu/layout.lua"
  "lua/orca_menu/lualine.lua"
  "lua/orca_menu/popup.lua"
  "lua/orca_menu/state.lua"
)

usage() {
  cat <<'EOF'
Usage: sync_hm_mirror.sh [diff|copy|status]

Commands:
  diff    Show diffs between this repo and the Home Manager mirror.
  copy    Copy tracked files from this repo into the Home Manager mirror.
  status  Print whether tracked files differ.

Env:
  HM_MIRROR_DIR   Override the Home Manager mirror path.
EOF
}

ensure_paths() {
  if [[ ! -d "$ROOT_DIR" ]]; then
    echo "Project root not found: $ROOT_DIR" >&2
    exit 1
  fi

  if [[ ! -d "$HM_MIRROR_DIR" ]]; then
    echo "Home Manager mirror not found: $HM_MIRROR_DIR" >&2
    exit 1
  fi
}

diff_one() {
  local rel="$1"
  local src="$ROOT_DIR/$rel"
  local dst="$HM_MIRROR_DIR/$rel"

  if [[ ! -e "$src" ]]; then
    echo "Missing source file: $src" >&2
    return 1
  fi

  if [[ ! -e "$dst" ]]; then
    echo "Only in source: $rel"
    return 0
  fi

  diff -u "$dst" "$src" || true
}

copy_one() {
  local rel="$1"
  local src="$ROOT_DIR/$rel"
  local dst="$HM_MIRROR_DIR/$rel"

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "Copied $rel"
}

status_one() {
  local rel="$1"
  local src="$ROOT_DIR/$rel"
  local dst="$HM_MIRROR_DIR/$rel"

  if [[ ! -e "$dst" ]]; then
    echo "missing  $rel"
    return
  fi

  if cmp -s "$src" "$dst"; then
    echo "same     $rel"
  else
    echo "differs  $rel"
  fi
}

main() {
  local cmd="${1:-status}"
  ensure_paths

  case "$cmd" in
    diff)
      for rel in "${FILES[@]}"; do
        diff_one "$rel"
      done
      ;;
    copy)
      for rel in "${FILES[@]}"; do
        copy_one "$rel"
      done
      ;;
    status)
      for rel in "${FILES[@]}"; do
        status_one "$rel"
      done
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
