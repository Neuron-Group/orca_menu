local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.o.mousemoveevent = false

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  submenu = {
    hover_select = true,
    hover_topbar = true,
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "&Open", key = "o", action = function() end },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        { label = "Cu&t", key = "x", action = function() end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Tree", key = "r", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function statusline_row()
  return vim.o.lines - vim.o.cmdheight
end

local function top_col(index)
  layout.refresh_label_positions()
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local function hover_top(index)
  mouse.screenrow = statusline_row()
  mouse.screencol = top_col(index)
  local hover_map = vim.fn.maparg("<MouseMove>", "n", false, true)
  H.truthy(hover_map.callback, "top-bar hover test expects hover mouse mapping to be installed")
  hover_map.callback()
end

H.falsy(popup.is_open(), "popup should start closed")
hover_top(2)
H.falsy(popup.is_open(), "hovering top bar while popup is closed should not open a popup")
H.eq(state.active_top, 1, "hovering top bar while popup is closed should not retarget active_top")

popup.open_top(1)
H.truthy(popup.is_open(), "popup should be open after opening File")
H.eq(state.active_top, 1, "opening File should target File")

hover_top(2)
H.truthy(popup.is_open(), "hovering another top item while popup is open should keep a popup open")
H.eq(state.active_top, 2, "hovering another top item while popup is open should switch active_top")
H.eq(#state.menu_stack, 1, "hovering another top item while popup is open should switch to that popup tree")

hover_top(3)
H.eq(state.active_top, 3, "hovering a third top item while popup is open should keep switching active_top")
H.eq(#state.menu_stack, 1, "top-bar hover switching should keep exactly one top-level popup")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_hover_topbar.lua")
