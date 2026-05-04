{
  lib,
  ...
}: {
  imports = [
    ../../nix/nvf-module.nix
  ];

  vim.orcaMenu = {
    enable = true;

    settings = {
      enable_mouse = true;
      keys.open = "<F12>";

      topbar.hint_format = lib.generators.mkLuaInline ''
        function(ctx)
          return string.format("%s <%s>", ctx.label, ctx.hint)
        end
      '';

      menus = [
        {
          label = "&File";
          key = "f";
          items = [
            { label = "&Write"; key = "w"; command = "write"; }
            { label = "Write &Quit"; key = "q"; command = "wq"; }
          ];
        }
        {
          label = "&Tools";
          key = "t";
          items = [
            {
              label = "Insert &Timestamp";
              key = "i";
              lua = lib.generators.mkLuaInline ''
                function()
                  local stamp = os.date("%Y-%m-%d %H:%M:%S")
                  vim.api.nvim_put({ stamp }, "c", true, true)
                end
              '';
            }
          ];
        }
      ];

      lsp_overrides = {
        rust_analyzer = {
          menus = [
            {
              label = "&Rust";
              key = "r";
              items = [
                { label = "&Run"; key = "r"; command = "RustLsp runnables"; }
                { label = "&Expand Macro"; key = "m"; command = "RustLsp expandMacro"; }
              ];
            }
            {
              label = "&File";
              key = "f";
              items = [
                { label = "&Write"; key = "w"; command = "write"; }
              ];
            }
          ];
        };

        lua_ls = {
          topbar.hint_format = lib.generators.mkLuaInline ''
            function(ctx)
              return string.format("%s → %s", ctx.hint, ctx.label)
            end
          '';
        };
      };
    };
  };
}
