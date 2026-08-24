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
        {
          label = "Sub&tools",
          key = "t",
          items = {
            { label = "&Nested", key = "n", action = function() end },
          },
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma", "delta" })
vim.cmd("normal! gg0")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = 1, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)
local function feed_click()
  vim.fn.feedkeys(vim.keycode("<LeftMouse>"), "xt")
  H.flush()
  H.flush()
end

popup.open_top(1)
mouse.screenrow = vim.o.lines - vim.o.cmdheight
mouse.screencol = state.label_positions[1] + 1
feed_click()
H.falsy(popup.is_open(), "clicking the active lualine label should close the popup")
H.eq(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "lualine clicks should not move the cursor")

popup.open_top(1)
local parent = state.menu_stack[1]
mouse.screenrow = parent.content_row + 1
mouse.screencol = parent.content_col + 1
feed_click()
H.eq(#state.menu_stack, 2, "clicking a submenu row should open its child popup")
H.eq(vim.api.nvim_win_get_cursor(0), { 1, 0 }, "submenu clicks should not move the cursor")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_sequence_ownership.lua")
