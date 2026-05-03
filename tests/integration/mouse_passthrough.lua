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
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
local mouse = { screenrow = 1, screencol = 1 }
local restore = H.stub_mouse(mouse)

local left_mouse = vim.fn.maparg("<LeftMouse>", "x", false, true).callback
local left_drag = vim.fn.maparg("<LeftDrag>", "x", false, true).callback
local left_release = vim.fn.maparg("<LeftRelease>", "x", false, true).callback

H.truthy(left_mouse, "left mouse should be mapped in visual mode")
H.truthy(left_drag, "left drag should be mapped in visual mode")
H.truthy(left_release, "left release should be mapped in visual mode")

vim.cmd("normal! gg0v$")
left_mouse()
H.flush()
H.falsy(state.menu_mode, "outside left click should not enable menu mode")
H.falsy(popup.is_open(), "outside left click should not open popup")

vim.cmd("normal! gg0v$")
left_drag()
H.flush()
H.falsy(state.menu_mode, "left drag should not enable menu mode")
H.falsy(popup.is_open(), "left drag should not open popup")

vim.cmd("normal! gg0v$")
left_release()
H.flush()
H.falsy(state.menu_mode, "left release should not enable menu mode")
H.falsy(popup.is_open(), "left release should not open popup")

restore()
H.finish()
print("ok - tests/integration/mouse_passthrough.lua")
