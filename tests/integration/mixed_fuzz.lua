local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_fuzz_action = 0

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
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_fuzz_action = vim.g.orca_fuzz_action + 1
              end,
            },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_fuzz_action = vim.g.orca_fuzz_action + 10
          end,
        },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        {
          label = "Cu&t",
          key = "x",
          action = function()
            vim.g.orca_fuzz_action = vim.g.orca_fuzz_action + 100
          end,
        },
        {
          label = "Find",
          key = "d",
          action = function()
            vim.g.orca_fuzz_action = vim.g.orca_fuzz_action + 1000
          end,
        },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        {
          label = "Tree",
          key = "r",
          action = function()
            vim.g.orca_fuzz_action = vim.g.orca_fuzz_action + 10000
          end,
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

local mouse = { screenrow = 1, screencol = 1 }
local restore = H.stub_mouse(mouse)
local left_mouse = vim.fn.maparg("<LeftMouse>", "n", false, true).callback
local left_release = vim.fn.maparg("<LeftRelease>", "n", false, true).callback
local open_key = vim.fn.maparg("<F13>", "n", false, true).callback

H.truthy(left_mouse, "left mouse mapping should exist")
H.truthy(left_release, "left release mapping should exist")
H.truthy(open_key, "open key should exist")

local menu_count = #(state.config.menus or {})

local function refresh_topbar()
  H.render_statusline()
  layout.refresh_label_positions()
end

local function top_col(index)
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local function assert_invariants(label)
  H.truthy(state.active_top >= 1 and state.active_top <= menu_count, label .. ": active_top should stay in bounds")

  if popup.is_open() then
    H.truthy(state.menu_mode, label .. ": popup open implies menu_mode")
    H.truthy(#state.menu_stack >= 1, label .. ": popup open implies non-empty stack")
  else
    H.eq(#state.menu_stack, 0, label .. ": no popup implies empty stack")
  end

  for level, entry in ipairs(state.menu_stack) do
    H.truthy(type(entry.items) == "table", label .. ": stack entry should contain items")
    H.truthy((entry.selected or 1) >= 1, label .. ": selected index should stay positive")
    if level > 1 then
      H.truthy(state.menu_stack[level - 1], label .. ": child levels should have parents")
    end
  end
end

local function click_top(index)
  refresh_topbar()
  mouse.screenrow = vim.o.lines - vim.o.cmdheight
  mouse.screencol = top_col(index)
  left_mouse()
end

local function release_top(index)
  refresh_topbar()
  mouse.screenrow = vim.o.lines - vim.o.cmdheight
  mouse.screencol = top_col(index)
  left_release()
end

local function click_row(level, visible_row)
  local entry = state.menu_stack[level]
  mouse.screenrow = entry.content_row + visible_row - 1
  mouse.screencol = entry.content_col + 1
  left_mouse()
end

local function click_outside()
  mouse.screenrow = 1
  mouse.screencol = vim.o.columns
  left_mouse()
end

local steps = {
  { name = "keyboard_open_mode", run = function() open_key() end, check = function()
    H.truthy(state.menu_mode, "open key should enter menu mode")
    H.falsy(popup.is_open(), "open key should not open popup")
  end },
  { name = "mouse_open_file", run = function() click_top(1) end, check = function()
    H.truthy(popup.is_open(), "mouse top open should open popup")
    H.eq(state.active_top, 1, "mouse top open should select File")
  end },
  { name = "top_release_no_blink", run = function() release_top(1) end, check = function()
    H.truthy(popup.is_open(), "top release should not blink-close popup")
    H.truthy(state.menu_mode, "top release should keep menu mode")
  end },
  { name = "keyboard_submenu_open", run = function() popup.activate_item_key("t") end, check = function()
    H.eq(#state.menu_stack, 2, "submenu hotkey should open child popup")
  end },
  { name = "mouse_top_switch", run = function() click_top(2) end, check = function()
    H.eq(state.active_top, 2, "mouse top switch should move to Edit")
    H.eq(#state.menu_stack, 1, "mouse top switch should collapse child popup")
  end },
  { name = "top_release_after_switch", run = function() release_top(2) end, check = function()
    H.truthy(popup.is_open(), "release after top switch should not close popup")
    H.eq(state.active_top, 2, "release after top switch should keep active top")
  end },
  { name = "keyboard_action_after_mouse", run = function() popup.activate_item_key("x") end, check = function()
    H.flush()
    H.eq(vim.g.orca_fuzz_action, 100, "keyboard action should execute after mouse switch")
    H.falsy(state.menu_mode, "action should leave menu mode")
  end },
  { name = "mouse_open_view", run = function() click_top(3) end, check = function()
    H.truthy(popup.is_open(), "mouse should reopen popup from idle")
    H.eq(state.active_top, 3, "mouse should select View")
  end },
  { name = "mouse_action_close", run = function() click_row(1, 1) end, check = function()
    H.flush()
    H.eq(vim.g.orca_fuzz_action, 10100, "mouse action should execute from View menu")
    H.falsy(state.menu_mode, "mouse action should leave menu mode")
  end },
  { name = "keyboard_open_again", run = function() open_key() end, check = function()
    H.truthy(state.menu_mode, "open key should re-enter menu mode")
    H.falsy(popup.is_open(), "menu mode re-entry should still not open popup")
  end },
  { name = "keyboard_top_open_file", run = function() popup.activate_top_key("f") end, check = function()
    H.truthy(popup.is_open(), "top key should open File popup")
    H.eq(state.active_top, 1, "top key should set File active")
  end },
  { name = "mouse_submenu_open", run = function() click_row(1, 1) end, check = function()
    H.eq(#state.menu_stack, 2, "mouse submenu click should open child popup")
  end },
  { name = "keyboard_back_child", run = function() popup.go_back() end, check = function()
    H.eq(#state.menu_stack, 1, "keyboard back should close child popup")
    H.truthy(state.menu_mode, "keyboard back should keep menu mode at root popup")
  end },
  { name = "mouse_toggle_close_top", run = function() click_top(1) end, check = function()
    H.falsy(popup.is_open(), "mouse active top click should close popup")
    H.falsy(state.menu_mode, "mouse active top click should leave menu mode")
  end },
  { name = "top_release_after_close", run = function() release_top(1) end, check = function()
    H.falsy(popup.is_open(), "release after close should not reopen popup")
    H.falsy(state.menu_mode, "release after close should not re-enter mode")
  end },
  { name = "mouse_open_edit", run = function() click_top(2) end, check = function()
    H.truthy(popup.is_open(), "mouse should open Edit popup")
    H.eq(state.active_top, 2, "mouse should select Edit")
  end },
  { name = "outside_close", run = function() click_outside() end, check = function()
    H.falsy(popup.is_open(), "outside click should close popup")
    H.falsy(state.menu_mode, "outside click should leave menu mode")
  end },
}

for _, step in ipairs(steps) do
  step.run()
  assert_invariants(step.name)
  step.check()
  assert_invariants(step.name .. ":post")
end

restore()
H.finish()
print("ok - tests/integration/mixed_fuzz.lua")
