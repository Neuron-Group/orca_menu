local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&Tools",
      key = "t",
      items = {
        {
          label = "For&mat",
          key = "m",
          action = function() end,
        },
      },
    },
    {
      label = "&LSP",
      key = "p",
      enabled = false,
      items = {
        {
          label = "&Rename",
          key = "r",
          action = function() end,
        },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        {
          label = "&Tree",
          key = "e",
          action = function() end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

local function statusline_row()
  return vim.o.lines - vim.o.cmdheight
end

local function top_col(index)
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local function click_top_with_popup_handler(index)
  mouse.screenrow = statusline_row()
  mouse.screencol = top_col(index)
  popup.handle_mouse()
end

click_top_with_popup_handler(1)
H.truthy(popup.is_open(), "clicking an enabled top label should open its popup")
H.eq(state.active_top, 1, "clicking Tools should activate Tools")

click_top_with_popup_handler(2)
H.truthy(popup.is_open(), "clicking a disabled top label while a popup is open should keep the popup open")
H.eq(state.active_top, 1, "clicking a disabled top label while a popup is open should not retarget to another enabled menu")
H.eq(#state.menu_stack, 1, "clicking a disabled top label while a popup is open should preserve stack depth")

click_top_with_popup_handler(3)
H.truthy(popup.is_open(), "clicking another enabled top label should still switch popups")
H.eq(state.active_top, 3, "clicking View should still activate View")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_disabled_top_click.lua")
