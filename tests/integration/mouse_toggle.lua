local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "&Open", key = "o", action = function() end },
      },
    },
  },
})

local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")
local state = require("orca_menu.state")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function top_col(index)
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

H.eq(vim.fn.maparg("<LeftMouse>", "n", false, true), {}, "mouse bindings should stay inactive before a popup opens")
H.eq(vim.fn.maparg("<2-LeftMouse>", "n", false, true), {}, "double-click bindings should stay inactive before a popup opens")
H.eq(vim.fn.maparg("<LeftRelease>", "n", false, true), {}, "release bindings should stay inactive before a popup opens")
H.eq(vim.fn.maparg("<2-LeftRelease>", "n", false, true), {}, "double-release bindings should stay inactive before a popup opens")
H.eq(vim.fn.maparg("<2-LeftDrag>", "n", false, true), {}, "double-drag bindings should stay inactive before a popup opens")

mouse.screencol = top_col(1)
_G.orca_menu_click_menu_1()
H.flush()
H.truthy(popup.is_open(), "top-bar click should open popup")
H.truthy(vim.fn.maparg("<LeftMouse>", "n", false, true).callback, "mouse bindings should install while popup is open")
H.truthy(vim.fn.maparg("<2-LeftMouse>", "n", false, true).callback, "double-click bindings should install while popup is open")
H.truthy(vim.fn.maparg("<LeftRelease>", "n", false, true).callback, "release bindings should install while popup is open")
H.truthy(vim.fn.maparg("<2-LeftRelease>", "n", false, true).callback, "double-release bindings should install while popup is open")
H.truthy(vim.fn.maparg("<2-LeftDrag>", "n", false, true).callback, "double-drag bindings should install while popup is open")

popup.close_all()
H.eq(vim.fn.maparg("<LeftMouse>", "n", false, true), {}, "mouse bindings should be removed after popup close")
H.eq(vim.fn.maparg("<2-LeftMouse>", "n", false, true), {}, "double-click bindings should be removed after popup close")
H.eq(vim.fn.maparg("<LeftRelease>", "n", false, true), {}, "release bindings should be removed after popup close")
H.eq(vim.fn.maparg("<2-LeftRelease>", "n", false, true), {}, "double-release bindings should be removed after popup close")
H.eq(vim.fn.maparg("<2-LeftDrag>", "n", false, true), {}, "double-drag bindings should be removed after popup close")

require("orca_menu").setup({
  enable_mouse = false,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "&Open", key = "o", action = function() end },
      },
    },
  },
})

H.eq(vim.fn.maparg("<LeftMouse>", "n", false, true), {}, "mouse bindings should remain absent when disabled")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_toggle.lua")
