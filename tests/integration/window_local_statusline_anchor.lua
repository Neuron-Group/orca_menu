local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = false,
  lualine = {
    spacing = " ",
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
      label = "&Search",
      key = "s",
      items = {
        { label = "&Grep", key = "g", action = function() end },
        { label = "&Buffers", key = "b", action = function() end },
      },
    },
  },
})

local layout = require("orca_menu.layout")
local state = require("orca_menu.state")
local lualine = require("orca_menu.lualine")

local left_win = vim.api.nvim_get_current_win()
vim.cmd("vsplit")
local right_win = vim.api.nvim_get_current_win()

vim.api.nvim_win_set_width(left_win, 28)
vim.api.nvim_win_set_width(right_win, 90)

local function set_window_statusline(winid)
  vim.api.nvim_set_current_win(winid)
  vim.wo.statusline = table.concat({
    "%=",
    lualine.component_at(1),
    lualine.component_at(2),
  }, "")
end

set_window_statusline(left_win)
set_window_statusline(right_win)

vim.api.nvim_set_current_win(left_win)
layout.refresh_label_positions()

local rendered = vim.api.nvim_eval_statusline(vim.wo.statusline, {
  winid = left_win,
  maxwidth = vim.api.nvim_win_get_width(left_win),
  highlights = false,
  use_winbar = false,
}).str

local search_label = layout.top_bar_display_label(state.config.menus[2], 2)
local expected_col = assert(rendered:find(search_label, 1, true), "expected Search label in left split statusline")

H.eq(state.label_positions[2], expected_col, "label positions should be computed against the current window width")

local popup_width = layout.submenu_width(state.config.menus[2].items)
local anchor = layout.resolve_anchor(2, state.config.menus[2].items)
H.truthy(anchor.col <= vim.api.nvim_win_get_width(left_win), "popup anchor should stay within the narrow current window")
H.eq(anchor.col, math.max(expected_col + vim.fn.strdisplaywidth(search_label) - popup_width - 3, 1), "popup anchor should follow the label rendered in the active narrow split")

H.finish()
print("ok - tests/integration/window_local_statusline_anchor.lua")
