local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

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
        { label = "&About", key = "a", action = function() end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Explorer", key = "e", action = function() end },
      },
    },
    {
      label = "&Search",
      key = "s",
      items = {
        { label = "&Find", key = "f", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

vim.o.laststatus = 2

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

  return assert(rendered:find(clipped_view, 1, true), "expected clipped View fragment in statusline") + 1
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
vim.cmd("normal! gg0v$")
H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "test should enter visual mode")

local mouse = {
  screenrow = vim.o.lines - vim.o.cmdheight,
  screencol = render_clipped_topbar(),
}
local restore_mouse = H.stub_mouse(mouse)

_G.orca_menu_click_menu_2()
H.flush()
H.flush()

H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "clipped top-bar fragment click should not leave visual mode")
H.falsy(state.menu_mode, "clipped top-bar fragment click should not enter menu mode")
H.falsy(popup.is_open(), "clipped top-bar fragment click should not open popup")
H.falsy(state.menu_context and state.menu_context.selection, "clipped top-bar fragment click should not preserve Orca selection context")

restore_mouse()
H.finish()
print("ok - tests/integration/visual_clipped_top_click.lua")
