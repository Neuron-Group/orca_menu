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
  enable_mouse = vim.env.ORCA_ENABLE_MOUSE ~= "0",
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
local orca = require("orca_menu")

local function screen_line(row, first_col, last_col)
  local cells = {}
  for col = first_col, last_col do
    table.insert(cells, vim.fn.screenstring(row, col))
  end
  return {
    first_col = first_col,
    last_col = last_col,
    text = table.concat(cells),
  }
end

local function popup_summary()
  local popup_win = state.windows[1]
  local popup_entry = state.menu_stack[1]
  local actual_screen = vim.fn.win_screenpos(popup_win)
  return {
    owner_win = state.menu_owner_win,
    current_win = vim.api.nvim_get_current_win(),
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
  }
end

local function current_component_position(winid)
  return vim.deepcopy(lualine.get_component_positions({
    place = "statusline",
    winid = winid,
  })["orca_menu:1"])
end

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
local component_width = vim.fn.strdisplaywidth(require("orca_menu.lualine").visible_component_at(1))
assert(
  position.screen.width == component_width,
  "lualine screen geometry should match the rendered component"
)
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

local screen_row = position.screen.row
vim.cmd("redrawstatus")
vim.cmd("redraw")
local screen_before = screen_line(screen_row, 50, vim.o.columns)
local rendered_component = {}
for col = position.screen.start_col, position.screen.end_col do
  table.insert(rendered_component, vim.fn.screenstring(screen_row, col))
end
assert(
  table.concat(rendered_component) == require("orca_menu.lualine").visible_component_at(1),
  "lualine component geometry should address the rendered topbar component"
)

local original_getmousepos = vim.fn.getmousepos
local event_mouse = {
  screenrow = position.screen.row,
  screencol = position.screen.start_col,
  winid = owner_win,
  win = owner_win,
}
vim.fn.getmousepos = function()
  return event_mouse
end
vim.fn.feedkeys(vim.keycode("<LeftMouse>"), "xt")
vim.wait(20, function()
  return popup.is_open()
end, 1)
assert(popup.is_open(), "real mouse event path should open the menu")
local event = popup_summary()
event.component = current_component_position(owner_win)
vim.fn.getmousepos = original_getmousepos

popup.close_all()
popup.open_top(1)
local direct = popup_summary()
direct.component = current_component_position(owner_win)
vim.cmd("redraw")
local direct_screen = screen_line(screen_row, 50, vim.o.columns)

popup.close_all()
vim.api.nvim_set_current_win(owner_win)
local click_mouse = {
  screenrow = position.screen.row,
  screencol = position.screen.start_col,
  winid = owner_win,
  win = owner_win,
}
orca.click(1, click_mouse)
assert(popup.is_open(), "click path should open the menu")
local click = popup_summary()
click.component = current_component_position(owner_win)
vim.cmd("redraw")
local click_screen = screen_line(screen_row, 50, vim.o.columns)
local actual = {
  status = "ok",
  main_win = main_win,
  infoview_win = infoview_win,
  owner_kind = owner_kind,
  infoview_config = vim.api.nvim_win_get_config(infoview_win),
  infoview_screen = vim.fn.win_screenpos(infoview_win),
  component = position,
  component_width = component_width,
  popup_width = popup_width,
  frame_width = frame_width,
  laststatus = vim.o.laststatus,
  section = vim.env.ORCA_LUALINE_SECTION or "a",
  screen_row = screen_row,
  screen_before = screen_before,
  event = event,
  direct = direct,
  direct_screen = direct_screen,
  click = click,
  click_screen = click_screen,
  -- Keep the direct values at the top level for the existing validator.
  owner_win = click.owner_win,
  current_win = click.current_win,
  anchor = click.anchor,
  popup_screen = click.popup_screen,
  popup_window_position = click.popup_window_position,
  popup_cell_screen = click.popup_cell_screen,
  popup_config = click.popup_config,
  popup_entry = click.popup_entry,
  expected_col = expected_col,
  expected_frame_col = expected_frame_col,
}
vim.fn.writefile({ vim.json.encode(actual) }, outfile)
vim.cmd("qa!")
