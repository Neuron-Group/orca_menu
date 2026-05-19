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
local mode = require("orca_menu.mode")

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

local function hover_top_insert(index)
  mouse.screenrow = statusline_row()
  mouse.screencol = top_col(index)
  local hover_map = vim.fn.maparg("<MouseMove>", "i", false, true)
  H.truthy(hover_map.callback, "insert-mode hover test expects hover mouse mapping to be installed")
  vim.api.nvim_input(vim.keycode("<MouseMove>"))
end

H.falsy(popup.is_open(), "popup should start closed")
H.eq(vim.fn.maparg("<MouseMove>", "n", false, true), {}, "idle normal-mode mousemove should stay native while popup is closed")
H.eq(vim.fn.maparg("<MouseMove>", "i", false, true), {}, "idle insert-mode mousemove should stay native while popup is closed")

popup.open_top(1)
H.truthy(popup.is_open(), "popup should be open after opening File")
H.eq(state.active_top, 1, "opening File should target File")
H.truthy(vim.fn.maparg("<MouseMove>", "n", false, true).callback, "open popup should install normal-mode mousemove handling")
H.truthy(vim.fn.maparg("<MouseMove>", "i", false, true).callback, "open popup should install insert-mode mousemove handling")

local original_is_insert = mode.is_insert
local original_run_after_editor_mode = mode.run_after_editor_mode
local handoff_called = false
mode.is_insert = function()
  return true
end
mode.run_after_editor_mode = function(fn)
  handoff_called = true
  if fn then
    fn()
  end
end
hover_top_insert(2)
H.flush()
H.falsy(handoff_called, "hovering in insert mode should not invoke editor-mode handoff")
H.eq(state.active_top, 1, "hovering top bar in insert mode should not retarget active_top")
mode.is_insert = original_is_insert
mode.run_after_editor_mode = original_run_after_editor_mode

hover_top(2)
H.truthy(popup.is_open(), "hovering another top item while popup is open should keep a popup open")
H.eq(state.active_top, 2, "hovering another top item while popup is open should switch active_top")
H.eq(#state.menu_stack, 1, "hovering another top item while popup is open should switch to that popup tree")

hover_top(3)
H.eq(state.active_top, 3, "hovering a third top item while popup is open should keep switching active_top")
H.eq(#state.menu_stack, 1, "top-bar hover switching should keep exactly one top-level popup")

popup.close_all()
H.eq(vim.fn.maparg("<MouseMove>", "n", false, true), {}, "closing popup should remove normal-mode mousemove handling again")
H.eq(vim.fn.maparg("<MouseMove>", "i", false, true), {}, "closing popup should remove insert-mode mousemove handling again")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_hover_topbar.lua")
