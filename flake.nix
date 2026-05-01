{
  description = "orca_menu: VSCode-style top menu plugin for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages.default = pkgs.vimUtils.buildVimPlugin {
          pname = "orca-menu";
          version = "dev";
          src = self;
        };

        overlays.default = final: prev: {
          vimPlugins = prev.vimPlugins // {
            orca-menu = final.vimUtils.buildVimPlugin {
              pname = "orca-menu";
              version = "dev";
              src = self;
            };
          };
        };
      }
    );
}
