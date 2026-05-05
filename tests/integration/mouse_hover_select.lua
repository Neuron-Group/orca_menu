local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mouse_hover_action = 0

vim.o.mousemoveevent = false

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  submenu = {
    hover_select = true,
    hover_parent = "retarget",
    hover_topbar = false,
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
            vim.g.orca_mouse_hover_action = vim.g.orca_mouse_hover_action + 1
          end,
        },
        {
          label = "&Disabled",
          key = "d",
          enabled = false,
          action = function()
            vim.g.orca_mouse_hover_action = vim.g.orca_mouse_hover_action + 100
          end,
        },
        {
          label = "Sub&tools",
          key = "t",
          items = {
            {
              label = "&Nested",
              key = "n",
              items = {
                {
                  label = "&Deep",
                  key = "d",
                  action = function()
                    vim.g.orca_mouse_hover_action = vim.g.orca_mouse_hover_action + 10
                  end,
                },
                {
                  label = "Dee&p Two",
                  key = "p",
                  action = function()
                    vim.g.orca_mouse_hover_action = vim.g.orca_mouse_hover_action + 30
                  end,
                },
              },
            },
            {
              label = "Ne&xted",
              key = "x",
              action = function()
                vim.g.orca_mouse_hover_action = vim.g.orca_mouse_hover_action + 20
              end,
            },
          },
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local mouse = { screenrow = 1, screencol = 1 }
local restore_mouse = H.stub_mouse(mouse)

H.eq(vim.fn.maparg("<MouseMove>", "n", false, true), {}, "hover mapping should stay inactive before popup opens")
H.falsy(vim.o.mousemoveevent, "mousemoveevent should start disabled for this test")

popup.open_top(1)

local hover_map = vim.fn.maparg("<MouseMove>", "n", false, true)
H.truthy(hover_map.callback, "opening a popup with hover_select should install mouse-move handling")
H.truthy(vim.o.mousemoveevent, "opening a popup with hover_select should enable mousemoveevent")
H.eq(#state.menu_stack, 1, "opening a popup should create exactly one level")
H.eq(state.menu_stack[1].selected, 1, "first enabled row should start selected")

local function hover_row(level, row)
  local entry = state.menu_stack[level]
  mouse.screenrow = entry.content_row + row - 1
  mouse.screencol = entry.content_col + 1
  hover_map.callback()
end

local function hover_frame(level)
  local entry = state.menu_stack[level]
  mouse.screenrow = entry.frame_row
  mouse.screencol = entry.frame_col
  hover_map.callback()
end

hover_row(1, 3)
H.eq(state.menu_stack[1].selected, 3, "hovering an enabled row should move selection to it")
H.eq(#state.menu_stack, 1, "hovering a submenu row should not auto-open children")
H.eq(vim.g.orca_mouse_hover_action, 0, "hovering should not execute item actions")

hover_row(1, 2)
H.eq(state.menu_stack[1].selected, 3, "hovering a disabled row should not move selection")
H.eq(vim.g.orca_mouse_hover_action, 0, "hovering a disabled row should not execute actions")

popup.activate_selected()
H.eq(#state.menu_stack, 2, "activating the hovered submenu row should still open its child popup")

hover_row(2, 1)
H.eq(state.menu_stack[2].selected, 1, "hovering a second-level submenu row should move child selection to it")
H.eq(#state.menu_stack, 2, "hovering a second-level submenu row should not auto-open a third popup")

popup.activate_selected()
H.eq(#state.menu_stack, 3, "activating the hovered second-level submenu row should open a third popup")

hover_row(3, 2)
H.eq(state.menu_stack[3].selected, 2, "hovering an enabled grandchild row should move grandchild selection")
H.eq(#state.menu_stack, 3, "hovering within the grandchild popup should keep all three levels open")

hover_row(2, 1)
H.eq(#state.menu_stack, 3, "hovering back on the selected child row should keep the grandchild popup open")
H.eq(state.menu_stack[2].selected, 1, "hovering back on the selected child row should preserve child selection")
H.eq(state.menu_stack[3].selected, 2, "hovering back on the selected child row should preserve grandchild selection")

hover_row(2, 2)
H.eq(state.menu_stack[2].selected, 2, "hovering an enabled child row should move child selection")
H.eq(#state.menu_stack, 2, "hovering within the child popup should keep the child popup open")

hover_row(1, 3)
H.eq(#state.menu_stack, 2, "hovering back on the selected parent row should keep the child popup open")
H.eq(state.menu_stack[1].selected, 3, "hovering back on the selected parent row should preserve parent selection")
H.eq(state.menu_stack[2].selected, 2, "hovering back on the selected parent row should preserve child selection")

hover_frame(1)
H.eq(#state.menu_stack, 2, "hovering the parent frame while a child is open should keep the child popup open")
H.eq(state.menu_stack[1].selected, 3, "hovering the parent frame should preserve parent selection")
H.eq(state.menu_stack[2].selected, 2, "hovering the parent frame should preserve child selection")

hover_row(1, 1)
H.eq(#state.menu_stack, 1, "hovering another parent row should collapse child popups")
H.eq(state.menu_stack[1].selected, 1, "hovering another parent row should retarget selection")
H.eq(vim.g.orca_mouse_hover_action, 0, "collapsing child popups by hover should not execute actions")

popup.close_all()
H.eq(vim.fn.maparg("<MouseMove>", "n", false, true), {}, "closing popups should remove mouse-move handling")
H.falsy(vim.o.mousemoveevent, "closing popups should restore mousemoveevent to its prior value")

vim.o.mousemoveevent = true
popup.open_top(1)
H.truthy(vim.o.mousemoveevent, "hover setup should preserve a previously enabled mousemoveevent option")
popup.close_all()
H.truthy(vim.o.mousemoveevent, "closing popups should preserve a previously enabled mousemoveevent option")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_hover_select.lua")
