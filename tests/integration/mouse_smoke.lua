local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mouse_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    mode_backend = "builtin",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_mouse_action = vim.g.orca_mouse_action + 1
          end,
        },
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

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

local statusline_row = vim.o.lines - vim.o.cmdheight
local restore = H.stub_mouse({
  screenrow = statusline_row,
  screencol = state.label_positions[1],
})

popup.handle_mouse()
H.truthy(popup.is_open(), "mouse click on visible top label should open popup")
H.eq(state.active_top, 1, "mouse click should target the clicked top menu")

popup.handle_mouse()
H.falsy(popup.is_open(), "clicking the same top label should close the popup tree")
restore()

require("orca_menu").open_menu(1)
local entry = state.menu_stack[1]
local restore_item = H.stub_mouse({
  screenrow = entry.content_row,
  screencol = entry.content_col,
})

popup.handle_mouse()
H.flush()
H.eq(vim.g.orca_mouse_action, 1, "mouse click on popup item should execute its action")
H.falsy(popup.is_open(), "mouse item activation should close popup tree")

restore_item()
H.finish()
print("ok - tests/integration/mouse_smoke.lua")

