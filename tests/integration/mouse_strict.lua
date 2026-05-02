local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mouse_strict_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    mode_backend = "builtin",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_mouse_strict_action = vim.g.orca_mouse_strict_action + 1
          end,
        },
        {
          label = "Sub&tools",
          key = "t",
          items = {
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_mouse_strict_action = vim.g.orca_mouse_strict_action + 10
              end,
            },
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
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Tree", key = "r", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = 1, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function statusline_row()
  return vim.o.lines - vim.o.cmdheight
end

local function top_col(index)
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local function click_top(index)
  mouse.screenrow = statusline_row()
  mouse.screencol = top_col(index)
  popup.handle_mouse()
end

local function current_entry(level)
  return state.menu_stack[level or #state.menu_stack]
end

local function click_item(level, row)
  local entry = current_entry(level)
  mouse.screenrow = entry.content_row + row - 1
  mouse.screencol = entry.content_col + 1
  popup.handle_mouse()
end

local function click_frame(level)
  local entry = current_entry(level)
  mouse.screenrow = entry.frame_row
  mouse.screencol = entry.frame_col
  popup.handle_mouse()
end

local function click_outside()
  mouse.screenrow = 1
  mouse.screencol = vim.o.columns
  popup.handle_mouse()
end

for attempt = 1, 8 do
  click_top(1)
  H.eq(popup.is_open(), attempt % 2 == 1, "repeated top-label clicks should alternate open and closed state")
  H.eq(state.active_top, 1, "repeated top-label clicks should keep the same active menu")
  H.eq(#state.menu_stack, attempt % 2 == 1 and 1 or 0, "repeated top-label clicks should keep stack depth stable")
end

for _, index in ipairs({ 1, 2, 3, 2, 1, 3, 1, 2 }) do
  click_top(index)
  H.truthy(popup.is_open(), "switching between top labels should keep a popup open")
  H.eq(state.active_top, index, "top label click should switch to the clicked menu")
  H.eq(#state.menu_stack, 1, "top label switching should collapse to one top-level popup")
end

click_top(1)
click_item(1, 2)
H.eq(#state.menu_stack, 2, "submenu click should open exactly one child popup")

click_item(1, 2)
H.eq(#state.menu_stack, 1, "re-clicking the same submenu parent should close its child popup")

click_item(1, 2)
H.eq(#state.menu_stack, 2, "clicking the same submenu parent again should reopen its child popup")

local child_before = vim.deepcopy(current_entry(2))
click_frame(2)
H.eq(#state.menu_stack, 2, "clicking the child frame border should not close the popup tree")
H.eq(current_entry(2).selected, child_before.selected, "frame-border clicks should not change child selection")

click_outside()
H.falsy(popup.is_open(), "outside clicks should close the popup tree")
H.eq(#state.menu_stack, 0, "outside clicks should clear the popup stack")

click_top(1)
click_item(1, 2)
H.eq(#state.menu_stack, 2, "submenu should reopen cleanly after outside close")
mouse.screenrow = current_entry(2).content_row
mouse.screencol = current_entry(2).content_col + 1
H.truthy(popup.scroll_at_mouse(1), "scrolling over a child popup should be accepted")
mouse.screenrow = 1
mouse.screencol = 1
H.falsy(popup.scroll_at_mouse(1), "scrolling outside all popups should be rejected")

click_outside()
click_top(1)
click_item(1, 1)
H.flush()
H.eq(vim.g.orca_mouse_strict_action, 1, "strict mouse item clicks should still execute actions exactly once")
H.falsy(popup.is_open(), "action clicks should close the popup tree")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_strict.lua")
