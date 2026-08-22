{
  description = "orca_menu: VSCode-style top menu plugin for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    lualine = {
      url = "git+file:./lualine.nvim";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, lualine }:
    let
      src = builtins.path {
        path = ./.;
        name = "orca-menu-src";
        filter = path: type:
          let
            baseName = baseNameOf path;
          in
            baseName != "result"
            && baseName != ".git"
            && baseName != ".nvimlog"
            && baseName != ".tmp-orca-bootstrap-trace.log"
            && baseName != ".tmp-notify-exact-trace.log"
            && baseName != ".tmp-data"
            && baseName != "debug_click.lua"
            && baseName != "debug_clipped.lua"
            && baseName != "debug_sequence.lua"
            && baseName != "lualine.nvim";
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
        lualinePackage = pkgs.vimUtils.buildVimPlugin {
          pname = "lualine-nvim-local";
          version = "dev";
          src = lualine;
          dontUnpack = true;
          postInstall = ''
            rm -rf $out
            mkdir -p $out
            cp -r ${lualine}/. $out/
          '';
        };
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
            export ORCA_TEST_EXTRA_RTP="${lualinePackage}"
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
