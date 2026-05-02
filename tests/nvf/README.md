# NVF Test Environment

This subflake reuses the `nvf` configuration from `~/.config/home-manager/programs/nvf/` and swaps the `orca-menu` plugin source to this repository checkout.

## What it uses

- `~/.config/home-manager/programs/nvf/default.nix`
- `~/.config/home-manager/programs/nvf/orca-menu.nix`
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

- the generated Neovim package comes from your existing `nvf` module
- `inputs.orca-menu` is redirected to this repo so local plugin changes are tested
- if flakes need to refresh uncached inputs, you may need network access
