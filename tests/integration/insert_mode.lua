local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_insert_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    mode_backend = "builtin",
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
          label = "Sub&tools",
          key = "t",
          items = {
            { label = "&Nested", key = "n", action = function() end },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_insert_action = vim.g.orca_insert_action + 1
          end,
        },
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

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "", "beta", "gamma" })
vim.cmd("normal! gg0")

local open_key = vim.fn.maparg("<F13>", "i", false, true).callback
H.truthy(open_key, "open key should be mapped in insert mode")

vim.api.nvim_feedkeys("i" .. vim.keycode("<F13>"), "x", false)
H.flush()
H.truthy(state.menu_mode, "actual open key from insert mode should enable menu mode")
H.falsy(popup.is_open(), "actual open key from insert mode should not open popup immediately")

popup.close_all()

open_key()
H.flush()
H.truthy(state.menu_mode, "callback open key from insert mode should enable menu mode")
H.falsy(popup.is_open(), "callback open key from insert mode should not open popup immediately")

H.render_statusline()
layout.refresh_label_positions()
popup.activate_top_key("f")
H.truthy(popup.is_open(), "top key should open popup after insert-mode entry")
popup.activate_item_key("o")
H.flush()
H.eq(vim.g.orca_insert_action, 1, "action should execute after opening from insert mode")
H.falsy(state.menu_mode, "action should leave menu mode after insert-mode entry")

H.render_statusline()
layout.refresh_label_positions()
vim.cmd("normal! gg0")
local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = state.label_positions[1] + 1 }
local restore = H.stub_mouse(mouse)
local left_mouse = vim.fn.maparg("<LeftMouse>", "i", false, true).callback
H.truthy(left_mouse, "left mouse should be mapped in insert mode")
left_mouse()
H.flush()
H.truthy(state.menu_mode, "mouse top-bar open from insert mode should enable menu mode")
H.truthy(popup.is_open(), "mouse top-bar open from insert mode should open popup")

popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "submenu hotkey should work after mouse open from insert mode")
popup.go_back()
H.eq(#state.menu_stack, 1, "go_back should close child submenu after insert-mode mouse open")

mouse.screencol = state.label_positions[1] + 1
left_mouse()
H.falsy(popup.is_open(), "mouse click on active top menu should close popup from insert-origin flow")
H.falsy(state.menu_mode, "mouse click on active top menu should leave menu mode from insert-origin flow")

restore()

H.eq(vim.fn.maparg("f", "i", false, true), {}, "top-menu keys should not be mapped in insert mode")
H.eq(vim.fn.maparg("t", "i", false, true), {}, "submenu item keys should not be mapped in insert mode")
H.eq(vim.fn.maparg("o", "i", false, true), {}, "action item keys should not be mapped in insert mode")

H.finish()
print("ok - tests/integration/insert_mode.lua")
