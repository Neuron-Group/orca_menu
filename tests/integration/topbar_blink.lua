local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

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
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = state.label_positions[1] + 1 }
local restore = H.stub_mouse(mouse)
local left_mouse = vim.fn.maparg("<LeftMouse>", "n", false, true).callback
local left_release = vim.fn.maparg("<LeftRelease>", "n", false, true).callback
H.truthy(left_mouse, "left mouse mapping should exist")
H.truthy(left_release, "left release mapping should exist")

left_mouse()
H.truthy(popup.is_open(), "top-bar press should open popup")
H.truthy(state.menu_mode, "top-bar press should enable menu mode")

left_release()
H.truthy(popup.is_open(), "top-bar release should not close or reopen popup")
H.truthy(state.menu_mode, "top-bar release should keep menu mode active")

left_mouse()
H.falsy(popup.is_open(), "second top-bar press on same menu should close popup tree")
H.falsy(state.menu_mode, "second top-bar press on same menu should leave menu mode")

left_release()
H.falsy(popup.is_open(), "release after close should not reopen the same top-bar popup")
H.falsy(state.menu_mode, "release after close should not re-enter menu mode")

left_mouse()
H.truthy(popup.is_open(), "top-bar popup should reopen cleanly after close")
mouse.screencol = state.label_positions[2] + 1
left_mouse()
H.truthy(popup.is_open(), "switching top-bar targets should keep popup open")
H.eq(state.active_top, 2, "switching top-bar targets should move active top")
left_release()
H.truthy(popup.is_open(), "release after top-bar switch should not close or reopen")
H.eq(state.active_top, 2, "release after top-bar switch should keep active top stable")

restore()
H.finish()
print("ok - tests/integration/topbar_blink.lua")

