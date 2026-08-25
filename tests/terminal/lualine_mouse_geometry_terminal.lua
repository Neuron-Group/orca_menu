local outfile = vim.env.ORCA_TERMINAL_RESULT
local timeout_ms = tonumber(vim.env.ORCA_TERMINAL_TIMEOUT_MS or "3500")

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.o.mouse = "a"
vim.o.laststatus = 2
vim.g.mapleader = " "

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
    lualine_y = {},
    lualine_z = { "location" },
  },
})

vim.cmd("enew")
local main_win = vim.api.nvim_get_current_win()
vim.bo.filetype = "lean"
vim.api.nvim_set_hl(0, "OrcaMenuTopbarActive", { fg = "#ffffff", bg = "#3b4261", bold = true })

require("orca_menu").setup({
  enable_mouse = true,
  topbar = {
    hint_format = "{hint}/{label}",
  },
  lualine = {
    section = "y",
    spacing = " ",
  },
  highlights = {
    topbar_active = "OrcaMenuTopbarActive",
    topbar_active_preserve_bg = false,
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

vim.cmd("botright 62vsplit")
local infoview_win = vim.api.nvim_get_current_win()
vim.bo.filetype = "leaninfo"
vim.api.nvim_set_current_win(infoview_win)

local layout = require("orca_menu.layout")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

local function write_result(status, extra)
  vim.fn.writefile({ vim.json.encode(vim.tbl_extend("force", {
    status = status,
    current_win = vim.api.nvim_get_current_win(),
    main_win = main_win,
    infoview_win = infoview_win,
    active_top = state.active_top,
    popup_open = popup.is_open() and true or false,
    label_positions = vim.deepcopy(state.label_positions),
  }, extra or {})) }, outfile)
end

local function fail(message)
  write_result("error", { message = message })
  vim.cmd("qa!")
end

lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
popup.open_top(1)
layout.refresh_label_positions(infoview_win)

local target = 5
local target_position = state.component_positions[target]
local target_start = state.label_positions[target]
local target_label = layout.top_bar_display_label(state.config.menus[target], target)
local target_width = vim.fn.strdisplaywidth(target_label)
local statusline_row = target_position and target_position.screen and target_position.screen.row
local target_right = target_start and target_start + target_width - 1
local popup_width = layout.submenu_width(state.config.menus[target].items)
local expected_anchor_col
if target_position and target_position.screen then
  expected_anchor_col = math.max(
    math.min(target_position.screen.end_col - popup_width + 1 - 3, vim.o.columns - popup_width + 1),
    1
  )
end

if not target_position or not target_position.visible or not target_position.screen then
  fail("Search component was not visible in the infoview statusline")
  return
end
if not target_start or not target_right or not statusline_row then
  fail("Search label did not receive screen geometry")
  return
end

write_result("ready", {
  target = target,
  target_label = target_label,
  target_col = target_right,
  target_row = statusline_row,
  target_component = vim.deepcopy(target_position),
  evaluated = vim.api.nvim_eval_statusline(vim.wo.statusline, {
    winid = infoview_win,
    maxwidth = vim.api.nvim_win_get_width(infoview_win),
  }).str,
})

local started = vim.loop.hrtime()
local timer = vim.loop.new_timer()
timer:start(40, 40, vim.schedule_wrap(function()
  if popup.is_open() then
    timer:stop()
    timer:close()
    if state.active_top ~= target then
      fail(string.format("mouse opened top %d instead of Search (%d)", state.active_top, target))
      return
    end
    if expected_anchor_col and state.anchor.col ~= expected_anchor_col then
      fail(string.format("anchor used a post-click geometry frame: got %d, expected %d", state.anchor.col, expected_anchor_col))
      return
    end
    write_result("ok", {
      target = target,
      target_label = target_label,
      clicked_col = target_right,
      clicked_row = statusline_row,
      anchor = vim.deepcopy(state.anchor),
      expected_anchor_col = expected_anchor_col,
      owner_win = state.menu_owner_win,
      before_component = vim.deepcopy(target_position),
      after_component = vim.deepcopy(state.component_positions[target]),
      after_label_col = state.label_positions[target],
    })
    vim.cmd("qa!")
    return
  end

  if (vim.loop.hrtime() - started) / 1000000 >= timeout_ms then
    timer:stop()
    timer:close()
    fail("PTY mouse click did not open Search")
  end
end))
