local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F14>",
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
      label = "&Edit",
      key = "e",
      items = {
        {
          label = "&Copy",
          key = "c",
          keys = "y",
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta" })
vim.cmd("normal! gg0lv2l")
H.eq(vim.fn.getreg('"'), "", "unnamed register should start empty")

vim.fn.feedkeys(vim.keycode("<F14>"), "xt")
H.flush()
H.flush()
H.eq(vim.fn.mode(), "n", "open key should leave visual mode")
H.truthy(state.menu_mode, "open key should enable menu mode from visual mode")
H.truthy(state.menu_context and state.menu_context.selection, "visual-origin copy should preserve selection context")

H.render_statusline()
layout.refresh_label_positions()
popup.activate_top_key("e")
H.truthy(popup.is_open(), "top key should open Edit popup")
popup.activate_item_key("c")
H.flush()
H.flush()

H.eq(vim.fn.getreg('"'), "lph", "visual-origin copy should yank the selected text")
H.eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "alpha", "beta" }, "copy should not modify the buffer")
H.falsy(state.menu_mode, "copy action should leave menu mode")
H.falsy(popup.is_open(), "copy action should close popups")

H.finish()
print("ok - tests/integration/visual_keys_copy.lua")
