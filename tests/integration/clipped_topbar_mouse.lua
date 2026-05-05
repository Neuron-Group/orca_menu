local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_clipped_topbar_action = 0
vim.g.orca_clipped_view_enabled = true

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
            vim.g.orca_clipped_topbar_action = vim.g.orca_clipped_topbar_action + 1
          end,
        },
      },
    },
    {
      label = "&View",
      key = "v",
      enabled = function()
        return vim.g.orca_clipped_view_enabled
      end,
      items = {
        {
          label = "&Explorer",
          key = "e",
          action = function()
            vim.g.orca_clipped_topbar_action = vim.g.orca_clipped_topbar_action + 10
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
            vim.g.orca_clipped_topbar_action = vim.g.orca_clipped_topbar_action + 100
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

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function render_clipped_topbar()
  local view_label = layout.top_bar_display_label(state.config.menus[2], 2)
  local search_label = layout.top_bar_display_label(state.config.menus[3], 3)
  local clipped_view = view_label:sub(2)

  vim.wo.statusline = string.format(" %s %s ", clipped_view, search_label)
  layout.refresh_label_positions()

  local rendered = vim.api.nvim_eval_statusline(vim.wo.statusline, {
    winid = vim.api.nvim_get_current_win(),
    maxwidth = vim.o.columns,
    highlights = false,
    use_winbar = false,
  }).str

  local clipped_col = assert(rendered:find(clipped_view, 1, true), "expected clipped View fragment in statusline") + 1
  local search_col = assert(rendered:find(search_label, 1, true), "expected Search label in statusline") + 1
  return clipped_col, search_col
end

local clipped_col, search_col = render_clipped_topbar()

mouse.screencol = clipped_col
_G.orca_menu_click_menu_2()
H.flush()
H.falsy(popup.is_open(), "clicking a clipped visible fragment should not open its menu")
H.falsy(state.menu_mode, "clicking a clipped visible fragment should not enter menu mode")

clipped_col, search_col = render_clipped_topbar()
mouse.screencol = search_col
_G.orca_menu_click_menu_3()
H.flush()
H.truthy(popup.is_open(), "clicking a fully visible top label should still open its menu")
H.eq(state.active_top, 3, "visible top-label clicks should keep targeting the clicked menu")
popup.close_all()
H.flush()

vim.g.orca_clipped_view_enabled = false
require("orca_menu").refresh()
clipped_col, search_col = render_clipped_topbar()

mouse.screencol = clipped_col
_G.orca_menu_click_menu_2()
H.flush()
H.falsy(popup.is_open(), "clicking a clipped disabled label should do nothing")
H.falsy(state.menu_mode, "clipped disabled labels should not enter menu mode")
H.eq(vim.g.orca_clipped_topbar_action, 0, "clipped disabled label clicks should not trigger any action behind them")

clipped_col, search_col = render_clipped_topbar()
mouse.screencol = search_col
_G.orca_menu_click_menu_3()
H.flush()
H.truthy(popup.is_open(), "visible labels should remain clickable after disabled clipping")
H.eq(state.active_top, 3, "visible label targeting should remain stable after disabled clipping")

restore_mouse()
H.finish()
print("ok - tests/integration/clipped_topbar_mouse.lua")
