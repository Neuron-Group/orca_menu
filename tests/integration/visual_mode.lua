local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_visual_action = 0
vim.g.orca_visual_ctx = nil

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
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
          action = function(ctx)
            vim.g.orca_visual_action = vim.g.orca_visual_action + 1
            vim.g.orca_visual_ctx = ctx
          end,
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

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
vim.cmd("normal! gg0v$")
H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "test should enter visual mode")

local open_key = vim.fn.maparg("<F13>", "x", false, true).callback
H.truthy(open_key, "open key should be mapped in visual mode")

vim.cmd("normal! gg0v$")
vim.api.nvim_feedkeys(vim.keycode("<F13>"), "x", false)
H.flush()
H.eq(vim.fn.mode(), "n", "actual open key should leave visual mode")
H.truthy(state.menu_mode, "actual open key from visual mode should enable menu mode")
H.falsy(popup.is_open(), "actual open key from visual mode should not open popup immediately")
H.truthy(state.menu_context and state.menu_context.selection, "visual-mode entry should preserve selection context")
H.eq(state.menu_context.selection.mode, "v", "visual-mode entry should preserve the visual mode kind")
H.eq(state.menu_context.selection.lines, { "alpha" }, "visual-mode entry should preserve selected text")
H.truthy(#selection_marks() > 0, "visual-mode entry should keep a temporary selection highlight visible")

popup.close_all()
H.eq(selection_marks(), {}, "closing menu mode should clear the temporary selection highlight")

vim.cmd("normal! gg0v$")
open_key()
H.flush()
H.eq(vim.fn.mode(), "n", "callback open key should leave visual mode")
H.truthy(state.menu_mode, "callback open key from visual mode should enable menu mode")
H.falsy(popup.is_open(), "callback open key from visual mode should not open popup immediately")
H.truthy(#selection_marks() > 0, "callback open key should restore the temporary selection highlight")

H.render_statusline()
layout.refresh_label_positions()
popup.activate_top_key("f")
H.truthy(popup.is_open(), "top key should open popup after visual-mode entry")
popup.activate_item_key("o")
H.flush()
H.eq(vim.g.orca_visual_action, 1, "action should execute after opening from visual mode")
H.truthy(vim.g.orca_visual_ctx and vim.g.orca_visual_ctx.selection, "visual-origin action should receive selection context")
H.eq(vim.g.orca_visual_ctx.selection.lines, { "alpha" }, "visual-origin action should receive selected text")
H.falsy(state.menu_mode, "action should leave menu mode after visual-mode entry")
H.eq(selection_marks(), {}, "executing a visual-origin action should clear the temporary selection highlight")

H.render_statusline()
layout.refresh_label_positions()
vim.cmd("normal! gg0v$")
local click_menu = _G.orca_menu_click_menu_1
H.truthy(click_menu, "top-bar click handler should exist")
click_menu()
H.flush()
H.eq(vim.fn.mode(), "n", "mouse top-bar open should leave visual mode")
H.truthy(state.menu_mode, "mouse top-bar open from visual mode should enable menu mode")
H.truthy(popup.is_open(), "mouse top-bar open from visual mode should open popup")
H.eq(state.active_top, 1, "mouse top-bar open from visual mode should target the clicked menu")

popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "submenu hotkey should work after mouse open from visual mode")
popup.go_back()
H.eq(#state.menu_stack, 1, "go_back should close child submenu after visual-mode mouse open")
H.truthy(state.menu_mode, "go_back should keep menu mode active at root popup")

click_menu()
H.falsy(popup.is_open(), "mouse click on active top menu should close popup from visual-origin flow")
H.falsy(state.menu_mode, "mouse click on active top menu should leave menu mode from visual-origin flow")

H.finish()
print("ok - tests/integration/visual_mode.lua")
