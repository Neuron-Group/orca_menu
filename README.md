# orca_menu

`orca_menu` is a Neovim top menu plugin with floating popups, nested submenus,
keyboard navigation, mouse support, and lualine integration.

It is designed to provide a VSCode-style menu bar while staying fully
configurable in Lua.

## Features

- top menu bar rendered through `lualine`
- floating popup menus and nested submenus
- tall popup menus auto-scroll with selection
- `h/j/k/l`, arrows, `Enter`, `Esc`, and custom key navigation
- right-aligned popup key hints
- mouse support for menu bar and popup items
- mouse-wheel scrolling for open popup menus
- wheel scrolling moves by nearly a full visible page
- popup borders show `↑`/`↓` when more items are hidden above or below
- configurable menu labels, accelerators, commands, and Lua callbacks
- `enable_mouse = false` disables menu click and wheel bindings
- Nix flake packaging included in this repository

## Requirements

- Neovim `>= 0.9`
- `nvim-lualine/lualine.nvim`
- `anuvyklack/hydra.nvim` when using the default Hydra backend

## Installation

### `lazy.nvim`

```lua
{
  "your-name/orca_menu",
  dependencies = {
    "nvim-lualine/lualine.nvim",
    "anuvyklack/hydra.nvim",
  },
  config = function()
    require("orca_menu").setup({
      menus = {
        {
          label = "&File",
          key = "f",
          items = {
            { label = "&Write", key = "w", command = "write" },
            { label = "Write &Quit", key = "q", command = "wq" },
          },
        },
        {
          label = "&Tools",
          key = "t",
          items = {
            {
              label = "&Terminal",
              key = "t",
              items = {
                { label = "&Toggle", key = "g", command = "ToggleTerm" },
              },
            },
          },
        },
      },
    })
  end,
}
```

### `packer.nvim`

```lua
use {
  "your-name/orca_menu",
  requires = {
    "nvim-lualine/lualine.nvim",
    "anuvyklack/hydra.nvim",
  },
  config = function()
    require("orca_menu").setup({})
  end,
}
```

## Nix Flake Package

This repository includes two Nix-oriented packaging entrypoints:

- `flake.nix`
  - exposes `packages.default` as a Vim plugin package
- `nix/overlay.nix`
  - exposes `vimPlugins.orca-menu`
- `nix/home-manager-module.nix`
  - small Home Manager helper module

Example flake input:

```nix
inputs.orca-menu.url = "github:your-name/orca_menu";
```

Example plugin use with overlay output:

```nix
{
  inputs.orca-menu.url = "github:your-name/orca_menu";

  outputs = { self, nixpkgs, orca-menu, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ orca-menu.overlays.default ];
      };
    in {
      packages.${system}.default = pkgs.neovim;
    };
}
```

## Setup

Call:

```lua
require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<M-m>",
    mode_backend = "hydra",
  },
  lualine = {
    section = "y",
    spacing = " ",
  },
  submenu = {
    border = "rounded",
    min_width = 18,
    scroll_indicator_up = "↑",
    scroll_indicator_down = "↓",
  },
  highlights = {
    menu = "NormalFloat",
    menu_sel = "OrcaMenuSelected",
    accelerator = "OrcaMenuHint",
  },
  menus = {
    { label = "&File", key = "f", items = {} },
  },
})
```

## Menu Behavior

### Mode Keys

Default keys:

- open: `<M-m>`
- next top menu: `l` / `<Right>`
- previous top menu: `h` / `<Left>`
- next row: `j` / `<Down>`
- previous row: `k` / `<Up>`
- select: `<CR>`
- back: `<BS>` / `<Esc>`
- close: `q`

### `Esc` Behavior

- in a child submenu, `Esc` closes only that child and returns to its parent
- in a first-level popup, `Esc` closes the popup and leaves menu mode
- after executing an action, all popups close and menu mode exits before the action runs
- when a popup is taller than the screen, selection keeps the visible window scrolled
- child submenus open beside the visible parent row and flip left if needed
- `submenu.scroll_indicator_up` and `submenu.scroll_indicator_down` customize the border scroll markers

### Top Menu Keys

Each top-level menu can define:

```lua
{ label = "&File", key = "f", items = { ... } }
```

- explicit `key` opens that visible top menu
- if `key` is absent, the `&` accelerator is used as a fallback

Rendered labels look like:

- `File(f)`
- `Tools(t)`

### Popup Item Keys

Each popup item can define:

```lua
{ label = "&Save", key = "s", command = "write" }
{ label = "&Terminal", key = "t", items = { ... } }
```

- explicit `key` activates the visible item
- if `key` is absent, the `&` accelerator is used as a fallback
- right-side key hints are rendered in the popup

Examples:

- `1`
- `Tab`
- `Space`
- `Ctrl+x`

## Menu Item Fields

Each item may use:

- `label`
- `key`
- `command`
- `keys`
- `action`
- `lua`
- `items`

Use `{ label = "-" }` for a separator.

## Highlights

Default popup highlights:

- `menu`
  - base popup row highlight
- `menu_sel`
  - selected popup row highlight
- `accelerator`
  - popup key-hint highlight

By default:

- right-side key hints use `OrcaMenuHint`
- the selected row uses `OrcaMenuSelected`

## Main Files

- `lua/orca_menu/init.lua`
- `lua/orca_menu/hydra_mode.lua`
- `lua/orca_menu/input.lua`
- `lua/orca_menu/popup.lua`
- `lua/orca_menu/layout.lua`
- `lua/orca_menu/lualine.lua`
- `flake.nix`
- `nix/overlay.nix`
