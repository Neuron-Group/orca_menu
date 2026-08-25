local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = false,
  lualine = {
    section = "y",
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
  },
})

local lualine = require("lualine")
local layout = require("orca_menu.layout")
local state = require("orca_menu.state")

vim.o.laststatus = 3
lualine.refresh({ force = true, scope = "all", place = { "statusline" } })

local global_host = vim.api.nvim_get_current_win()
local global_buf = vim.api.nvim_create_buf(false, true)
local global_float = vim.api.nvim_open_win(global_buf, true, {
  relative = "editor",
  row = 2,
  col = 4,
  width = 20,
  height = 4,
  focusable = true,
})
local global_position = assert(lualine.get_component_positions({
  place = "statusline",
  winid = global_float,
})["orca_menu:1"])
H.eq(global_position.screen.row, vim.o.lines - vim.o.cmdheight, "global statusline geometry should keep its screen row through a float")
H.eq(global_position.winid, global_host, "global statusline geometry should retain its normal render window")

layout.refresh_label_positions(global_float)
local global_mouse = {
  screenrow = global_position.screen.row,
  screencol = global_position.screen.start_col + 1,
  winid = global_float,
}
H.eq(layout.label_hit_at_col(global_mouse.screencol, global_mouse), 1, "global topbar clicks should hit through a float window")
vim.api.nvim_win_close(global_float, true)
vim.api.nvim_buf_delete(global_buf, { force = true })

vim.o.laststatus = 2
vim.cmd("vsplit")
local local_host = vim.api.nvim_get_current_win()
local host_screen = vim.fn.win_screenpos(local_host)
lualine.refresh({ force = true, scope = "all", place = { "statusline" } })

local local_buf = vim.api.nvim_create_buf(false, true)
local local_float = vim.api.nvim_open_win(local_buf, true, {
  relative = "editor",
  row = host_screen[1] - 1 + 2,
  col = host_screen[2] - 1 + 2,
  width = math.max(math.min(20, vim.api.nvim_win_get_width(local_host) - 4), 1),
  height = 4,
  focusable = true,
})
local local_position = assert(lualine.get_component_positions({
  place = "statusline",
  winid = local_float,
})["orca_menu:1"])
local host_position = assert(lualine.get_component_positions({
  place = "statusline",
  winid = local_host,
})["orca_menu:1"])
H.eq(local_position.winid, local_host, "local statusline geometry should resolve a float to its underlying window")
H.eq(local_position.screen, host_position.screen, "float queries should reuse the underlying statusline geometry")

layout.refresh_label_positions(local_float)
H.eq(state.component_positions[1].winid, local_host, "Orca should retain lualine's underlying render window")
local local_mouse = {
  screenrow = local_position.screen.row,
  screencol = local_position.screen.start_col + 1,
  winid = local_float,
}
H.eq(layout.label_hit_at_col(local_mouse.screencol, local_mouse), 1, "local topbar clicks should hit through a float window")

local anchor = layout.resolve_anchor(1, state.config.menus[1].items)
H.truthy(anchor.col <= vim.api.nvim_win_get_width(local_host), "anchor should stay within the underlying window")
local label = layout.top_bar_display_label(state.config.menus[1], 1)
local spacing_width = vim.fn.strdisplaywidth(state.config.lualine.spacing or " ")
local right_anchor = host_position.screen.start_col
  + spacing_width
  + vim.fn.strdisplaywidth(label)
  - 1
local popup_width = layout.submenu_width(state.config.menus[1].items)
local expected_col = math.max(
  math.min(right_anchor - popup_width + 1 - 3, vim.o.columns - popup_width + 1),
  1
)
H.eq(anchor.col, expected_col, "anchor should use lualine's editor-screen component geometry")

vim.api.nvim_win_close(local_float, true)
vim.api.nvim_buf_delete(local_buf, { force = true })
H.finish()
print("ok - tests/integration/lualine_popup_geometry.lua")
