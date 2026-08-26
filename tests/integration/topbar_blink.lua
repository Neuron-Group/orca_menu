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

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function top_col(index)
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local click_file = _G.orca_menu_click_menu_1
local click_edit = _G.orca_menu_click_menu_2
H.truthy(click_file, "top-bar click handler for File should exist")
H.truthy(click_edit, "top-bar click handler for Edit should exist")
H.eq(vim.fn.maparg("<LeftRelease>", "n", false, true), {}, "release should stay native while popup is inactive")

local function feed_mouse_press(key)
  vim.fn.feedkeys(vim.keycode(key), "xt")
end

mouse.screencol = top_col(1)
click_file()
H.truthy(popup.is_open(), "top-bar press should open popup")
H.truthy(state.menu_mode, "top-bar press should enable menu mode")
H.truthy(vim.fn.maparg("<LeftRelease>", "n", false, true).callback, "release should be handled while popup is open")

vim.fn.maparg("<LeftRelease>", "n", false, true).callback()
H.truthy(popup.is_open(), "top-bar release should not close or reopen popup")
H.truthy(state.menu_mode, "top-bar release should keep menu mode active")

mouse.screencol = top_col(1)
click_file()
H.falsy(popup.is_open(), "second top-bar press on same menu should close popup tree")
H.falsy(state.menu_mode, "second top-bar press on same menu should leave menu mode")
H.eq(vim.fn.maparg("<LeftRelease>", "n", false, true), {}, "release should return native after close")

feed_mouse_press("<2-LeftMouse>")
H.truthy(popup.is_open(), "counted repeat top-bar press should reopen popup immediately after close")
H.truthy(state.menu_mode, "counted repeat top-bar press should re-enable menu mode")
click_file()
H.falsy(popup.is_open(), "top-bar should close again after counted-repeat reopen")

for attempt, key in ipairs({ "<3-LeftMouse>", "<4-LeftMouse>", "<4-LeftMouse>", "<LeftMouse>" }) do
  mouse.screencol = top_col(1)
  feed_mouse_press(key)
  H.eq(popup.is_open(), attempt % 2 == 1, "fast counted top-bar presses should keep alternating popup state")
end

mouse.screencol = top_col(1)
click_file()
H.truthy(popup.is_open(), "top-bar popup should reopen cleanly after close")
mouse.screencol = top_col(2)
click_edit()
H.truthy(popup.is_open(), "switching top-bar targets should keep popup open")
H.eq(state.active_top, 2, "switching top-bar targets should move active top")
vim.fn.maparg("<LeftRelease>", "n", false, true).callback()
H.truthy(popup.is_open(), "release after top-bar switch should not close or reopen")
H.eq(state.active_top, 2, "release after top-bar switch should keep active top stable")

restore_mouse()
H.finish()
print("ok - tests/integration/topbar_blink.lua")
