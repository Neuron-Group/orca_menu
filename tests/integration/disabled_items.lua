local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_disabled_items_action = 0
vim.g.orca_disabled_items_enabled = false

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
          label = "&Blocked",
          key = "b",
          enabled = function()
            return vim.g.orca_disabled_items_enabled
          end,
          action = function()
            vim.g.orca_disabled_items_action = vim.g.orca_disabled_items_action + 1
          end,
        },
        {
          label = "Sub&tools",
          key = "t",
          enabled = false,
          items = {
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_disabled_items_action = vim.g.orca_disabled_items_action + 10
              end,
            },
          },
        },
        {
          label = "&Ready",
          key = "r",
          action = function()
            vim.g.orca_disabled_items_action = vim.g.orca_disabled_items_action + 100
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

H.render_statusline()

require("orca_menu").open_menu(1)
H.eq(state.menu_stack[1].selected, 3, "initial selection should skip disabled rows")

popup.select_row(-1)
H.eq(state.menu_stack[1].selected, 3, "k should skip disabled rows")

popup.select_row(1)
H.eq(state.menu_stack[1].selected, 3, "j should skip disabled rows when no other enabled row exists")

H.falsy(popup.activate_item_key("b"), "disabled action hotkey should not activate")
H.falsy(popup.activate_item_key("t"), "disabled submenu hotkey should not activate")
H.eq(vim.g.orca_disabled_items_action, 0, "disabled hotkeys should not execute actions")
H.eq(#state.menu_stack, 1, "disabled submenu hotkey should not open a child popup")

local root = state.menu_stack[1]
root.selected = 1
popup.activate_selected()
H.eq(vim.g.orca_disabled_items_action, 0, "pressing select on a disabled row should do nothing")
H.eq(#state.menu_stack, 1, "pressing select on a disabled row should not change popup stack")

local mouse = { screenrow = root.content_row, screencol = root.content_col + 1 }
local restore_mouse = H.stub_mouse(mouse)
popup.handle_mouse()
H.eq(vim.g.orca_disabled_items_action, 0, "mouse click on disabled row should do nothing")
H.eq(root.selected, 1, "mouse click on disabled row should not move selection")

vim.g.orca_disabled_items_enabled = true
popup.redraw_all()
H.eq(state.menu_stack[1].selected, 1, "selection should dock on the newly enabled first row")

popup.activate_item_key("b")
H.flush()
H.eq(vim.g.orca_disabled_items_action, 1, "enabled hotkey should execute once the item becomes available")
H.falsy(state.menu_mode, "executing an enabled item should leave menu mode")
H.falsy(popup.is_open(), "executing an enabled item should close the popup")

restore_mouse()
H.finish()
print("ok - tests/integration/disabled_items.lua")
