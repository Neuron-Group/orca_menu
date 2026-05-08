local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_extreme_narrow_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&Help",
      key = "h",
      items = {
        {
          label = "&About",
          key = "a",
          action = function()
            vim.g.orca_extreme_narrow_action = vim.g.orca_extreme_narrow_action + 1
          end,
        },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        {
          label = "&Explorer",
          key = "e",
          action = function()
            vim.g.orca_extreme_narrow_action = vim.g.orca_extreme_narrow_action + 10
          end,
        },
      },
    },
    {
      label = "&Search",
      key = "s",
      items = {
        {
          label = "&Find",
          key = "f",
          action = function()
            vim.g.orca_extreme_narrow_action = vim.g.orca_extreme_narrow_action + 100
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

vim.o.laststatus = 2

local function eval_statusline()
  return vim.api.nvim_eval_statusline(vim.wo.statusline, {
    winid = vim.api.nvim_get_current_win(),
    maxwidth = vim.o.columns,
    highlights = false,
    use_winbar = false,
  }).str
end

local function render_half_eaten_tail()
  local search_label = layout.top_bar_display_label(state.config.menus[3], 3)
  local clipped_tail = search_label:sub(1, math.max(#search_label - 1, 1))
  vim.wo.statusline = string.format(" %s", clipped_tail)
  layout.refresh_label_positions()
  local rendered = eval_statusline()
  local hit_col = assert(rendered:find(clipped_tail, 1, true), "expected clipped tail fragment in statusline") + 1
  return hit_col
end

local function render_all_eaten_padding_only()
  vim.wo.statusline = string.rep(" ", 12)
  layout.refresh_label_positions()
end

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local half_eaten_col = render_half_eaten_tail()
mouse.screencol = half_eaten_col
_G.orca_menu_click_menu_3()
H.flush()
H.falsy(popup.is_open(), "half-eaten last top item should not open from mouse click")
H.falsy(state.menu_mode, "half-eaten last top item should not enter menu mode from mouse click")

render_half_eaten_tail()
H.falsy(popup.activate_top_key("s"), "half-eaten last top item should not open from hotkey")
H.falsy(popup.is_open(), "half-eaten last top item hotkey should leave popup closed")

render_all_eaten_padding_only()
mouse.screencol = 1
H.falsy(popup.activate_top_key("s"), "fully eaten top items should not open from hotkey")
H.falsy(popup.is_open(), "fully eaten top items should keep popup closed")

restore_mouse()
H.finish()
print("ok - tests/integration/extreme_narrow_topbar_activation.lua")
