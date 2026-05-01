# Packaging Notes

This directory contains optional packaging helpers for publishing `orca_menu`.

## Common Neovim Plugin

Use the repository root directly with a plugin manager such as `lazy.nvim`.
See the main `README.md` for examples.

## Nix / Flake Package

- `flake.nix`
  - exposes `packages.default` as a Neovim plugin package
- `nix/overlay.nix`
  - overlay form for importing into an existing Nix setup
- `nix/home-manager-module.nix`
  - small Home Manager helper module
