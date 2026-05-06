local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_parent_click_action = 0
vim.g.orca_parent_click_nested = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  submenu = {
    hover_select = true,
    hover_parent = "background",
    hover_topbar = false,
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
            vim.g.orca_parent_click_action = vim.g.orca_parent_click_action + 1
          end,
        },
        {
          label = "Sub&tools",
          key = "t",
          items = {
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_parent_click_nested = vim.g.orca_parent_click_nested + 1
              end,
            },
          },
        },
        {
          label = "For&mat",
          key = "m",
          items = {
            {
              label = "&Trim",
              key = "r",
              action = function()
                vim.g.orca_parent_click_nested = vim.g.orca_parent_click_nested + 10
              end,
            },
          },
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local mouse = { screenrow = 1, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function click_row(level, row)
  local entry = state.menu_stack[level]
  mouse.screenrow = entry.content_row + row - 1
  mouse.screencol = entry.content_col + 1
  popup.handle_mouse()
end

popup.open_top(1)
H.eq(#state.menu_stack, 1, "opening the top popup should start with one level")

click_row(1, 2)
H.eq(#state.menu_stack, 2, "clicking a submenu row in the deepest menu should open its child popup")
H.eq(state.menu_stack[1].selected, 2, "opening the first child popup should select its parent row")

click_row(1, 2)
H.eq(#state.menu_stack, 1, "clicking the same parent submenu row should close its child popup")
H.eq(state.menu_stack[1].selected, 2, "closing a child popup should preserve parent selection")

click_row(1, 2)
H.eq(#state.menu_stack, 2, "clicking the same parent submenu row again should reopen its child popup")

click_row(1, 3)
H.eq(#state.menu_stack, 2, "clicking a different parent submenu row should replace the old child popup")
H.eq(state.menu_stack[1].selected, 3, "switching parent submenu rows should retarget parent selection")
H.eq(state.menu_stack[2].items[1].label, "Trim", "switching parent submenu rows should open the new child popup")

click_row(1, 1)
H.eq(#state.menu_stack, 1, "clicking a parent action row while a child popup is open should close descendants")
H.eq(state.menu_stack[1].selected, 1, "clicking a parent action row should focus that row")
H.eq(vim.g.orca_parent_click_action, 0, "clicking a parent action row while descendants are open should not execute immediately")

click_row(1, 1)
H.flush()
H.eq(vim.g.orca_parent_click_action, 1, "clicking the focused action row again at the deepest level should execute it")
H.falsy(popup.is_open(), "executing the focused deepest action row should close the popup tree")

popup.open_top(1)
click_row(1, 3)
H.eq(#state.menu_stack, 2, "reopening should still allow opening another child popup")

click_row(2, 1)
H.flush()
H.eq(vim.g.orca_parent_click_nested, 10, "clicking an action in the deepest child popup should still execute immediately")
H.falsy(popup.is_open(), "executing a deepest child action should close the popup tree")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_parent_click_policy.lua")
