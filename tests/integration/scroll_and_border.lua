local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local items = {}
for index = 1, 10 do
  table.insert(items, {
    label = string.format("Item %d", index),
    key = tostring(index % 10),
    action = function() end,
  })
end

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    mode_backend = "builtin",
  },
  submenu = {
    border = "rounded",
    min_width = 18,
    scroll_indicator_up = "↑",
    scroll_indicator_down = "↓",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = items,
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

vim.o.lines = 10
H.render_statusline()

require("orca_menu").open_menu(1)

local entry = state.menu_stack[1]
H.truthy(entry.visible_height < #entry.items, "test menu should be tall enough to scroll")

local initial_border = vim.api.nvim_win_get_config(entry.win).border
H.eq(initial_border[5], "↓", "initial border should show only the down scroll indicator")
H.eq(initial_border[3], "╮", "initial border should keep the top-right corner when nothing is hidden above")

local restore = H.stub_mouse({
  screenrow = entry.content_row,
  screencol = entry.content_col,
})

local step = entry.visible_height - 1
popup.scroll_at_mouse(1)

entry = state.menu_stack[1]
H.eq(entry.selected, 1 + step, "mouse wheel should advance by nearly a full visible page")

popup.scroll_at_mouse(1)
entry = state.menu_stack[1]
H.truthy(entry.scroll_top > 1, "repeated wheel scroll should advance the visible window")

local scrolled_border = vim.api.nvim_win_get_config(entry.win).border
H.eq(scrolled_border[3], "↑", "scrolled border should show hidden rows above")

popup.scroll_at_mouse(-1)
entry = state.menu_stack[1]
H.truthy(entry.selected < #entry.items, "reverse wheel scroll should move selection upward")

restore()
H.finish()
print("ok - tests/integration/scroll_and_border.lua")

