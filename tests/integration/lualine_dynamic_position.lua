local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.o.columns = 80
vim.o.laststatus = 2
vim.cmd("vsplit")

local lualine = require("lualine")
lualine.setup({
  options = {
    globalstatus = false,
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = { "filename" },
    lualine_x = { "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

require("orca_menu").setup({
  enable_mouse = false,
  lualine = {
    section = "y",
    spacing = " ",
  },
  menus = {
    { label = "&Help", key = "h", items = { { label = "&About", key = "a", action = function() end } } },
    { label = "&Tools", key = "t", items = { { label = "&Tool", key = "t", action = function() end } } },
    { label = "&LSP", key = "p", items = { { label = "&Lsp", key = "l", action = function() end } } },
    { label = "&View", key = "v", items = { { label = "&View", key = "v", action = function() end } } },
    { label = "&Search", key = "s", items = { { label = "&Search", key = "s", action = function() end } } },
    { label = "&Edit", key = "e", items = { { label = "&Edit", key = "e", action = function() end } } },
    { label = "&File", key = "f", items = { { label = "&File", key = "f", action = function() end } } },
  },
})

local layout = require("orca_menu.layout")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
layout.refresh_label_positions()

local positions = lualine.get_component_positions({ place = "statusline" })
local evaluated = vim.api.nvim_eval_statusline(vim.wo.statusline, {
  winid = vim.api.nvim_get_current_win(),
  maxwidth = vim.api.nvim_win_get_width(0),
})
local visible_count = 0
for index, menu in ipairs(state.config.menus) do
  local position = assert(positions["orca_menu:" .. index])
  local label = layout.top_bar_display_label(menu, index)
  local label_start = evaluated.str:find(label, 1, true)
  if label_start then
    visible_count = visible_count + 1
    H.eq(state.label_positions[index], position.screen.start_col, "visible labels should use lualine screen geometry")
  else
    H.falsy(position.visible, "clipped components should not be reported as visible")
    H.falsy(position.screen, "clipped components should not expose screen geometry")
    H.falsy(state.label_positions[index], "clipped components should not enter Orca's hitbox cache")
  end
end
H.truthy(visible_count > 0, "the narrow statusline should retain visible Orca components")

local target = 7
H.truthy(state.label_positions[target], "the final visible menu should have a measured position")
popup.open_top(target)
H.truthy(popup.is_open(), "opening a measured top menu should create its popup")

local target_position = lualine.get_component_positions({ place = "statusline" })["orca_menu:" .. target]
local popup_width = layout.submenu_width(state.config.menus[target].items)
H.eq(
  state.anchor.col,
  H.expected_popup_anchor(target_position, popup_width, state.config.submenu.border),
  "opening should anchor from the freshly measured component"
)

H.finish()
print("ok - tests/integration/lualine_dynamic_position.lua")
