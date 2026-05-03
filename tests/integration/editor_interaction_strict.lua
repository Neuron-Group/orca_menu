local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

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
        { label = "&Open", key = "o", action = function() end },
        { label = "&Save", key = "s", action = function() end },
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

local function is_visual_mode()
  local current = vim.fn.mode()
  return current == "v" or current == "V" or current == "\22"
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "alpha one",
  "beta two",
  "gamma three",
  "delta four",
})

vim.cmd("normal! gg0")
vim.api.nvim_feedkeys("j", "x", false)
H.flush()
H.eq(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "inactive normal-mode menu keys should keep native cursor motion")
H.falsy(state.menu_mode, "inactive normal-mode keys should not enable menu mode")
H.falsy(popup.is_open(), "inactive normal-mode keys should not open popup")

vim.cmd("normal! gg0v")
vim.api.nvim_feedkeys("j", "x", false)
H.flush()
H.truthy(is_visual_mode(), "inactive visual-mode menu keys should keep visual mode active")
H.eq(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "inactive visual-mode menu keys should keep native selection motion")
H.falsy(state.menu_mode, "inactive visual-mode keys should not enable menu mode")
H.falsy(popup.is_open(), "inactive visual-mode keys should not open popup")

vim.cmd("normal! gg0")
H.eq(vim.fn.maparg("f", "i", false, true), {}, "top-menu keys should stay unmapped in insert mode")
H.eq(vim.fn.maparg("o", "i", false, true), {}, "item keys should stay unmapped in insert mode")
H.eq(vim.fn.maparg("j", "i", false, true), {}, "navigation keys should stay unmapped in insert mode")
H.falsy(state.menu_mode, "insert-mode key availability checks should not enable menu mode")
H.falsy(popup.is_open(), "insert-mode key availability checks should not open popup")

popup.enter_menu_mode(1)
H.truthy(state.menu_mode, "enter_menu_mode should activate menu mode")
H.truthy(state.keymaps_installed, "enter_menu_mode should install menu keymaps")

local top_key = vim.fn.maparg("f", "n", false, true).callback
H.truthy(top_key, "active menu-mode top key should be mapped")
top_key()
H.flush()
H.truthy(popup.is_open(), "active menu-mode top key should open popup")
H.eq(state.active_top, 1, "active menu-mode top key should target the requested menu")
H.eq(#state.menu_stack, 1, "active menu-mode top key should create one popup level")

local down_key = vim.fn.maparg("j", "n", false, true).callback
H.truthy(down_key, "active menu-mode down key should be mapped")
down_key()
H.flush()
H.eq(state.menu_stack[1].selected, 2, "active menu-mode down key should move menu selection")

local close_key = vim.fn.maparg("q", "n", false, true).callback
H.truthy(close_key, "active menu-mode close key should be mapped")
close_key()
H.flush()
H.falsy(state.menu_mode, "close key should leave menu mode")
H.falsy(state.keymaps_installed, "close key should remove menu keymaps")
H.falsy(popup.is_open(), "close key should close the popup tree")

vim.cmd("normal! gg0")
vim.api.nvim_feedkeys("j", "x", false)
H.flush()
H.eq(vim.api.nvim_win_get_cursor(0), { 2, 0 }, "cursor motion should return immediately after menu close")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = 1, screencol = 1 }
local restore = H.stub_mouse(mouse)
H.eq(vim.fn.maparg("<LeftMouse>", "n", false, true), {}, "normal-mode left mouse should stay native while inactive")
H.eq(vim.fn.maparg("<LeftDrag>", "n", false, true), {}, "normal-mode left drag should stay native while inactive")
H.eq(vim.fn.maparg("<LeftRelease>", "n", false, true), {}, "normal-mode left release should stay native while inactive")

mouse.screenrow = vim.o.lines - vim.o.cmdheight
mouse.screencol = state.label_positions[1] + 1
_G.orca_menu_click_menu_1()
H.flush()
H.truthy(state.menu_mode, "mouse menu open should still work after repeated passthrough")
H.truthy(popup.is_open(), "popup should still open after repeated passthrough")
H.eq(state.active_top, 1, "mouse menu open after passthrough should target the first menu")

restore()
H.finish()
print("ok - tests/integration/editor_interaction_strict.lua")
