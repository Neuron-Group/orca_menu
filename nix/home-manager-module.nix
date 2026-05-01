{ pkgs, lib, config, ... }:
let
  overlay = import ./overlay.nix;
  pluginPkgs = import pkgs.path {
    system = pkgs.system;
    overlays = [ overlay ];
  };
in {
  options.programs.orca-menu.enable = lib.mkEnableOption "orca-menu Neovim plugin";

  config = lib.mkIf config.programs.orca-menu.enable {
    programs.neovim = {
      enable = lib.mkDefault true;
      plugins = [
        pluginPkgs.vimPlugins.orca-menu
        pkgs.vimPlugins.hydra-nvim
        pkgs.vimPlugins.lualine-nvim
      ];
    };
  };
}
