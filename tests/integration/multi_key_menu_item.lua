local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_multi_menu_action = 0

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
      key = "ff",
      items = {
        {
          label = "&Tools",
          key = "tt",
          items = {
            {
              label = "&Nested",
              key = "nn",
              action = function()
                vim.g.orca_multi_menu_action = vim.g.orca_multi_menu_action + 1
              end,
            },
          },
        },
        {
          label = "&Open",
          key = "oo",
          action = function()
            vim.g.orca_multi_menu_action = vim.g.orca_multi_menu_action + 10
          end,
        },
      },
    },
    {
      label = "&Edit",
      key = "ee",
      items = {
        {
          label = "Cu&t",
          key = "xx",
          action = function()
            vim.g.orca_multi_menu_action = vim.g.orca_multi_menu_action + 100
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local function press_typed(keys)
  vim.fn.feedkeys(keys, "xt")
  H.flush()
  H.flush()
end

popup.enter_menu_mode(1)

H.truthy(vim.fn.maparg("ff", "n", false, true).callback, "multi-key top menu should be mapped in normal mode")
H.truthy(vim.fn.maparg("ff", "x", false, true).callback, "multi-key top menu should be mapped in visual mode")
H.truthy(vim.fn.maparg("tt", "n", false, true).callback, "multi-key submenu item should be mapped in normal mode")
H.truthy(vim.fn.maparg("nn", "n", false, true).callback, "multi-key nested item should be mapped in normal mode")

press_typed("ee")
H.truthy(popup.is_open(), "typed ee should open the matching top menu")
H.eq(state.active_top, 2, "typed ee should activate Edit")
H.eq(#state.menu_stack, 1, "typed ee should open one popup level")

popup.close_all()
popup.enter_menu_mode(1)
press_typed("ff")
H.truthy(popup.is_open(), "typed ff should open the matching top menu")
H.eq(state.active_top, 1, "typed ff should activate File")

press_typed("tt")
H.eq(#state.menu_stack, 2, "typed tt should open the matching submenu")
H.eq(state.menu_stack[2].items[1].label, "Nested", "typed tt should open the Tools submenu")

press_typed("nn")
H.eq(vim.g.orca_multi_menu_action, 1, "typed nn should execute the nested action")
H.falsy(state.menu_mode, "typed nn action should leave menu mode")
H.falsy(popup.is_open(), "typed nn action should close popups")

popup.enter_menu_mode(1)
press_typed("ff")
press_typed("oo")
H.eq(vim.g.orca_multi_menu_action, 11, "typed oo should execute the direct action")
H.falsy(state.menu_mode, "typed oo action should leave menu mode")
H.falsy(popup.is_open(), "typed oo action should close popups")

H.finish()
print("ok - tests/integration/multi_key_menu_item.lua")
