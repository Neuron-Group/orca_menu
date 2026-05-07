# TLA+ Formalization

This repo now includes an initial TLA+ model for the mouse interaction rules in Orca Menu:

- `doc/OrcaMenuMouse.tla`
- `doc/OrcaMenuMouse.cfg`

It also includes a focused mode-handoff model:

- `doc/OrcaMenuMode.tla`
- `doc/OrcaMenuMode.cfg`

## Scope

The current model focuses on the popup-tree interaction rules that are easiest to regress:

- top-bar click switching and same-item close behavior
- top-bar hover switching while a popup tree is already open
- keyboard activation of the currently selected row
- deepest popup hover changes selection
- ancestor hover is inert while descendants are open
- disabled top-bar targets are inert
- disabled popup items are inert
- deepest action click executes and closes the tree
- deepest submenu click opens a child popup
- keyboard activation on an action executes and closes the tree
- keyboard activation on a submenu opens its child popup
- clicking the same ancestor submenu row closes that child subtree
- clicking a different ancestor submenu row replaces the open child subtree
- clicking an ancestor action row closes descendants and focuses the row without executing
- outside click closes the whole tree
- back closes one submenu level or the whole tree at the root

The mode-handoff model focuses on editor-mode preservation and Orca entry/exit:

- open key always enters Orca and normalizes editor mode
- actionable top-bar click enters Orca and normalizes editor mode
- disabled or missed top-bar click is inert and must not force editor-mode exit
- visual selection context is preserved only while Orca is actually active
- Orca exit clears preserved visual context

The model is intentionally abstract. It does not try to represent:

- screen coordinates
- floating window borders
- lualine rendering
- Hydra lifecycle details

The mode-handoff model is intentionally abstract too. It does not try to represent:

- exact visual marks and buffer contents
- popup-tree structure
- asynchronous scheduling between keymaps and Hydra
- lualine hitbox geometry

Those remain implementation- and integration-test concerns.

## Running TLC

If `tla2tools.jar` is available locally, one common command is:

```bash
java -cp tla2tools.jar tlc2.TLC doc/OrcaMenuMouse.tla -config doc/OrcaMenuMouse.cfg
java -cp tla2tools.jar tlc2.TLC doc/OrcaMenuMode.tla -config doc/OrcaMenuMode.cfg
```

Or open either spec in the TLA+ Toolbox and use its matching `.cfg` file.

To generate a state graph directly from TLC and render it with Graphviz:

```bash
bash scripts/gen_tla_graph.sh
```

That produces:

- `doc/OrcaMenuMouse.dot`
- `doc/OrcaMenuMouse.svg`
- `doc/OrcaMenuMouse.compact.dot`
- `doc/OrcaMenuMouse.compact.svg`

The `compact` graph is usually the more readable one. It projects away TLC
bookkeeping fields such as `prevStack`, `lastEvent`, and action-result detail,
and instead groups states by high-level UI shape:

- closed vs open
- active top menu
- current visible stack path and selections

You can also pass custom paths:

```bash
bash scripts/gen_tla_graph.sh doc/OrcaMenuMouse.tla doc/OrcaMenuMouse.cfg out/orca_menu_mouse
```

That writes full and compact DOT files and, if `dot` is installed, matching SVG files.

## Intended Use

Use these models as behavioral sources of truth for popup logic and mode handoff.

The mode-handoff model is now backed by explicit regressions for inert top-bar
clicks from visual mode:

- `tests/integration/visual_disabled_top_click.lua`
- `tests/integration/visual_miss_top_click.lua`
- `tests/integration/visual_clipped_top_click.lua`

These cover the contract that disabled, missed, or clipped lualine clicks must
not force editor-mode exit or create Orca selection context.

When UI behavior changes, update in this order:

1. TLA+ state transition or invariant
2. Lua implementation in `lua/orca_menu/input.lua`, `lua/orca_menu/mode.lua`, or `lua/orca_menu/popup.lua`
3. integration tests in `tests/integration/*.lua`

That keeps the mathematical model, the runtime behavior, and the test suite aligned.

## Next Good Extensions

- add wheel-scrolling invariants
- model keyboard activation separately from mouse activation
- connect randomized test traces to abstract TLA+ event sequences
- compose popup-tree and mode-handoff models into one larger state machine
