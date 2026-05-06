# TLA+ Formalization

This repo now includes an initial TLA+ model for the mouse interaction rules in Orca Menu:

- `doc/OrcaMenuMouse.tla`
- `doc/OrcaMenuMouse.cfg`

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

The model is intentionally abstract. It does not try to represent:

- screen coordinates
- floating window borders
- lualine rendering
- keyboard-mode handoff
- Hydra lifecycle details

Those remain implementation- and integration-test concerns.

## Running TLC

If `tla2tools.jar` is available locally, one common command is:

```bash
java -cp tla2tools.jar tlc2.TLC doc/OrcaMenuMouse.tla -config doc/OrcaMenuMouse.cfg
```

Or open the spec in the TLA+ Toolbox and use `doc/OrcaMenuMouse.cfg` as the model configuration.

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

Use this model as a behavioral source of truth for mouse popup logic.

When UI behavior changes, update in this order:

1. TLA+ state transition or invariant
2. Lua implementation in `lua/orca_menu/popup.lua`
3. integration tests in `tests/integration/*.lua`

That keeps the mathematical model, the runtime behavior, and the test suite aligned.

## Next Good Extensions

- add wheel-scrolling invariants
- model keyboard activation separately from mouse activation
- connect randomized test traces to abstract TLA+ event sequences
