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
local layout = require("orca_menu.layout")
vim.o.laststatus = 2
local view_label = layout.top_bar_display_label(state.config.menus[2], 2)
local search_label = layout.top_bar_display_label(state.config.menus[3], 3)
local clipped_view = view_label:sub(2)
vim.wo.statusline = string.format(" %s %s ", clipped_view, search_label)
local rendered = vim.api.nvim_eval_statusline(vim.wo.statusline, { winid = vim.api.nvim_get_current_win(), maxwidth = vim.o.columns, highlights = false, use_winbar = false }).str
print('rendered=[' .. rendered .. ']')
print('view=['..view_label..'] search=['..search_label..'] clipped=['..clipped_view..']')
print('find clipped', rendered:find(clipped_view,1,true))
print('find search', rendered:find(search_label,1,true))
local original = vim.fn.getmousepos
vim.fn.getmousepos = function() return { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 } end
layout.refresh_label_positions()
print('positions', vim.inspect(state.label_positions))
vim.fn.getmousepos = function() return { screenrow = vim.o.lines - vim.o.cmdheight, screencol = (rendered:find(clipped_view,1,true) or 0)+1 } end
print('hit clipped', layout.label_hit_at_col((rendered:find(clipped_view,1,true) or 0)+1))
vim.fn.getmousepos = function() return { screenrow = vim.o.lines - vim.o.cmdheight, screencol = (rendered:find(search_label,1,true) or 0)+1 } end
print('hit search', layout.label_hit_at_col((rendered:find(search_label,1,true) or 0)+1))
vim.fn.getmousepos = original
