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
    {
      label = "&Search",
      key = "s",
      items = {
        { label = "&Grep", key = "g", action = function() end },
      },
    },
  },
})

local lualine = require("lualine")
local layout = require("orca_menu.layout")
local state = require("orca_menu.state")

H.render_statusline()

local positions = lualine.get_component_positions({ place = "statusline" })
local first = assert(positions["orca_menu:1"], "first Orca component should expose a position")
local second = assert(positions["orca_menu:2"], "second Orca component should expose a position")

H.truthy(first.logical.start_col < first.logical.end_col, "logical component span should have positive width")
H.truthy(second.logical.start_col > first.logical.end_col, "logical spans should follow section order")
H.truthy(first.visible and first.screen, "visible component should expose a screen span")
H.truthy(second.visible and second.screen, "second visible component should expose a screen span")
H.eq(first.screen.row, vim.o.lines - vim.o.cmdheight, "screen span should expose the statusline row")
H.eq(lualine.get_component_positions({ component_id = "orca_menu:1" }).id, "orca_menu:1", "single-component lookup should work")
H.eq(state.label_positions[1], first.screen.start_col + 1, "Orca label cache should derive from lualine screen geometry")
H.eq(layout.is_top_visible(2), true, "Orca visibility should derive from lualine position metadata")

local evaluated = vim.api.nvim_eval_statusline(vim.wo.statusline, {
  winid = vim.api.nvim_get_current_win(),
  maxwidth = vim.api.nvim_win_get_width(0),
})
for index, menu in ipairs(state.config.menus) do
  local label = layout.top_bar_display_label(menu, index)
  local label_start = assert(evaluated.str:find(label, 1, true), "rendered label should be present")
  local rendered_col = vim.fn.strdisplaywidth(evaluated.str:sub(1, label_start - 1)) + 1
  H.eq(state.label_positions[index], rendered_col, "label position should match final rendered statusline")
end

H.finish()
print("ok - tests/integration/lualine_component_positions.lua")
