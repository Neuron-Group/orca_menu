{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vim.orcaMenu;
  overlay = import ./overlay.nix;
  pluginPkgs = import pkgs.path {
    system = pkgs.system;
    overlays = [ overlay ];
  };
  inherit (lib) literalExpression mkEnableOption mkIf mkMerge mkOption optionalAttrs types;
  toLua = lib.generators.toLua { multiline = true; indent = "  "; };
  setupLua = toLua cfg.settings;
in {
  options.vim.orcaMenu = {
    enable = mkEnableOption "orca_menu plugin for nvf";

    package = mkOption {
      type = types.package;
      default = pluginPkgs.vimPlugins.orca-menu;
      defaultText = literalExpression "pkgs.vimPlugins.orca-menu";
      description = "The `orca_menu` plugin package to install.";
    };

    installDependencies = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install `hydra.nvim` and `lualine.nvim` alongside `orca_menu`.";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      example = literalExpression ''
        {
          enable_mouse = true;
          keys.open = "<F12>";
          topbar.hint_format = "{hint}→{label}";
          menus = [
            {
              label = "&File";
              key = "f";
              items = [
                { label = "&Write"; key = "w"; command = "write"; }
                {
                  label = "Write &As";
                  key = "a";
                  lua = lib.generators.mkLuaInline "function() vim.cmd('write') end";
                }
              ];
            }
          ];
        }
      '';
      description = ''
        Attribute set passed to `require("orca_menu").setup(...)`.

        Use `lib.generators.mkLuaInline` for Lua callbacks or formatter
        functions such as `topbar.hint_format` or item `lua` handlers.
      '';
    };

    extraConfigLua = mkOption {
      type = types.lines;
      default = "";
      example = ''
        vim.api.nvim_create_user_command("OrcaMenuDebug", function()
          require("orca_menu").toggle()
        end, {})
      '';
      description = "Additional Lua appended after `orca_menu` setup runs.";
    };
  };

  config = mkIf cfg.enable {
    vim.extraPlugins = mkMerge [
      {
        orca-menu = {
          package = cfg.package;
          setup = ''
            require("orca_menu").setup(${setupLua})
            ${cfg.extraConfigLua}
          '';
        };
      }
      (optionalAttrs cfg.installDependencies {
        hydra-nvim = {
          package = pkgs.vimPlugins.hydra-nvim;
        };
        lualine-nvim = {
          package = pkgs.vimPlugins.lualine-nvim;
        };
      })
    ];
  };
}
