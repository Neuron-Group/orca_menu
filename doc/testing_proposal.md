# Orca Menu Testing Proposal

This document proposes a test strategy for `orca_menu` based on the current code layout and the kinds of interaction the plugin implements.

## Current Logic Map

The interaction-heavy parts of the plugin are concentrated in a small set of modules:

- `lua/orca_menu/init.lua`
  - wires setup, autocommands, lualine registration, backend selection, and mouse install
- `lua/orca_menu/input.lua`
  - installs keyboard and mouse mappings
  - dispatches top-level keys and item-level keys
- `lua/orca_menu/popup.lua`
  - owns popup state, menu stack, selection, submenu open/close, hit-testing, and wheel scrolling
- `lua/orca_menu/layout.lua`
  - computes label positions, popup width/height, top-bar hit detection, and popup anchor placement
- `lua/orca_menu/hydra_mode.lua`
  - adds Hydra lifecycle behavior and action deferral through `state.pending_action`
- `lua/orca_menu/actions.lua`
  - executes `command`, `keys`, `action`, and `lua` items
- `lua/orca_menu/config.lua`
  - normalizes menus, accelerators, explicit keys, and LSP overrides

From a testing perspective, the highest-risk logic is not the static config handling. It is the interaction between:

- menu-stack state in `popup.lua`
- dynamic key installation in `input.lua`
- label hit-testing in `layout.lua`
- backend-specific exit behavior in `hydra_mode.lua`
- mouse behavior that depends on screen row/column coordinates

## Recommendation

Use a three-layer test strategy:

- pure Lua unit tests for deterministic logic
- headless integration tests for keyboard flows and popup state changes
- UI-oriented tests for mouse and geometry-sensitive behavior

This is better than relying on only one style of test because the plugin mixes:

- pure data normalization
- Neovim keymap side effects
- floating-window state
- redraw-dependent hit-testing
- backend-specific lifecycle behavior

## Proposed Harness

The repo currently has no test framework. The least disruptive proposal is to add a self-hosted Neovim test harness instead of introducing a hard runtime dependency on `plenary.nvim` or another plugin.

Suggested layout:

- `tests/minimal_init.lua`
  - adds the repo to `runtimepath`
  - loads a tiny fake `lualine` module for deterministic tests
- `tests/helpers.lua`
  - helper assertions
  - helpers to call `nvim_input()`, `nvim_input_mouse()`, and flush scheduled callbacks
  - helpers to inspect `require("orca_menu.state")`
- `tests/unit/*.lua`
  - `config` and `layout` logic
- `tests/integration/*.lua`
  - keyboard navigation, submenu transitions, action execution, close behavior
- `tests/ui/*.lua`
  - mouse hit-testing, wheel scrolling, visible-label anchoring, border indicator behavior
- `scripts/test.sh`
  - runs `nvim --headless -u tests/minimal_init.lua ...`

If you later want a more standard runner, `mini.test` is the lightest add-on. If you want the most familiar plugin-testing ecosystem, `plenary.nvim` is the common alternative. For this repo, a self-hosted harness is simpler and keeps packaging clean.

## Test Layers

### 1. Unit Tests

These should avoid real keymaps and windows where possible.

Primary targets:

- `lua/orca_menu/config.lua`
  - `parse_label()` behavior through `normalize()`
  - explicit `key` preservation
  - reserved-key filtering
  - submenu normalization
  - separator normalization
  - LSP override merge semantics
  - `menus` replacement semantics inside overrides
- `lua/orca_menu/layout.lua`
  - key-hint display formatting
  - truncation behavior
  - right-hint width computation
  - submenu arrow width logic
  - top-bar hint formatting string and function behavior
- `lua/orca_menu/actions.lua`
  - dispatch precedence between `action`, `lua`, `command`, and `keys`

Unit tests should not try to prove that floating windows render correctly. They should prove that deterministic input-to-output logic stays stable.

### 2. Headless Integration Tests

These should run in Neovim headless mode and exercise real plugin state.

Recommended setup:

- use a Hydra stub for most automated tests
- use `require("orca_menu").setup(...)`
- inspect `require("orca_menu.state")`
- trigger behavior through public commands or real key input

Best candidates:

- `:OrcaMenu` toggles menu mode on and off
- open first-level popup with `open_menu()` or configured open key
- `h` and `l` move between visible top menus
- `j` and `k` skip separators and update selected row
- `<CR>` opens submenu or runs action
- `<Esc>` and `<BS>` pop one submenu level or close everything at the root
- custom item `key` activates matching item
- label accelerator fallback activates menu or item when explicit `key` is absent
- action execution closes menus before command or callback runs
- resize autocommands close popups and exit menu mode
- LSP refresh path closes popups and rebuilds config safely

These tests should be the main regression suite because they cover the real interaction model without depending too much on terminal UI details.

### 3. UI and Mouse Tests

Mouse behavior is the most fragile part of the plugin because it depends on screen coordinates, visible labels, popup borders, and hover target calculations.

