local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_repeat_action = 0

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
        {
          label = "Sub&tools",
          key = "t",
          items = {
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_repeat_action = vim.g.orca_repeat_action + 1
              end,
            },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_repeat_action = vim.g.orca_repeat_action + 10
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

require("orca_menu").open_menu(1)

for attempt = 1, 8 do
  H.truthy(popup.activate_item_key("t"), "submenu hotkey should stay active during repeats")
  H.eq(#state.menu_stack, attempt % 2 == 1 and 2 or 1, "repeated submenu hotkeys should toggle the child popup")
  H.eq(state.menu_stack[1].selected, 1, "repeated submenu hotkeys should keep parent selection stable")
end

H.eq(#state.menu_stack, 1, "even repeat counts should leave the child popup closed")
popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "child popup should reopen after being toggled closed")

local mouse = { screenrow = state.menu_stack[1].content_row, screencol = state.menu_stack[1].content_col + 1 }
local restore = H.stub_mouse(mouse)
local double_click = vim.fn.maparg("<2-LeftMouse>", "n", false, true).callback
H.truthy(double_click, "double-click mapping should be installed")

for attempt = 1, 8 do
  double_click()
  H.eq(#state.menu_stack, attempt % 2 == 1 and 1 or 2, "repeated double-clicks on submenu parents should toggle the child popup")
end

H.eq(#state.menu_stack, 2, "even repeat counts should leave the child popup reopened")

mouse.screenrow = state.menu_stack[2].content_row
mouse.screencol = state.menu_stack[2].content_col + 1
double_click()
H.flush()
H.eq(vim.g.orca_repeat_action, 1, "double-click on child action should execute exactly once per event")
H.falsy(popup.is_open(), "child action activation should close popup tree")

restore()
H.finish()
print("ok - tests/integration/repeat_activation.lua")
