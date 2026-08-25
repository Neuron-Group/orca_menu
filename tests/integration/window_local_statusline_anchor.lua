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

vim.cmd("set columns=140")

local layout = require("orca_menu.layout")
local state = require("orca_menu.state")
local lualine = require("lualine")

local left_win = vim.api.nvim_get_current_win()
vim.cmd("vsplit")
local right_win = vim.api.nvim_get_current_win()

local total_width = vim.api.nvim_win_get_width(left_win) + vim.api.nvim_win_get_width(right_win) + 1
local left_width = math.max(math.floor(total_width / 2), 28)
vim.api.nvim_win_set_width(left_win, left_width)
vim.api.nvim_win_set_width(right_win, math.max(total_width - left_width - 1, 1))

vim.api.nvim_set_current_win(right_win)
lualine.refresh({ force = true, scope = "all", place = { "statusline" } })

vim.api.nvim_set_current_win(left_win)
layout.refresh_label_positions()

local search_label = layout.top_bar_display_label(state.config.menus[2], 2)
local positions = lualine.get_component_positions({ winid = left_win })
local position = assert(positions["orca_menu:2"], "expected Search component position in left split statusline")
H.truthy(position.screen, "expected Search component to be visible in the left split statusline")
local expected_col = position.screen.start_col + vim.fn.strdisplaywidth(state.config.lualine.spacing or " ")

H.eq(state.label_positions[2], expected_col, "label positions should be computed against the current window width")

local popup_width = layout.submenu_width(state.config.menus[2].items)
local anchor = layout.resolve_anchor(2, state.config.menus[2].items)
H.truthy(anchor.col >= 1 and anchor.col + popup_width - 1 <= vim.o.columns, "popup anchor should stay within the editor screen")
local relative_label_col = expected_col
H.eq(anchor.col, math.max(
  math.min(relative_label_col + vim.fn.strdisplaywidth(search_label) - popup_width - 3, vim.o.columns - popup_width + 1),
  1
), "popup anchor should follow the label rendered in the active split")

H.finish()
print("ok - tests/integration/window_local_statusline_anchor.lua")
