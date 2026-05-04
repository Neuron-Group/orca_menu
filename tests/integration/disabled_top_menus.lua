local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_top_menu_enabled = false

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
      enabled = false,
      items = {
        { label = "&Open", key = "o", action = function() end },
      },
    },
    {
      label = "&Edit",
      key = "e",
      enabled = function()
        return vim.g.orca_top_menu_enabled
      end,
      items = {
        { label = "Cu&t", key = "x", action = function() end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Tree", key = "t", action = function() end },
      },
    },
  },
})

local orca = require("orca_menu")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

H.falsy(popup.activate_top_key("f"), "disabled explicit top key should not activate")
H.falsy(popup.activate_top_key("e"), "disabled dynamic top key should not activate")
H.truthy(popup.activate_top_key("v"), "enabled top key should still activate")
H.eq(state.active_top, 3, "enabled top key should select the enabled menu")
H.truthy(popup.is_open(), "enabled top key should open popup")
popup.close_all()

popup.enter_menu_mode(1)
popup.move_top(1)
H.eq(state.active_top, 3, "moving right should skip disabled top menus")
popup.move_top(-1)
H.eq(state.active_top, 3, "moving left should skip disabled top menus when only one is enabled")
popup.close_all()

orca.open_menu(1)
H.eq(state.active_top, 3, "opening a disabled top menu should dock to the first enabled top menu")
H.truthy(popup.is_open(), "opening should still succeed when another top menu is enabled")
popup.close_all()

local click_file = _G.orca_menu_click_menu_1
local click_edit = _G.orca_menu_click_menu_2
local click_view = _G.orca_menu_click_menu_3
H.truthy(click_file, "disabled top menu should still have a click handler")
H.truthy(click_edit, "dynamic top menu should still have a click handler")
H.truthy(click_view, "enabled top menu should still have a click handler")

click_file()
H.falsy(popup.is_open(), "clicking a disabled top menu should do nothing")
H.falsy(state.menu_mode, "clicking a disabled top menu should not enter menu mode")

click_edit()
H.falsy(popup.is_open(), "clicking a dynamically disabled top menu should do nothing")
H.falsy(state.menu_mode, "clicking a dynamically disabled top menu should not enter menu mode")

click_view()
H.truthy(popup.is_open(), "clicking an enabled top menu should open popup")
H.eq(state.active_top, 3, "clicking enabled top menu should activate it")
popup.close_all()

vim.g.orca_top_menu_enabled = true
popup.enter_menu_mode(1)
H.eq(state.active_top, 2, "once enabled, entering menu mode should dock on the newly enabled top menu")
popup.move_top(1)
H.eq(state.active_top, 3, "navigation should move past the newly enabled top menu once docked")
popup.close_all()

H.truthy(popup.activate_top_key("e"), "enabled top key should activate once predicate flips")
H.eq(state.active_top, 2, "enabled top key should target Edit after predicate flips")

H.finish()
print("ok - tests/integration/disabled_top_menus.lua")
