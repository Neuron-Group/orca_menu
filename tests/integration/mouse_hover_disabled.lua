local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.o.mousemoveevent = false

require("orca_menu").setup({
  enable_mouse = false,
  keys = {
    open = "<F13>",
  },
  submenu = {
    hover_select = true,
    hover_topbar = true,
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

local popup = require("orca_menu.popup")

H.eq(vim.fn.maparg("<MouseMove>", "n", false, true), {}, "hover mapping should stay absent when mouse support is disabled")
H.falsy(vim.o.mousemoveevent, "disabled mouse support should not enable mousemoveevent during setup")

popup.open_top(1)
H.eq(vim.fn.maparg("<MouseMove>", "n", false, true), {}, "opening a popup should still not install hover mapping when mouse support is disabled")
H.falsy(vim.o.mousemoveevent, "opening a popup should not enable mousemoveevent when mouse support is disabled")

popup.close_all()
H.falsy(vim.o.mousemoveevent, "closing a popup should leave mousemoveevent unchanged when mouse support is disabled")

H.finish()
print("ok - tests/integration/mouse_hover_disabled.lua")
