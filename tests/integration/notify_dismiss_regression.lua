local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    next = { "l" },
    prev = { "h" },
    down = { "j" },
    up = { "k" },
    select = { "<CR>" },
    back = { "<Esc>" },
    close = { "q" },
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        {
          label = "&Open",
          key = "o",
          action = function() end,
        },
      },
    },
  },
})

local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

H.render_statusline()

require("orca_menu").open_menu(1)
H.truthy(popup.is_open(), "menu should open before unrelated WinEnter")
H.eq(#state.menu_stack, 1, "menu stack should contain the root popup")

vim.api.nvim_exec_autocmds("WinEnter", { modeline = false })
H.flush()

H.truthy(popup.is_open(), "unrelated WinEnter should not close an open menu")
H.eq(#state.menu_stack, 1, "menu stack should stay intact after unrelated WinEnter")
H.truthy(state.menu_mode, "menu mode should remain enabled after unrelated WinEnter")

H.finish()
print("ok - tests/integration/notify_dismiss_regression.lua")
