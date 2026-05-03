local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mixed_action = 0

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
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_mixed_action = vim.g.orca_mixed_action + 1
              end,
            },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_mixed_action = vim.g.orca_mixed_action + 10
          end,
        },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        {
          label = "Cu&t",
          key = "x",
          action = function()
            vim.g.orca_mixed_action = vim.g.orca_mixed_action + 100
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

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = state.label_positions[1] + 1 }
local restore = H.stub_mouse(mouse)
local left_mouse = vim.fn.maparg("<LeftMouse>", "n", false, true).callback
H.truthy(left_mouse, "left mouse mapping should exist")

local function top_col(index)
  return state.label_positions[index] + 1
end

local function click_top(index)
  H.render_statusline()
  layout.refresh_label_positions()
  mouse.screenrow = vim.o.lines - vim.o.cmdheight
  mouse.screencol = top_col(index)
  left_mouse()
end

click_top(1)
H.truthy(state.menu_mode, "mouse top-bar open should enable menu mode")
H.truthy(popup.is_open(), "mouse top-bar open should open popup")
H.eq(state.active_top, 1, "mouse top-bar open should target the clicked menu")

popup.select_row(1)
H.eq(state.menu_stack[1].selected, 2, "keyboard row movement should work after mouse open")
popup.activate_selected()
H.flush()
H.eq(vim.g.orca_mixed_action, 10, "keyboard selection should execute action after mouse open")
H.falsy(state.menu_mode, "keyboard action after mouse open should leave menu mode")
H.falsy(popup.is_open(), "keyboard action after mouse open should close popup tree")

popup.enter_menu_mode(1)
H.truthy(state.menu_mode, "enter_menu_mode should re-enable menu mode")
H.eq(#state.menu_stack, 0, "enter_menu_mode should not open popup immediately")

click_top(1)
H.truthy(popup.is_open(), "mouse should open popup while menu mode is already active")
H.eq(#state.menu_stack, 1, "mouse open from menu mode should create one popup level")
popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "keyboard submenu hotkey should work after mouse open in menu mode")

click_top(2)
H.truthy(popup.is_open(), "mouse top-bar switch should keep popup tree open")
H.eq(state.active_top, 2, "mouse top-bar switch should update active menu")
H.eq(#state.menu_stack, 1, "mouse top-bar switch should collapse child submenus")

popup.activate_item_key("x")
H.flush()
H.eq(vim.g.orca_mixed_action, 110, "keyboard item hotkey should execute after mouse top-bar switch")
H.falsy(state.menu_mode, "keyboard action after mouse switch should leave menu mode")
H.falsy(popup.is_open(), "keyboard action after mouse switch should close popup tree")

popup.enter_menu_mode(1)
popup.activate_top_key("f")
H.truthy(popup.is_open(), "keyboard top activation should open popup")
H.eq(state.active_top, 1, "keyboard top activation should target File")

mouse.screenrow = state.menu_stack[1].content_row
mouse.screencol = state.menu_stack[1].content_col + 1
left_mouse()
H.eq(#state.menu_stack, 2, "mouse click on submenu row should open child popup after keyboard open")

popup.go_back()
H.eq(#state.menu_stack, 1, "keyboard back should close child submenu after mouse-opened child")
H.truthy(state.menu_mode, "keyboard back from child should keep menu mode active")

click_top(1)
H.falsy(popup.is_open(), "mouse click on active top menu should close popup after keyboard open")
H.falsy(state.menu_mode, "mouse click on active top menu should leave menu mode after keyboard open")

restore()
H.finish()
print("ok - tests/integration/mixed_input.lua")
