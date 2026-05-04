# NVF Test Environment

This subflake exercises the exported `nvf` module from this repository against your local `nvf` input versions.

## What it uses

- `orca-menu.nvfModules.default`
- `tests/nvf/module-example.nix`
- `tests/nvf/module-lsp-overrides-example.nix`
- your Home Manager flake inputs through `path:/home/neuron/.config/home-manager`

## Build

```bash
nix build ./tests/nvf#default --no-write-lock-file
```

## Run

```bash
nix run ./tests/nvf#default -- --headless "+checkhealth" +qa
```

Or open the interactive test Neovim:

```bash
nix run ./tests/nvf#default
```

## Notes

- the generated Neovim package comes from `nvf.lib.neovimConfiguration`
- `inputs.orca-menu` points at this repo so local module/plugin changes are tested
- `module-example.nix` covers basic static config
- `module-lsp-overrides-example.nix` shows `lsp_overrides` and inline Lua callbacks
- if flakes need to refresh uncached inputs, you may need network access
