local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

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
        { label = "&Open", key = "o", action = function() end },
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
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

for _, mode in ipairs({ "n", "x", "i" }) do
  H.eq(vim.fn.maparg("<LeftMouse>", mode, false, true), {}, "inactive left mouse should stay native in mode " .. mode)
end

for _, mode in ipairs({ "n", "x", "i" }) do
  H.eq(vim.fn.maparg("<LeftDrag>", mode, false, true), {}, "inactive left drag should stay native in mode " .. mode)
  H.eq(vim.fn.maparg("<LeftRelease>", mode, false, true), {}, "inactive left release should stay native in mode " .. mode)
end

for _, mode in ipairs({ "n", "i" }) do
  H.eq(vim.fn.maparg("<ScrollWheelDown>", mode, false, true), {}, "inactive wheel down should stay native in mode " .. mode)
  H.eq(vim.fn.maparg("<ScrollWheelUp>", mode, false, true), {}, "inactive wheel up should stay native in mode " .. mode)
end

H.truthy(_G.orca_menu_click_menu_1, "top-bar click handler should exist")
_G.orca_menu_click_menu_1()
H.flush()
H.truthy(state.menu_mode, "top-bar click handler should enable menu mode")
H.truthy(popup.is_open(), "top-bar click handler should open popup")

for _, mode in ipairs({ "n", "x", "i" }) do
  H.truthy(vim.fn.maparg("<LeftMouse>", mode, false, true).callback, "active popup should install left mouse handling in mode " .. mode)
end

for _, mode in ipairs({ "n", "i" }) do
  H.truthy(vim.fn.maparg("<LeftDrag>", mode, false, true).callback, "active popup should install left drag handling in mode " .. mode)
  H.truthy(vim.fn.maparg("<LeftRelease>", mode, false, true).callback, "active popup should install left release handling in mode " .. mode)
  H.truthy(vim.fn.maparg("<ScrollWheelDown>", mode, false, true).callback, "active popup should install wheel down handling in mode " .. mode)
  H.truthy(vim.fn.maparg("<ScrollWheelUp>", mode, false, true).callback, "active popup should install wheel up handling in mode " .. mode)
end

popup.close_all()
H.flush()

for _, mode in ipairs({ "n", "x", "i" }) do
  H.eq(vim.fn.maparg("<LeftMouse>", mode, false, true), {}, "left mouse should be removed after popup closes in mode " .. mode)
end

for _, mode in ipairs({ "n", "x", "i" }) do
  H.eq(vim.fn.maparg("<LeftDrag>", mode, false, true), {}, "left drag should be removed after popup closes in mode " .. mode)
  H.eq(vim.fn.maparg("<LeftRelease>", mode, false, true), {}, "left release should be removed after popup closes in mode " .. mode)
end

for _, mode in ipairs({ "n", "i" }) do
  H.eq(vim.fn.maparg("<ScrollWheelDown>", mode, false, true), {}, "wheel down should be removed after popup closes in mode " .. mode)
  H.eq(vim.fn.maparg("<ScrollWheelUp>", mode, false, true), {}, "wheel up should be removed after popup closes in mode " .. mode)
end

H.finish()
print("ok - tests/integration/mouse_scope.lua")
