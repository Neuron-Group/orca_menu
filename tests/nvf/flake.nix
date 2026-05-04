{
  description = "orca_menu nvf-based local test environment";

  inputs = {
    home-manager-config.url = "path:/home/neuron/.config/home-manager";
    nixpkgs.follows = "home-manager-config/nixpkgs";
    nvf.follows = "home-manager-config/nvf";
    orca-menu.url = "path:/home/neuron/Projects/orca_menu";
  };

  outputs = inputs@{ self, nixpkgs, nvf, orca-menu, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      customNeovim = nvf.lib.neovimConfiguration {
        inherit pkgs;
        modules = [
          orca-menu.nvfModules.default
          ./module-example.nix
          {
            config.vim = {
              viAlias = true;
              vimAlias = true;
            };
          }
        ];
      };
      neovimPkg = customNeovim.neovim;
    in {
      packages.${system}.default = neovimPkg;

      apps.${system}.default = {
        type = "app";
        program = "${neovimPkg}/bin/nvim";
      };
    };
}
