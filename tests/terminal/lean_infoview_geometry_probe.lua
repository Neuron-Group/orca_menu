local outfile = vim.env.ORCA_TERMINAL_RESULT

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.o.laststatus = 2
vim.o.mouse = "a"
vim.g.mapleader = " "
vim.g.lean_config = {
  infoview = {
    autoopen = false,
    update_cooldown = 0,
  },
  lsp = { enable = false },
}

require("lean").setup()
vim.cmd.edit(vim.env.ORCA_LEAN_FILE)
vim.bo.filetype = "lean"
local infoview = require("lean.infoview")
local iv = infoview.open()
iv:reposition()
iv:enter()

require("orca_menu").setup({
  enable_mouse = false,
  lualine = {
    section = "a",
    spacing = " ",
  },
  menus = {
    {
      label = "&Search",
      key = "s",
      items = {
        { label = "&Search", key = "s", action = function() end },
      },
    },
  },
})

local layout = require("orca_menu.layout")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")
local lualine = require("lualine")

local main_win = iv.last_window.id
local infoview_win = iv.window.id
vim.api.nvim_set_current_win(infoview_win)
lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
layout.refresh_label_positions(infoview_win)

local position = assert(lualine.get_component_positions({
  place = "statusline",
  winid = infoview_win,
})["orca_menu:1"])
local popup_width = layout.submenu_width(state.config.menus[1].items)
local expected_col = math.max(
  math.min(position.screen.end_col - popup_width + 1 - 3, vim.o.columns - popup_width + 1),
  1
)

popup.open_top(1)
local popup_win = state.windows[1]
local actual_screen = vim.fn.win_screenpos(popup_win)
local actual = {
  status = "ok",
  main_win = main_win,
  infoview_win = infoview_win,
  owner_win = state.menu_owner_win,
  current_win = vim.api.nvim_get_current_win(),
  infoview_config = vim.api.nvim_win_get_config(infoview_win),
  infoview_screen = vim.fn.win_screenpos(infoview_win),
  component = position,
  popup_width = popup_width,
  anchor = vim.deepcopy(state.anchor),
  popup_screen = actual_screen,
  expected_col = expected_col,
}
vim.fn.writefile({ vim.json.encode(actual) }, outfile)
vim.cmd("qa!")
