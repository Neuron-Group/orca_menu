local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F16>",
    next = { "l" },
    prev = { "h" },
    down = { "j" },
    up = { "k" },
    select = { "<CR>" },
    back = { "<Esc>" },
    close = { "q" },
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "&Open", key = "o", action = function() end },
        {
          label = "Sub&tools",
          key = "t",
          items = {
            { label = "&Nested", key = "n", action = function() end },
          },
        },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        { label = "Cu&t", key = "x", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")
local selection = require("orca_menu.selection")

local function fail(message, detail)
  error(message .. "\n" .. (detail or ""))
end

local function selection_marks()
  return vim.api.nvim_buf_get_extmarks(0, state.selection_namespace, 0, -1, { details = true })
end

local lines = vim.fn.readfile(vim.fn.getcwd() .. "/tests/Basis.lean")
H.truthy(#lines > 12, "Basis fixture should have enough lines for randomized selection coverage")
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

H.render_statusline()
layout.refresh_label_positions()

local function top_col(index)
  layout.refresh_label_positions()
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = top_col(1) }
local restore_mouse = H.stub_mouse(mouse)

local click_menu = _G.orca_menu_click_menu_1
H.truthy(click_menu, "top-bar click handler should exist")

local seed = 20250302
math.randomseed(seed)

local function line_length(row)
  return #(lines[row] or "")
end

local function random_point()
  local row = math.random(1, #lines)
  local max_col = math.max(line_length(row), 1)
  return row, math.random(1, max_col)
end

local function apply_visual_selection(start_row, start_col, end_row, end_col)
  vim.cmd(("normal! %dG%d|v%dG%d|"):format(start_row, start_col, end_row, end_col))
end

for attempt = 1, 60 do
  popup.close_all()
  H.flush()

  local start_row, start_col = random_point()
  local end_row, end_col = random_point()
  apply_visual_selection(start_row, start_col, end_row, end_col)

  local mode_name = vim.fn.mode()
  if mode_name ~= "v" and mode_name ~= "V" and mode_name ~= "\22" then
    fail("randomized visual test failed to enter visual mode", string.format("attempt=%d seed=%d", attempt, seed))
  end

  local expected = selection.capture()
  if not expected.selection then
    fail(
      "randomized visual test failed to capture expected selection",
      string.format("attempt=%d seed=%d start=%d:%d end=%d:%d", attempt, seed, start_row, start_col, end_row, end_col)
    )
  end

  mouse.screencol = top_col(1)
  click_menu()
  H.flush()
  H.flush()

  H.eq(vim.fn.mode(), "n", "mouse click should leave visual mode after opening menu")
  H.truthy(state.menu_mode, "mouse click should enable menu mode")
  H.truthy(popup.is_open(), "mouse click should open a top-level popup")
  H.truthy(state.menu_context and state.menu_context.selection, "mouse click should preserve visual selection context")
  H.eq(state.menu_context.selection.mode, expected.selection.mode, "mouse click should preserve selection mode")
  H.eq(state.menu_context.selection.start_row, expected.selection.start_row, "mouse click should preserve selection start row")
  H.eq(state.menu_context.selection.start_col, expected.selection.start_col, "mouse click should preserve selection start col")
  H.eq(state.menu_context.selection.end_row, expected.selection.end_row, "mouse click should preserve selection end row")
  H.eq(state.menu_context.selection.end_col, expected.selection.end_col, "mouse click should preserve selection end col")
  H.eq(state.menu_context.selection.lines, expected.selection.lines, "mouse click should preserve selected text")
  H.truthy(#selection_marks() > 0, "mouse click should keep the temporary selection overlay visible")
end

popup.close_all()
H.eq(selection_marks(), {}, "closing the menu should clear the temporary selection overlay")

restore_mouse()
H.finish()
print("ok - tests/integration/visual_mouse_randomized.lua")
