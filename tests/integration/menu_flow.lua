local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_test_action = 0
vim.g.orca_nested_action = 0

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
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_test_action = vim.g.orca_test_action + 1
          end,
        },
        { label = "-" },
        {
          label = "Sub&tools",
          key = "t",
          items = {
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_nested_action = vim.g.orca_nested_action + 1
              end,
            },
          },
        },
        {
          label = "Sa&ve",
          key = "s",
          action = function()
            vim.g.orca_test_action = vim.g.orca_test_action + 10
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

H.render_statusline()

vim.cmd("OrcaMenu")
H.truthy(state.menu_mode, "toggle should enter menu mode")
H.eq(#state.menu_stack, 0, "toggle should not open a popup immediately")

vim.cmd("OrcaMenu")
H.falsy(state.menu_mode, "toggle should close menu mode")

require("orca_menu").open_menu(1)
H.truthy(popup.is_open(), "open_menu should open top popup")
H.eq(#state.menu_stack, 1, "top popup should create one menu stack level")
H.eq(state.menu_stack[1].selected, 1, "first entry should be selected initially")

popup.select_row(1)
H.eq(state.menu_stack[1].selected, 3, "selection should skip separator rows")

popup.activate_selected()
H.eq(#state.menu_stack, 2, "activating submenu should push child level")
H.eq(state.menu_stack[2].items[1].label, "Nested", "child submenu items should be opened")

popup.go_back()
H.eq(#state.menu_stack, 1, "go_back should pop one submenu level")

popup.go_back()
H.eq(#state.menu_stack, 0, "go_back at root should close all popups")
H.falsy(state.menu_mode, "go_back at root should leave menu mode")

require("orca_menu").open_menu(2)
H.eq(state.active_top, 2, "explicit top open should update active top")

popup.activate_top_key("f")
H.eq(state.active_top, 1, "top key activation should switch visible menus")
H.truthy(popup.is_open(), "top key activation should open the menu")

popup.activate_item_key("o")
H.flush()
H.eq(vim.g.orca_test_action, 1, "item key activation should execute the matching action")
H.falsy(state.menu_mode, "action execution should close menu mode")
H.falsy(popup.is_open(), "action execution should close popups")

H.finish()
print("ok - tests/integration/menu_flow.lua")

