local outfile = vim.env.ORCA_TERMINAL_RESULT

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.o.laststatus = tonumber(vim.env.ORCA_LASTSTATUS or "2")
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

local submenu_border = vim.env.ORCA_SUBMENU_BORDER or "rounded"

local lualine = require("lualine")
lualine.setup({
  options = {
    globalstatus = vim.o.laststatus == 3,
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
    section = vim.env.ORCA_LUALINE_SECTION or "a",
    spacing = " ",
  },
  submenu = {
    border = submenu_border,
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

local main_win = iv.last_window.id
local infoview_win = iv.window.id
local owner_kind = vim.env.ORCA_OWNER or "infoview"
local owner_win = owner_kind == "main" and main_win or infoview_win
vim.api.nvim_set_current_win(owner_win)
lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
layout.refresh_label_positions(owner_win)

local positions = lualine.get_component_positions({
  place = "statusline",
  winid = owner_win,
})
local position = assert(positions["orca_menu:1"])
assert(position.screen, "lualine should expose a screen span for the rendered menu")
local popup_width = layout.submenu_width(state.config.menus[1].items)
local border_size = state.config.submenu.border and 1 or 0
local frame_width = popup_width + (border_size * 2)
local min_frame_col = 1
local max_frame_col = math.max(vim.o.columns - frame_width + 1, 1)
local expected_frame_col = math.min(
  math.max(position.screen.end_col - frame_width + 1, min_frame_col),
  max_frame_col
)
local expected_col = math.max(
  expected_frame_col - 1,
  0
)

popup.open_top(1)
local popup_win = state.windows[1]
local actual_screen = vim.fn.win_screenpos(popup_win)
local popup_entry = state.menu_stack[1]
local actual = {
  status = "ok",
  main_win = main_win,
  infoview_win = infoview_win,
  owner_kind = owner_kind,
  owner_win = state.menu_owner_win,
  current_win = vim.api.nvim_get_current_win(),
  infoview_config = vim.api.nvim_win_get_config(infoview_win),
  infoview_screen = vim.fn.win_screenpos(infoview_win),
  component = position,
  popup_width = popup_width,
  frame_width = frame_width,
  laststatus = vim.o.laststatus,
  section = vim.env.ORCA_LUALINE_SECTION or "a",
  anchor = vim.deepcopy(state.anchor),
  popup_screen = actual_screen,
  popup_window_position = vim.api.nvim_win_get_position(popup_win),
  popup_cell_screen = vim.fn.screenpos(popup_win, 1, 1),
  popup_config = vim.api.nvim_win_get_config(popup_win),
  popup_entry = {
    row = popup_entry.row,
    col = popup_entry.col,
    frame_row = popup_entry.frame_row,
    frame_col = popup_entry.frame_col,
    content_row = popup_entry.content_row,
    content_col = popup_entry.content_col,
    frame_width = popup_entry.frame_width,
    content_width = popup_entry.content_width,
  },
  expected_col = expected_col,
  expected_frame_col = expected_frame_col,
}
vim.fn.writefile({ vim.json.encode(actual) }, outfile)
vim.cmd("qa!")
