{
  lib,
  ...
}: {
  vim.orcaMenu = {
    enable = true;

    settings = {
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
              lua = lib.generators.mkLuaInline ''
                function()
                  vim.ui.input({ prompt = "Save as: ", default = vim.fn.expand("%:p") }, function(path)
                    if path and path ~= "" then
                      vim.cmd("saveas " .. vim.fn.fnameescape(path))
                    end
                  end)
                end
              '';
            }
          ];
        }
        {
          label = "&Tools";
          key = "t";
          items = [
            { label = "&Terminal"; key = "t"; command = "ToggleTerm"; }
          ];
        }
      ];
    };
  };
}
