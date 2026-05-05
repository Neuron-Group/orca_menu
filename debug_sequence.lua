vim.g.orca_clipped_view_enabled = true
require("orca_menu").setup({
  enable_mouse = true,
  keys = { open = "<F13>" },
  menus = {
    { label = "&Help", key = "h", items = {{ label = "&About", key = "a", action = function() end }} },
    { label = "&View", key = "v", enabled = function() return vim.g.orca_clipped_view_enabled end, items = {{ label = "&Explorer", key = "e", action = function() end }} },
    { label = "&Search", key = "s", items = {{ label = "&Find", key = "f", action = function() end }} },
  },
})
local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")
vim.o.laststatus = 2
local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
vim.fn.getmousepos = function() return mouse end

local function eval()
  local ok, v = pcall(vim.api.nvim_eval_statusline, vim.wo.statusline, { winid = vim.api.nvim_get_current_win(), maxwidth = vim.o.columns, highlights = false, use_winbar = false })
  print('statusline raw', vim.wo.statusline)
  print('statusline eval ok', ok, v and v.str)
end

local function render_clipped_topbar()
  local view_label = layout.top_bar_display_label(state.config.menus[2], 2)
  local search_label = layout.top_bar_display_label(state.config.menus[3], 3)
  local clipped_view = view_label:sub(2)
  vim.wo.statusline = string.format(" %s %s ", clipped_view, search_label)
  eval()
  layout.refresh_label_positions()
  local rendered = vim.api.nvim_eval_statusline(vim.wo.statusline, { winid = vim.api.nvim_get_current_win(), maxwidth = vim.o.columns, highlights = false, use_winbar = false }).str
  local clipped_col = assert(rendered:find(clipped_view, 1, true)) + 1
  local search_col = assert(rendered:find(search_label, 1, true)) + 1
  return clipped_col, search_col
end

local clipped_col, search_col = render_clipped_topbar()
mouse.screencol = clipped_col
_G.orca_menu_click_menu_2()
vim.wait(20, function() return false end, 1)
eval()
print('hit search post clipped', layout.label_hit_at_col(search_col))
mouse.screencol = search_col
_G.orca_menu_click_menu_3()
vim.wait(20, function() return false end, 1)
print('after search callback', popup.is_open(), state.menu_mode, state.active_top, #state.menu_stack)
