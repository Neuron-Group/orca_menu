{
  description = "orca_menu nvf-based local test environment";

  inputs = {
    home-manager-config.url = "path:/home/neuron/.config/home-manager";
    nixpkgs.follows = "home-manager-config/nixpkgs";
    nvf.follows = "home-manager-config/nvf";
    orca-menu.url = "path:/home/neuron/Projects/orca_menu";
    orca-menu.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, home-manager-config, orca-menu, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      hmNvf = import "${home-manager-config}/programs/nvf/default.nix" {
        inherit system pkgs;
        lib = pkgs.lib;
        inputs = inputs // {
          orca-menu = orca-menu;
        };
      };
      neovimPkg = builtins.elemAt hmNvf.home.packages 0;
    in {
      packages.${system}.default = neovimPkg;

      apps.${system}.default = {
        type = "app";
        program = "${neovimPkg}/bin/nvim";
      };
    };
}
