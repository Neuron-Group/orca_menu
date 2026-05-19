local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

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
local hydra_mode = require("orca_menu.hydra_mode")
local popup = require("orca_menu.popup")

local hydra = hydra_mode.setup()
H.truthy(hydra:press("f"), "base hydra key should exist before runtime registration")
H.truthy(popup.is_open(), "base hydra key should open the base menu")
popup.close_all()

orca.register_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    { label = "&Build", key = "b", action = function() end },
  },
})

hydra = hydra_mode.setup()
H.truthy(hydra:press("t"), "hydra should rebuild to include a runtime-registered menu key")
H.truthy(popup.is_open(), "runtime-registered hydra key should open its popup")
popup.close_all()

H.truthy(orca.unregister_menu("tools"), "runtime menu should unregister cleanly")

hydra = hydra_mode.setup()
H.falsy(hydra:press("t"), "hydra should rebuild to drop an unregistered menu key")
H.falsy(popup.is_open(), "removed runtime hydra key should no longer open a popup")
H.truthy(hydra:press("f"), "base hydra key should still work after runtime unregister")
H.truthy(popup.is_open(), "base hydra key should still open after runtime unregister")

H.finish()
print("ok - tests/integration/hydra_runtime_menu_refresh.lua")
