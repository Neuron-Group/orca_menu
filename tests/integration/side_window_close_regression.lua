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
        { label = "&Open", key = "o", action = function() end },
        { label = "&Save", key = "s", action = function() end },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        { label = "Cu&t", key = "x", action = function() end },
      },
    },
  },
})

local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

H.render_statusline()

require("orca_menu").open_menu(1)
H.truthy(popup.is_open(), "menu should open before splitting the window")
H.truthy(state.menu_mode, "opening the menu should enable menu mode")
H.eq(#state.menu_stack, 1, "opening the menu should create the root popup")

local owner_win = vim.api.nvim_get_current_win()
vim.cmd("vsplit")
local new_win = vim.api.nvim_get_current_win()

H.truthy(new_win ~= owner_win, "vsplit should enter a different window")
H.falsy(popup.is_open(), "switching to a side window should close the popup")
H.falsy(state.menu_mode, "switching to a side window should leave menu mode")
H.eq(#state.menu_stack, 0, "switching to a side window should clear the menu stack")

H.finish()
print("ok - tests/integration/side_window_close_regression.lua")
