local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_extreme_narrow_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&Help",
      key = "h",
      items = {
        {
          label = "&About",
          key = "a",
          action = function()
            vim.g.orca_extreme_narrow_action = vim.g.orca_extreme_narrow_action + 1
          end,
        },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        {
          label = "&Explorer",
          key = "e",
          action = function()
            vim.g.orca_extreme_narrow_action = vim.g.orca_extreme_narrow_action + 10
          end,
        },
      },
    },
    {
      label = "&Search",
      key = "s",
      items = {
        {
          label = "&Find",
          key = "f",
          action = function()
            vim.g.orca_extreme_narrow_action = vim.g.orca_extreme_narrow_action + 100
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

vim.o.laststatus = 2
vim.cmd("set columns=25")
H.render_statusline()

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

mouse.screencol = 1
_G.orca_menu_click_menu_2()
H.flush()
H.falsy(popup.is_open(), "hidden top item should not open from mouse click")
H.falsy(state.menu_mode, "hidden top item should not enter menu mode from mouse click")

H.truthy(popup.activate_top_key("s"), "visible rightmost top item should remain openable from hotkey")
H.truthy(popup.is_open(), "visible rightmost top item should open from hotkey")

restore_mouse()
H.finish()
print("ok - tests/integration/extreme_narrow_topbar_activation.lua")
