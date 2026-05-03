local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_lua_action = 0

require("orca_menu").setup({
  enable_mouse = false,
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
          label = "Lua &String",
          key = "s",
          lua = "vim.g.orca_lua_action = vim.g.orca_lua_action + 1",
        },
        {
          label = "Lua &Function",
          key = "f",
          lua = function()
            vim.g.orca_lua_action = vim.g.orca_lua_action + 10
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local open_key = vim.fn.maparg("<F13>", "n", false, true).callback
H.truthy(open_key, "open key mapping should exist")

open_key()
H.flush()
H.truthy(state.menu_mode, "open key should enter menu mode")
popup.activate_top_key("f")
H.truthy(popup.is_open(), "top key should open popup")

popup.activate_item_key("s")
H.flush()
H.eq(vim.g.orca_lua_action, 1, "lua string action should execute once")
H.falsy(state.menu_mode, "lua string action should leave menu mode")
H.falsy(popup.is_open(), "lua string action should close popup")

open_key()
H.flush()
popup.activate_top_key("f")
popup.activate_item_key("f")
H.flush()
H.eq(vim.g.orca_lua_action, 11, "lua function action should execute after lua string action")
H.falsy(state.menu_mode, "lua function action should leave menu mode")
H.falsy(popup.is_open(), "lua function action should close popup")

H.finish()
print("ok - tests/integration/lua_action.lua")
