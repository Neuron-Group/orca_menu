local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F15>",
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
        {
          label = "Sub&tools",
          key = "t",
          items = {
            { label = "&Nested", key = "n", action = function() end },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function() end,
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

local function selection_marks()
  return vim.api.nvim_buf_get_extmarks(0, state.selection_namespace, 0, -1, { details = true })
end

local function left_click_callback()
  return vim.fn.maparg("<LeftMouse>", "n", false, true).callback
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
H.render_statusline()
layout.refresh_label_positions()

vim.cmd("normal! gg0v$")
vim.fn.feedkeys(vim.keycode("<F15>"), "xt")
H.flush()
H.flush()
H.truthy(state.menu_mode, "visual-origin open should enable menu mode")
H.truthy(#selection_marks() > 0, "visual-origin open should create a temporary selection overlay")

popup.activate_top_key("f")
popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "submenu activation should open a child popup")
H.truthy(#selection_marks() > 0, "opening a child submenu should keep the temporary selection overlay")

local child = state.menu_stack[2]
local restore_child_border = H.stub_mouse({
  screenrow = child.frame_row,
  screencol = child.frame_col,
})
left_click_callback()()
H.flush()
H.flush()
H.eq(#state.menu_stack, 2, "clicking the child frame border should not close the submenu")
H.truthy(state.menu_mode, "clicking the child frame border should keep menu mode active")
H.truthy(#selection_marks() > 0, "clicking the child frame border should preserve the temporary selection overlay")
restore_child_border()

H.render_statusline()
layout.refresh_label_positions()
local click_edit = _G.orca_menu_click_menu_2
H.truthy(click_edit, "top-bar click handler should exist for Edit")
local function top_col(index)
  layout.refresh_label_positions()
  return state.label_positions[index] + 1
end

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = top_col(2) }
local restore_mouse = H.stub_mouse(mouse)
click_edit()
H.flush()
H.flush()
H.eq(state.active_top, 2, "switching top-bar menu should retarget the active top menu")
H.eq(#state.menu_stack, 1, "switching top-bar menu should collapse child submenus")
H.truthy(state.menu_mode, "switching top-bar menu should keep menu mode active")
H.truthy(#selection_marks() > 0, "switching top-bar menu should preserve the temporary selection overlay")

popup.close_all()
H.eq(selection_marks(), {}, "closing the menu should clear the temporary selection overlay")

vim.cmd("normal! gg0v$")
vim.fn.feedkeys(vim.keycode("<F15>"), "xt")
H.flush()
H.flush()
H.truthy(state.menu_mode, "reopening from visual mode should still work")
popup.close_all()

H.eq(vim.fn.mode(), "n", "closing the menu should leave the editor in normal mode")
H.falsy(state.menu_mode, "closing the menu should leave menu mode inactive")

H.render_statusline()
layout.refresh_label_positions()
vim.cmd("normal! gg0")
vim.fn.feedkeys(vim.keycode("<F15>"), "xt")
H.flush()
H.flush()
H.falsy(state.menu_context and state.menu_context.selection, "reopening from normal mode after a canceled visual session should not resurrect stale selection context")

popup.close_all()
vim.cmd("normal! gg0v$")
vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "xt", false)
H.flush()
H.flush()
click_edit()
H.flush()
H.flush()
H.falsy(state.menu_context and state.menu_context.selection, "top-bar click from normal mode after canceling visual should not resurrect stale selection context")

restore_mouse()
H.finish()
print("ok - tests/integration/visual_selection_lifecycle.lua")
