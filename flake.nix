{
  description = "orca_menu: VSCode-style top menu plugin for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      src = builtins.path {
        path = ./.;
        name = "orca-menu-src";
      };
      overlay = final: prev: {
        vimPlugins = prev.vimPlugins // {
          orca-menu = final.vimUtils.buildVimPlugin {
            pname = "orca-menu";
            version = "dev";
            src = src;
          };
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
        pluginPackage = pkgs.vimPlugins.orca-menu;
      in {
        packages.default = pluginPackage;

        checks = {
          package = pluginPackage;
          tests = pkgs.runCommand "orca-menu-tests" {
            nativeBuildInputs = [ pkgs.bash pkgs.neovim pkgs.python3 ];
          } ''
            export HOME="$TMPDIR/home"
            export XDG_STATE_HOME="$TMPDIR/state"
            export XDG_DATA_HOME="$TMPDIR/data"
            export XDG_CACHE_HOME="$TMPDIR/cache"
            mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
            cd ${src}
            bash ${src}/scripts/check.sh
            touch "$out"
          '';
        };
      })
    // {
      overlays.default = overlay;
      nvfModules.default = import ./nix/nvf-module.nix;
    };
}
