#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

spec=${1:-doc/OrcaMenuMouse.tla}
cfg=${2:-doc/OrcaMenuMouse.cfg}
out_prefix=${3:-doc/OrcaMenuMouse}

if ! command -v tlc >/dev/null 2>&1; then
  echo "error: 'tlc' not found in PATH" >&2
  exit 1
fi

if [[ ! -f "$spec" ]]; then
  echo "error: spec not found: $spec" >&2
  exit 1
fi

if [[ ! -f "$cfg" ]]; then
  echo "error: config not found: $cfg" >&2
  exit 1
fi

dot_file="${out_prefix}.dot"
svg_file="${out_prefix}.svg"
compact_dot_file="${out_prefix}.compact.dot"
compact_svg_file="${out_prefix}.compact.svg"
meta_dir=$(mktemp -d "${TMPDIR:-/tmp}/orca_menu_tlc_graph.XXXXXX")

cleanup() {
  rm -rf "$meta_dir"
}
trap cleanup EXIT

echo "==> TLC graph dump"
echo "spec: $spec"
echo "cfg:  $cfg"
echo "dot:  $dot_file"

tlc \
  -cleanup \
  -workers 1 \
  -metadir "$meta_dir" \
  -config "$cfg" \
  -dump dot,actionlabels "$dot_file" \
  "$spec"

if command -v dot >/dev/null 2>&1; then
  echo "==> Graphviz render"
  dot -Tsvg "$dot_file" -o "$svg_file"
  echo "svg:  $svg_file"
else
  echo "note: graphviz 'dot' not found; skipped SVG render" >&2
fi

if command -v python3 >/dev/null 2>&1; then
  echo "==> Compact graph projection"
  python3 scripts/compact_tla_dot.py "$dot_file" "$compact_dot_file"
  echo "compact dot: $compact_dot_file"

  if command -v dot >/dev/null 2>&1; then
    dot -Tsvg "$compact_dot_file" -o "$compact_svg_file"
    echo "compact svg: $compact_svg_file"
  fi
else
  echo "note: python3 not found; skipped compact graph generation" >&2
fi
