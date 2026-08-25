local outfile = vim.env.ORCA_TERMINAL_RESULT

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.o.laststatus = tonumber(vim.env.ORCA_INITIAL_LASTSTATUS or vim.env.ORCA_LASTSTATUS or "2")
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
if vim.env.ORCA_INFOVIEW_WIDTH and vim.env.ORCA_INFOVIEW_WIDTH ~= "" then
  iv.window:set_width(tonumber(vim.env.ORCA_INFOVIEW_WIDTH))
end
if vim.env.ORCA_INFOVIEW_GUTTER == "1" then
  vim.api.nvim_win_call(iv.window.id, function()
    vim.wo.number = true
    vim.wo.signcolumn = "yes:1"
  end)
end

local submenu_border = vim.env.ORCA_SUBMENU_BORDER or "rounded"

local lualine = require("lualine")
local lualine_options = {
  globalstatus = vim.o.laststatus == 3,
}
if vim.env.ORCA_IGNORE_INFOVIEW == "1" then
  lualine_options.ignore_focus = { "leaninfo" }
end
lualine.setup({
  options = lualine_options,
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

if vim.env.ORCA_SWITCH_LASTSTATUS and vim.env.ORCA_SWITCH_LASTSTATUS ~= "" then
  vim.o.laststatus = tonumber(vim.env.ORCA_SWITCH_LASTSTATUS)
  lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
end

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

local function screen_cells(row, first_col, last_col)
  local cells = {}
  for col = first_col, last_col do
    table.insert(cells, {
      col = col,
      text = vim.fn.screenstring(row, col),
    })
  end
  return cells
end

local function current_component_position(winid)
  return vim.deepcopy(lualine.get_component_positions({
    place = "statusline",
    winid = winid,
  })["orca_menu:1"])
end

local function position_snapshot(winid)
  local position = current_component_position(winid)
  local screen = position and position.screen
  local row = screen and screen.row or (vim.o.lines - vim.o.cmdheight)
  local first_col = screen and math.max(screen.start_col - 4, 1) or 1
  local last_col = screen and math.min(screen.end_col + 4, vim.o.columns) or vim.o.columns
  local info = vim.fn.getwininfo(winid)[1] or {}
  local statusline = vim.api.nvim_win_get_option(winid, "statusline")
  local evaluated = vim.api.nvim_eval_statusline(statusline, {
    winid = winid,
    maxwidth = vim.api.nvim_win_get_width(winid),
    highlights = true,
  })
  return {
    winid = winid,
    current = vim.api.nvim_get_current_win() == winid,
    screen = vim.fn.win_screenpos(winid),
    position = vim.api.nvim_win_get_position(winid),
    width = vim.api.nvim_win_get_width(winid),
    textoff = info.textoff,
    row = row,
    cells = screen_line(row, first_col, last_col),
    statusline = statusline,
    evaluated_statusline = {
      str = evaluated.str,
      width = evaluated.width,
    },
    component = position,
  }
end

local function geometry_snapshot(main_win, infoview_win)
  local current_win = vim.api.nvim_get_current_win()
  local wins = {}
  for _, winid in ipairs({ main_win, infoview_win }) do
    wins[tostring(winid)] = position_snapshot(winid)
  end
  return {
    laststatus = vim.o.laststatus,
    globalstatus = lualine.get_config().options.globalstatus,
    actual_curwin = vim.g.actual_curwin,
    current_win = current_win,
    current_position = position_snapshot(current_win),
    wins = wins,
  }
end

local function position_cache_transition(main_win, infoview_win)
  local original_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(infoview_win)
  local inactive_statusline = vim.api.nvim_win_call(infoview_win, function()
    return lualine.statusline(false)
  end)
  vim.api.nvim_win_call(infoview_win, function()
    lualine.statusline(true)
  end)
  vim.api.nvim_win_set_option(infoview_win, "statusline", inactive_statusline)
  local transition_current = vim.env.ORCA_CACHE_TRANSITION_CURRENT == "infoview"
      and infoview_win
    or main_win
  vim.api.nvim_set_current_win(transition_current)
  local position = current_component_position(infoview_win)
  vim.api.nvim_set_current_win(original_win)
  lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
  return {
    inactive_statusline = inactive_statusline,
    position = position,
  }
end

local function popup_summary()
  local popup_win = state.windows[1]
  local popup_entry = state.menu_stack[1]
  local actual_screen = vim.fn.win_screenpos(popup_win)
  return {
    owner_win = state.menu_owner_win,
    current_win = vim.api.nvim_get_current_win(),
    component = state.menu_owner_win and current_component_position(state.menu_owner_win) or nil,
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

local main_win = iv.last_window.id
local infoview_win = iv.window.id
local infoview_info = vim.fn.getwininfo(infoview_win)[1] or {}
local infoview_geometry = {
  screen = vim.fn.win_screenpos(infoview_win),
  position = vim.api.nvim_win_get_position(infoview_win),
  width = vim.api.nvim_win_get_width(infoview_win),
  textoff = infoview_info.textoff,
  number = vim.wo[infoview_win].number,
  signcolumn = vim.wo[infoview_win].signcolumn,
  statuscolumn = vim.wo[infoview_win].statuscolumn,
}
local owner_kind = vim.env.ORCA_OWNER or "infoview"
local owner_win = owner_kind == "main" and main_win or infoview_win
vim.api.nvim_set_current_win(owner_win)
lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
layout.refresh_label_positions(owner_win)
vim.cmd("redrawstatus")
vim.cmd("redraw")
local geometry_before_mouse = geometry_snapshot(main_win, infoview_win)
local cache_transition
if vim.env.ORCA_TEST_POSITION_CACHE == "1" then
  cache_transition = position_cache_transition(main_win, infoview_win)
end

if vim.env.ORCA_REAL_MOUSE == "1" then
  local trace_path = outfile .. ".trace"
  vim.fn.writefile({}, trace_path)
  state.mouse_trace_path = trace_path
  if vim.env.ORCA_MOUSE_COL and vim.env.ORCA_MOUSE_ROW then
    vim.fn.writefile({ vim.json.encode({
      event = "real_mouse_expected",
      screencol = tonumber(vim.env.ORCA_MOUSE_COL),
      screenrow = tonumber(vim.env.ORCA_MOUSE_ROW),
    }) }, trace_path, "a")
  end
  vim.defer_fn(function()
    local mouse = vim.fn.getmousepos()
    local position = current_component_position(mouse.winid or owner_win)
    local item_position = position.screen.item or position.screen
    local hit = layout.label_hit_at_col(math.max(mouse.screencol or 1, 1), mouse)
    local popup_data = nil
    if vim.env.ORCA_REAL_MOUSE_CLICK == "1" and hit and not require("orca_menu.popup").is_open() then
      orca.click(hit, mouse)
      vim.wait(100, function()
        return require("orca_menu.popup").is_open()
      end, 1)
    end
    if require("orca_menu.popup").is_open() then
      popup_data = popup_summary()
    end
    vim.fn.writefile({ vim.json.encode({
      status = "ok",
      columns = vim.o.columns,
      position = position,
      screen = screen_line(position.screen.row, 58, vim.o.columns),
      cells = screen_cells(position.screen.row, 50, vim.o.columns),
      owner_win = owner_win,
      current_win = vim.api.nvim_get_current_win(),
      popup_open = require("orca_menu.popup").is_open(),
      infoview_geometry = infoview_geometry,
      geometry = geometry_before_mouse,
      real_mouse = {
        mouse = mouse,
        item = item_position,
        hit = hit,
      },
      popup = popup_data,
    }) }, outfile)
    vim.cmd("qa!")
  end, 2500)
  return
end

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
local item_position = position.screen.item or position.screen
local min_frame_col = 1
local max_frame_col = math.max(vim.o.columns - frame_width + 1, 1)
local expected_frame_col = math.min(
  math.max(item_position.end_col + border_size - frame_width + 1, min_frame_col),
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
  screencol = item_position.start_col,
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
  screencol = item_position.start_col,
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
  infoview_geometry = infoview_geometry,
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
  geometry = geometry_before_mouse,
  cache_transition = cache_transition,
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
