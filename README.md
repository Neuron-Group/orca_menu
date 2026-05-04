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
- clickable top menu bar via lualine, plus popup mouse support while Orca is open
- mouse-wheel scrolling for open popup menus
- wheel scrolling moves by nearly a full visible page
- popup borders show `↑`/`↓` when more items are hidden above or below
- configurable menu labels, accelerators, commands, and Lua callbacks
- `enable_mouse = false` disables lualine menu clicks and popup mouse bindings
- Nix flake packaging included in this repository

## Requirements

- Neovim `>= 0.9`
- `nvim-lualine/lualine.nvim`
- `anuvyklack/hydra.nvim`

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
- `nix/nvf-module.nix`
  - `nvf` module for Nix-native `orca_menu` configuration

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

## NVF Module

This repository also exports an `nvf` module at `nvfModules.default`.

Example flake use:

```nix
{
  inputs.orca-menu.url = "github:your-name/orca_menu";

  outputs = { self, nixpkgs, nvf, orca-menu, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.default = nvf.lib.neovimConfiguration {
        inherit pkgs;
        modules = [
          orca-menu.nvfModules.default
          ({ lib, ... }: {
            vim.orcaMenu = {
              enable = true;
              settings = {
                keys.open = "<F12>";
                menus = [
                  {
                    label = "&File";
                    key = "f";
                    items = [
                      { label = "&Write"; key = "w"; command = "write"; }
                    ];
                  }
                ];
              };
            };
          })
        ];
      };
    };
}
```

Module options:

- `vim.orcaMenu.enable` enables the plugin.
- `vim.orcaMenu.settings` maps to `require("orca_menu").setup(...)`.
- `vim.orcaMenu.installDependencies` also installs `hydra.nvim` and `lualine.nvim`.
- `vim.orcaMenu.extraConfigLua` appends custom Lua after setup.

For Lua callbacks inside Nix config, use `lib.generators.mkLuaInline`:

```nix
vim.orcaMenu.settings = {
  topbar.hint_format = lib.generators.mkLuaInline ''
    function(ctx)
      return string.format("%s <%s>", ctx.label, ctx.hint)
    end
  '';
};
```

There is a complete example module snippet at `tests/nvf/module-example.nix:1`.

An advanced example with `lsp_overrides` and `lib.generators.mkLuaInline`
callbacks is available at `tests/nvf/module-lsp-overrides-example.nix:1`.

## Setup

Call:

