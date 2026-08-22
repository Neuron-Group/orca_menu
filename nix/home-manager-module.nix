{ lualine ? null }:
{ pkgs, lib, config, ... }:
let
  overlay = import ./overlay.nix { inherit lualine; };
  pluginPkgs = pkgs.extend overlay;
  cfg = config.programs.orca-menu;
in {
  options.programs.orca-menu = {
    enable = lib.mkEnableOption "orca-menu Neovim plugin";

    package = lib.mkOption {
      type = lib.types.package;
      default = pluginPkgs.vimPlugins.orca-menu;
      defaultText = lib.literalExpression "pkgs.vimPlugins.orca-menu";
      description = "The orca-menu Vim plugin package to install.";
    };

    lualinePackage = lib.mkOption {
      type = lib.types.package;
      default = pluginPkgs.vimPlugins.lualine-nvim;
      defaultText = lib.literalExpression "pkgs.vimPlugins.lualine-nvim";
      description = "The lualine package used by orca-menu; defaults to the patched package.";
    };

    installDependencies = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install hydra.nvim and the patched lualine.nvim alongside orca-menu.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Attribute set passed to require(\"orca_menu\").setup(...).";
    };

    extraConfigLua = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional Lua appended after orca-menu setup runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = lib.mkDefault true;
      plugins = [
        cfg.package
      ] ++ lib.optionals cfg.installDependencies [
        pluginPkgs.vimPlugins.hydra-nvim
        cfg.lualinePackage
      ];
      extraLuaConfig = lib.mkAfter ''
        require("orca_menu").setup(${lib.generators.toLua { multiline = true; indent = "  "; } cfg.settings})
        ${cfg.extraConfigLua}
      '';
    };
  };
}
