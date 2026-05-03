#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

export HOME="${HOME:-$repo_root/.tmp-home}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$repo_root/.tmp-state}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$repo_root/.tmp-data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$repo_root/.tmp-cache}"

mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

cd "$repo_root"

run_suite() {
  local suite=$1
  echo "==> $suite"
  nvim --headless -u tests/minimal_init.lua -l "$suite"
}

run_suite tests/unit/config_layout.lua
run_suite tests/integration/menu_flow.lua
run_suite tests/integration/mouse_smoke.lua
run_suite tests/integration/topbar_blink.lua
run_suite tests/integration/mouse_strict.lua
run_suite tests/integration/mouse_toggle.lua
run_suite tests/integration/mouse_passthrough.lua
run_suite tests/integration/editor_interaction_strict.lua
run_suite tests/integration/visual_mode.lua
run_suite tests/integration/insert_mode.lua
run_suite tests/integration/function_key_open.lua
run_suite tests/integration/leader_open_key.lua
run_suite tests/integration/mode_shift.lua
run_suite tests/integration/lua_action.lua
echo "==> tests/terminal/run_open_hotkey_terminal.py"
python3 tests/terminal/run_open_hotkey_terminal.py
run_suite tests/integration/mixed_input.lua
run_suite tests/integration/mixed_fuzz.lua
run_suite tests/integration/randomized_stress.lua
run_suite tests/integration/randomized_repeat_bias.lua
run_suite tests/integration/repeat_activation.lua
run_suite tests/integration/scroll_and_border.lua
run_suite tests/integration/hydra_flow.lua

echo "All checks passed"
