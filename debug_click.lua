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
local view_label = layout.top_bar_display_label(state.config.menus[2], 2)
local search_label = layout.top_bar_display_label(state.config.menus[3], 3)
local clipped_view = view_label:sub(2)
vim.wo.statusline = string.format(" %s %s ", clipped_view, search_label)
local rendered = vim.api.nvim_eval_statusline(vim.wo.statusline, { winid = vim.api.nvim_get_current_win(), maxwidth = vim.o.columns, highlights = false, use_winbar = false }).str
local search_col = assert(rendered:find(search_label,1,true)) + 1
vim.fn.getmousepos = function() return { screenrow = vim.o.lines - vim.o.cmdheight, screencol = search_col } end
print('before', popup.is_open(), state.menu_mode, state.active_top)
_G.orca_menu_click_menu_3()
vim.wait(20, function() return false end, 1)
print('after', popup.is_open(), state.menu_mode, state.active_top)
print('stack', #state.menu_stack)
