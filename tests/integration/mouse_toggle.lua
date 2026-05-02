local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local input = require("orca_menu.input")
local state = require("orca_menu.state")

state.config = {
  enable_mouse = true,
  keys = {
    next = {},
    prev = {},
    down = {},
    up = {},
    select = {},
    back = {},
    close = {},
    mode_backend = "builtin",
  },
  menus = {},
}

input.install_mouse()
H.truthy(vim.fn.maparg("<LeftMouse>", "n", false, true).callback, "mouse bindings should be installed when enabled")
H.truthy(vim.fn.maparg("<2-LeftMouse>", "n", false, true).callback, "double-click mouse bindings should be installed when enabled")
H.truthy(vim.fn.maparg("<LeftRelease>", "n", false, true).callback, "release mouse bindings should be installed when enabled")
H.truthy(vim.fn.maparg("<2-LeftRelease>", "n", false, true).callback, "double-release bindings should be installed when enabled")
H.truthy(vim.fn.maparg("<2-LeftDrag>", "n", false, true).callback, "double-drag bindings should be installed when enabled")

state.config.enable_mouse = false
input.install_mouse()
H.eq(vim.fn.maparg("<LeftMouse>", "n", false, true), {}, "mouse bindings should be removed when disabled")
H.eq(vim.fn.maparg("<2-LeftMouse>", "n", false, true), {}, "double-click mouse bindings should be removed when disabled")
H.eq(vim.fn.maparg("<LeftRelease>", "n", false, true), {}, "release mouse bindings should be removed when disabled")
H.eq(vim.fn.maparg("<2-LeftRelease>", "n", false, true), {}, "double-release bindings should be removed when disabled")
H.eq(vim.fn.maparg("<2-LeftDrag>", "n", false, true), {}, "double-drag bindings should be removed when disabled")

print("ok - tests/integration/mouse_toggle.lua")
