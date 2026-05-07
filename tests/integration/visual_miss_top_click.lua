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
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Tree", key = "t", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

local function top_col(index)
  layout.refresh_label_positions()
  return state.label_positions[index] + 1
end

H.render_statusline()
layout.refresh_label_positions()

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
vim.cmd("normal! gg0v$")
H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "test should enter visual mode")

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = top_col(3) }
local restore_mouse = H.stub_mouse(mouse)

_G.orca_menu_click_menu_2()
H.flush()
H.flush()

H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "mismatched top-bar click should not leave visual mode")
H.falsy(state.menu_mode, "mismatched top-bar click should not enter menu mode")
H.falsy(popup.is_open(), "mismatched top-bar click should not open popup")
H.falsy(state.menu_context and state.menu_context.selection, "mismatched top-bar click should not preserve Orca selection context")

restore_mouse()
H.finish()
print("ok - tests/integration/visual_miss_top_click.lua")