```lua
require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<M-m>",
  },
  lualine = {
    section = "y",
    spacing = " ",
  },
  topbar = {
    hint_format = "{label}({hint})",
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

## Display Customization

`orca_menu` already exposes several display-oriented options through `setup()`.

```lua
require("orca_menu").setup({
  lualine = {
    section = "x",
    spacing = "  ",
  },
  topbar = {
    hint_format = "{label} [{hint}]",
  },
  submenu = {
    border = "single",
    min_width = 24,
    scroll_indicator_up = "▲",
    scroll_indicator_down = "▼",
  },
  highlights = {
    menu = "NormalFloat",
    menu_sel = "Visual",
    accelerator = "Special",
  },
})
```

- `lualine.section` chooses where the top bar is rendered. Built-in choices are `"a"`, `"b"`, `"c"`, `"x"`, `"y"`, and `"z"`.
- `lualine.spacing` adjusts padding around each top-level label. This accepts any string.
- `topbar.hint_format` customizes how menu labels and key hints are shown. It accepts a string template with `{label}` and `{hint}`, or a function.
- `submenu.border` controls the floating-window border. Built-in choices are `"none"`, `"single"`, `"double"`, `"rounded"`, `"solid"`, and `"shadow"`; an 8-element border character table also works.
- `submenu.min_width` controls the minimum popup width. This accepts a number.
- `submenu.scroll_indicator_up` and `submenu.scroll_indicator_down` change the overflow markers. Each should be a single-cell display character.
- `highlights.menu`, `highlights.menu_sel`, and `highlights.accelerator` let you reuse your own highlight groups. These accept highlight-group names.

`topbar.hint_format` may also be a function for fully custom label rendering:

```lua
require("orca_menu").setup({
  topbar = {
    hint_format = function(ctx)
      return string.format("%s <%s>", ctx.label, ctx.hint)
    end,
  },
})
```

This keeps the built-in lualine top bar and floating popup UI, while letting
users tune the presentation.

## LSP Overrides

You can override Orca Menu config when specific LSP clients are active.

```lua
require("orca_menu").setup({
  menus = {
    { label = "&File", key = "f", items = {} },
  },

  lsp_overrides = {
    rust_analyzer = {
      menus = {
        {
          label = "&Rust",
          key = "r",
          items = {
            { label = "&Run", command = "RustLsp runnables" },
          },
        },
      },
    },

    lua_ls = {
      topbar = {
        hint_format = "{hint} -> {label}",
      },
    },
  },
})
```

- keys in `lsp_overrides` match exact `client.name`
- matching overrides are resolved from LSP clients attached to the current buffer
- `menus` fully replaces base `menus` inside an override
- other fields are deep-merged onto the base config
- when the current buffer or its LSP state changes, open popups close and menu mode exits before refresh

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
- resizing the editor or windows closes all popups and exits menu mode
- when a popup is taller than the screen, selection keeps the visible window scrolled
- child submenus open beside the visible parent row and flip left if needed
- `submenu.scroll_indicator_up` and `submenu.scroll_indicator_down` customize the border scroll markers

### Mode Handoff

- in normal mode, the open key enters menu mode directly
- in visual, visual-line, and visual-block mode, the open key or menu mouse click first leaves editor mode, then enters Hydra-backed Orca mode
- in insert mode, the open key or menu mouse click first leaves insert mode, then enters Hydra-backed Orca mode
- popup navigation keys and menu item keys are active in normal and visual mode
- insert mode only supports safe menu entry paths, so ordinary typing is not hijacked by menu item keys

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

Top-bar key hints are customizable with `topbar.hint_format`:

```lua
require("orca_menu").setup({
  topbar = {
    hint_format = "{label}[{hint}]",
  },
})
```

Supported placeholders:

- `{label}` for the menu label
- `{hint}` for the rendered key hint

Examples:

- `"{label}({hint})"` -> `File(f)`
- `"{label}[{hint}]"` -> `File[f]`
- `"{hint} -> {label}"` -> `f -> File`

You can also use a function for full custom formatting:

```lua
require("orca_menu").setup({
  topbar = {
    hint_format = function(ctx)
      return string.format("%s <%s>", ctx.label, ctx.hint)
    end,
  },
})
```

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

When `lua` is a string, it is compiled with `load(...)` and executed in the global Lua environment.

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

## Testing

Run the local headless test suite with:

```bash
bash scripts/check.sh
```

That suite includes a PTY-backed terminal test for real open-key input in:

- normal mode
- insert mode
- visual mode
- visual-line mode
- visual-block mode

The terminal suite currently covers `<F12>`, `<leader>m`, and `<M-m>`.

Run the Nix checks with:

```bash
nix flake check
```

For manual mouse-event tracing in a real UI:

```bash
ORCA_MENU_MOUSE_TRACE=/tmp/orca_menu_mouse.jsonl nix run ./tests/nvf
```

Inside Neovim you can also enable tracing manually:

```vim
:OrcaMenuMouseTrace /tmp/orca_menu_mouse.jsonl
```

Disable it with:

```vim
:OrcaMenuMouseTrace off
```

For randomized stress test failures, the error output includes a replay command you can rerun directly. You can also replay a saved sequence manually:

```bash
ORCA_MENU_REPLAY='open_key,mouse_top,activate_selected' \
  nvim --headless -u tests/minimal_init.lua -l tests/integration/randomized_stress.lua
```

Or for the repeat-biased suite:

```bash
ORCA_MENU_REPLAY='top_file_click,submenu_key_toggle,top_file_release' \
  nvim --headless -u tests/minimal_init.lua -l tests/integration/randomized_repeat_bias.lua
```