Use two styles here:

- direct API-driven tests using `nvim_input_mouse()` when possible
- deterministic white-box tests that temporarily stub `vim.fn.getmousepos()` for edge cases

Primary targets:

- top-bar left click opens the clicked menu
- clicking the same top-bar label while open closes the popup tree
- clicking a different top-bar label switches menus
- clicking outside all popup frames closes all popups
- clicking an action item runs it
- clicking a submenu item opens only that child level
- wheel scrolling over a popup advances selection by visible page size minus one
- wheel scrolling outside a popup returns `false` and lets fallback behavior happen
- child submenu hit-testing works on the content region and frame region
- top-bar hit-testing respects only visible labels

For border and redraw-sensitive behavior, also assert:

- scroll indicators appear when rows are hidden above or below
- submenu opens on the expected side, or flips left when needed
- selected row remains visible after repeated scroll or keyboard moves

## Hydra Coverage

The plugin now uses Hydra as its only menu backend.

Most behavior should be tested with a lightweight Hydra stub for deterministic automation. Add a smaller Hydra-focused suite that verifies backend-specific contracts against terminal input and activation flow:

- entering through the Hydra body key opens menu mode
- closing through `q` exits Hydra and clears menu state
- selecting an action stores `state.pending_action`, exits Hydra, then executes the action
- `Esc` in a child submenu goes back one level instead of closing Hydra immediately
- mouse-opened menus still allow keyboard continuation under Hydra
- real PTY input leaves insert, visual, visual-line, and visual-block mode before Hydra activation

This keeps the Hydra suite focused and avoids duplicating the entire keyboard matrix.

## Priority Test Matrix

If implementation time is limited, build the suite in this order.

### Phase 1: High Value

- config normalization and LSP override tests
- open or close behavior for `:OrcaMenu`
- keyboard navigation across top menus and rows
- submenu open, back, and root close behavior
- action execution closes popups before running action

### Phase 2: Interaction Regressions

- dynamic top-menu key activation
- dynamic item-key activation
- accelerator fallback behavior
- selection skipping separators
- resize closes state cleanly

### Phase 3: Mouse and Geometry

- top-bar click open or close
- popup item click behavior
- wheel scrolling behavior
- label hit-testing with visible and hidden labels
- submenu left-flip behavior near screen edge

### Phase 4: Hydra-Specific

- pending-action lifecycle
- Hydra enter and exit state cleanup
- back behavior at nested and root levels
- PTY-backed open-key coverage for terminal byte input

## Concrete Test Cases

These are the first cases worth implementing.

1. `config.normalize` strips `&` and keeps accelerator index.
2. explicit item `key` is removed when it conflicts with reserved navigation keys.
3. `config.resolve` fully replaces `menus` inside an LSP override.
4. `:OrcaMenu` sets `state.menu_mode = true` and creates one popup stack level.
5. `j` moves selection past separator rows.
6. `<CR>` on a submenu pushes a second stack level.
7. `<Esc>` at submenu depth 2 removes only the child level.
8. `<Esc>` at depth 1 closes all popups and clears menu mode.
9. item custom `key` activates the correct visible item.
10. top-menu custom `key` opens the correct visible menu.
11. clicking outside all popup levels closes everything.
12. wheel scroll changes selection by `visible_height - 1` when possible.
13. resize autocmd closes all popups.
14. Hydra action execution defers until Hydra exit completes.

## Suggested Assertions

Prefer state assertions over screenshot-like assertions for most tests.

Useful checks:

- `state.menu_mode`
- `state.active_top`
- `#state.menu_stack`
- `state.menu_stack[level].selected`
- `state.menu_stack[level].scroll_top`
- presence or absence of `state.windows[level]`
- side effects from action callbacks or commands

Reserve rendered-text assertions for a smaller number of layout tests, such as:

- scroll indicator glyph presence
- right-side key hint placement
- top-bar hint formatting

## Notes on Mouse Simulation

True mouse testing in headless Neovim can be awkward because the plugin reads `vim.fn.getmousepos()` and also relies on layout derived from lualine-rendered labels.

Because of that, the most reliable approach is:

- keep layout deterministic with a fake `lualine` module in tests
- test pure hit-mapping with controlled screen geometry
- use `nvim_input_mouse()` for end-to-end coverage where available
- stub `vim.fn.getmousepos()` only for cases that are hard to trigger consistently in headless mode

This gives realistic coverage without making the suite flaky.

## Final Proposal

Adopt a self-hosted Neovim test harness with:

- unit tests for `config`, `layout`, and `actions`
- integration tests for keyboard and popup-stack behavior
- a smaller UI suite for mouse and geometry-sensitive paths
- a narrow Hydra-specific suite for deferred action execution and exit lifecycle
- a PTY-backed terminal suite for real open-key entry across editor modes

That strategy fits the current repo structure, keeps dependencies low, and directly targets the code paths most likely to regress.
