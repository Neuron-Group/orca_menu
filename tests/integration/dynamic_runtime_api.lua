local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_dynamic_hits = 0

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
        { label = "&Open", key = "o", action = function() end },
      },
    },
  },
})

local orca = require("orca_menu")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

H.eq(type(orca.register_menu), "function", "runtime register API should exist")
H.eq(type(orca.update_menu), "function", "runtime update API should exist")
H.eq(type(orca.unregister_menu), "function", "runtime unregister API should exist")
H.eq(type(orca.refresh), "function", "runtime refresh API should exist")

orca.register_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    {
      label = "Run &One",
      key = "1",
      action = function()
        vim.g.orca_dynamic_hits = vim.g.orca_dynamic_hits + 1
      end,
    },
  },
})

H.eq(#state.config.menus, 2, "registering a menu should append it to the active menu list")
H.eq(state.config.menus[2].label, "Tools", "registered menu should be normalized into active config")
H.truthy(_G.orca_menu_click_menu_2, "registered menu should rebuild click handlers")
H.truthy(popup.activate_top_key("t"), "registered menu key should open its popup")
H.eq(state.active_top, 2, "registered menu key should target the appended menu")
H.truthy(popup.is_open(), "registered menu should be openable immediately")
H.truthy(popup.activate_item_key("1"), "registered menu item key should activate")
H.flush()
H.eq(vim.g.orca_dynamic_hits, 1, "registered menu action should run")

popup.open_top(2)
orca.update_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    {
      label = "Run &Two",
      key = "2",
      action = function()
        vim.g.orca_dynamic_hits = vim.g.orca_dynamic_hits + 10
      end,
    },
  },
})

H.truthy(popup.is_open(), "updating a menu should preserve popup openness during refresh")
H.eq(state.active_top, 2, "updating a menu should preserve the active top index")
H.eq(state.menu_stack[1].items[1].label, "Run Two", "updated popup content should be rebuilt")
H.truthy(popup.activate_item_key("2"), "updated menu item key should activate")
H.flush()
H.eq(vim.g.orca_dynamic_hits, 11, "updated menu action should replace the previous action")

orca.refresh()
H.eq(#state.config.menus, 2, "manual refresh should keep registered runtime menus")
H.truthy(popup.activate_top_key("t"), "runtime menu should survive explicit refresh")
popup.close_all()

H.truthy(orca.unregister_menu("tools"), "unregistering an installed menu should report success")
H.eq(#state.config.menus, 1, "unregistering should remove the runtime menu")
H.falsy(_G.orca_menu_click_menu_2, "unregistering should rebuild click handlers and remove stale entries")
H.falsy(popup.activate_top_key("t"), "removed menu key should no longer activate")
H.falsy(orca.unregister_menu("tools"), "unregistering a missing menu should report failure")

H.finish()
print("ok - tests/integration/dynamic_runtime_api.lua")
