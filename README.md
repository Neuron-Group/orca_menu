# orca_menu

Neovim top menu plugin with floating popups, mouse support, submenu hotkeys, and Home Manager sync helpers.

## Repo Workflow

This project is edited in:

- repo source: `/home/neuron/Projects/orca_menu`
- Home Manager mirror: `/home/neuron/.config/home-manager/pkgs/orca-menu`

Use the helper scripts so you do not need to edit both places manually.

## Helper Scripts

- `./scripts/sync_hm_mirror.sh status`
  - show whether tracked files are the same or different

- `./scripts/sync_hm_mirror.sh diff`
  - show diffs between this repo and the Home Manager mirror

- `./scripts/sync_hm_mirror.sh copy`
  - copy tracked files from this repo into the Home Manager mirror

- `./scripts/sync_and_switch.sh`
  - sync files into the Home Manager mirror, then run:
  - `home-manager switch --flake /home/neuron/.config/home-manager#neuron`

- `./scripts/sync_and_switch.sh --no-switch`
  - sync only

## Current Home Manager Hook

The Home Manager NVF config currently prepends this repo to Neovim runtimepath:

- `vim.opt.runtimepath:prepend('/home/neuron/Projects/orca_menu')`

That means your live repo version is preferred while the plugin is still under development.

## Menu Key Options

### Global menu-mode keys

Configured under `keys`:

- `open`
  - enter menu mode, currently `<M-m>`
- `next` / `prev`
  - switch visible top bar menus
- `down` / `up`
  - move inside current popup
- `select`
  - activate selected item
- `back`
  - close child popup or leave menu mode
- `close`
  - close the menu

These keys are active only while menu mode is open.

### Top bar custom keys

Each top menu can define:

```lua
{ label = '&File', key = 'f', items = { ... } }
```

Behavior:

- custom `key` opens that top bar menu while menu mode is active
- if `key` is absent, `&` accelerator still works as fallback
- hidden/truncated lualine menu labels are not triggerable

Bar labels render like:

- `File(f)`
- `Tools(t)`

### Popup item custom keys

Each popup item can define:

```lua
{ label = '&Save', key = 's', command = 'write' }
{ label = '&Terminal', key = 't', items = { ... } }
```

Behavior while popup is open:

- explicit `key` activates the visible item
- if `key` is absent, `&` accelerator works as fallback
- right-side key hints are rendered in the popup

Examples:

- `1`
- `Tab`
- `Space`
- `Ctrl+x`

Submenu rows render a separate arrow column on the far right.

## Layout Notes

- popup rows are forced to one line
- long labels are truncated with `...`
- key hints are right-aligned in a dedicated column
- submenu arrows are rendered in a separate rightmost column
- top popup anchor uses visible rendered lualine labels, so hidden/truncated labels should not be opened

## Main Files

- `lua/orca_menu/input.lua`
  - menu-mode keymaps and item/top key activation bindings

- `lua/orca_menu/popup.lua`
  - popup drawing, mouse handling, submenu open/close logic

- `lua/orca_menu/layout.lua`
  - popup widths, row formatting, statusline label position lookup

- `lua/orca_menu/lualine.lua`
  - top bar label rendering such as `File(f)`

- `../../.config/home-manager/programs/nvf/default.nix`
  - active Home Manager config that wires this plugin into Neovim
