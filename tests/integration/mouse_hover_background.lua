local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mouse_hover_background_action = 0

vim.o.mousemoveevent = false

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  submenu = {
    hover_select = true,
    hover_parent = "background",
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
            vim.g.orca_mouse_hover_background_action = vim.g.orca_mouse_hover_background_action + 1
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
                    vim.g.orca_mouse_hover_background_action = vim.g.orca_mouse_hover_background_action + 10
                  end,
                },
                {
                  label = "Dee&p Two",
                  key = "p",
                  action = function()
                    vim.g.orca_mouse_hover_background_action = vim.g.orca_mouse_hover_background_action + 20
                  end,
                },
              },
            },
            {
              label = "Ne&xted",
              key = "x",
              action = function()
                vim.g.orca_mouse_hover_background_action = vim.g.orca_mouse_hover_background_action + 30
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

popup.open_top(1)

local hover_map = vim.fn.maparg("<MouseMove>", "n", false, true)
H.truthy(hover_map.callback, "background hover mode should install mouse-move handling")

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

hover_row(1, 2)
H.eq(state.menu_stack[1].selected, 2, "hovering a parent row should still work before any child popup opens")

popup.activate_selected()
H.eq(#state.menu_stack, 2, "activating the hovered submenu row should open the child popup")

hover_row(1, 1)
H.eq(#state.menu_stack, 2, "hovering another parent row while a child popup is open should keep the child popup open")
H.eq(state.menu_stack[1].selected, 2, "hovering another parent row while a child popup is open should not retarget the parent")

hover_frame(1)
H.eq(#state.menu_stack, 2, "hovering the parent frame while a child popup is open should keep the child popup open")
H.eq(state.menu_stack[1].selected, 2, "hovering the parent frame while a child popup is open should preserve parent selection")

hover_row(2, 1)
H.eq(state.menu_stack[2].selected, 1, "hovering a child submenu row should still move child selection")

popup.activate_selected()
H.eq(#state.menu_stack, 3, "activating the hovered child submenu row should open a grandchild popup")

hover_row(1, 1)
H.eq(#state.menu_stack, 3, "hovering the grandparent while a grandchild popup is open should keep descendants open")
H.eq(state.menu_stack[1].selected, 2, "hovering the grandparent while a grandchild popup is open should not retarget it")

hover_row(2, 2)
H.eq(#state.menu_stack, 3, "hovering the parent while a grandchild popup is open should keep the grandchild popup open")
H.eq(state.menu_stack[2].selected, 1, "hovering the parent while a grandchild popup is open should not retarget it")

popup.go_back()
H.eq(#state.menu_stack, 2, "go_back should close only the grandchild popup")

popup.go_back()
H.eq(#state.menu_stack, 1, "go_back again should close the child popup and return hover to the parent")

hover_row(1, 1)
H.eq(state.menu_stack[1].selected, 1, "once back on the parent level, hovering another parent row should work again")

restore_mouse()
H.finish()
print("ok - tests/integration/mouse_hover_background.lua")
