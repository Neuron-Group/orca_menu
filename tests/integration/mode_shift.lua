local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mode_shift_action = 0

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
          label = "Sub&tools",
          key = "t",
          items = {
            { label = "&Nested", key = "n", action = function() end },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_mode_shift_action = vim.g.orca_mode_shift_action + 1
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

local open_key = vim.fn.maparg("<F13>", "n", false, true).callback
H.truthy(open_key, "open key mapping should exist")

H.falsy(state.menu_mode, "menu mode should start inactive")
open_key()
H.truthy(state.menu_mode, "open key should enter menu mode")
H.eq(#state.menu_stack, 0, "open key should not open popup immediately")

popup.activate_top_key("f")
H.truthy(popup.is_open(), "top-key activation should open popup from menu mode")
H.eq(#state.menu_stack, 1, "opening top popup should create one stack level")

popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "submenu activation should add a child level")
H.truthy(state.menu_mode, "submenu activation should keep menu mode active")

popup.go_back()
H.eq(#state.menu_stack, 1, "go_back from child submenu should pop one level")
H.truthy(state.menu_mode, "go_back from child submenu should keep menu mode active")

popup.go_back()
H.eq(#state.menu_stack, 0, "go_back at root should close the popup tree")
H.falsy(state.menu_mode, "go_back at root should leave menu mode")

popup.enter_menu_mode(1)
H.truthy(state.menu_mode, "enter_menu_mode should re-enable menu mode")
popup.activate_top_key("f")
popup.activate_item_key("o")
H.flush()
H.eq(vim.g.orca_mode_shift_action, 1, "action activation should execute once")
H.falsy(state.menu_mode, "action execution should leave menu mode")
H.falsy(popup.is_open(), "action execution should close popup tree")

H.render_statusline()
layout.refresh_label_positions()
local click_menu = _G.orca_menu_click_menu_1
H.truthy(click_menu, "top-bar click handler should exist")
click_menu()
H.truthy(state.menu_mode, "mouse top-bar open should enable menu mode")
H.truthy(popup.is_open(), "mouse top-bar open should open popup tree")
click_menu()
H.falsy(state.menu_mode, "mouse top-bar close should leave menu mode")
H.falsy(popup.is_open(), "mouse top-bar close should close popup tree")

H.finish()
print("ok - tests/integration/mode_shift.lua")
