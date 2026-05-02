local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_random_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    mode_backend = "builtin",
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
            { label = "&Nested", key = "n", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 1 end },
            { label = "Ne&xt", key = "m", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 2 end },
          },
        },
        { label = "&Open", key = "o", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 10 end },
        { label = "Sa&ve", key = "s", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 20 end },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        { label = "Cu&t", key = "x", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 100 end },
        { label = "&Copy", key = "c", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 200 end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "Tree", key = "r", action = function() vim.g.orca_random_action = vim.g.orca_random_action + 1000 end },
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
H.truthy(open_key, "open key mapping should exist")

local seed = 1337
math.randomseed(seed)
local replay = vim.env.ORCA_MENU_REPLAY

local history = {}

local function record(step, detail)
  table.insert(history, string.format("%03d:%s", step, detail))
end

local function fail(message)
  local replay_value = table.concat(history, ",")
  local replay_cmd = string.format(
    "ORCA_MENU_REPLAY='%s' nvim --headless -u tests/minimal_init.lua -l tests/integration/randomized_stress.lua",
    replay_value
  )
  error(message .. "\nseed: " .. seed .. "\nhistory:\n" .. table.concat(history, "\n") .. "\nreplay:\n" .. replay_cmd)
end

local function expect(condition, message)
  if not condition then
    fail(message)
  end
end

local function safe_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    fail((message or "values differ") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
  end
end

local function refresh_topbar()
  H.render_statusline()
  layout.refresh_label_positions()
end

local function menu_count()
  return #(state.config.menus or {})
end

local function top_col(index)
  refresh_topbar()
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
end

local function assert_invariants(label)
  expect(state.active_top >= 1 and state.active_top <= menu_count(), label .. ": active_top out of bounds")

  if popup.is_open() then
    expect(state.menu_mode, label .. ": popup open but menu_mode false")
    expect(#state.menu_stack >= 1, label .. ": popup open but stack empty")
    safe_eq(#state.windows > 0, true, label .. ": popup open but windows missing")
  else
    safe_eq(#state.menu_stack, 0, label .. ": popup closed but stack not empty")
    safe_eq(#state.windows, 0, label .. ": popup closed but windows remain")
  end

  for level, entry in ipairs(state.menu_stack) do
    expect(type(entry.items) == "table", label .. ": stack entry missing items")
    expect((entry.selected or 1) >= 1, label .. ": selected must stay >= 1")
    if level > 1 then
      expect(state.menu_stack[level - 1] ~= nil, label .. ": child popup missing parent")
    end
  end
end

local function current_entry()
  return state.menu_stack[#state.menu_stack]
end

local function click_top(index)
  mouse.screenrow = vim.o.lines - vim.o.cmdheight
  mouse.screencol = top_col(index)
  left_mouse()
end

local function release_top(index)
  mouse.screenrow = vim.o.lines - vim.o.cmdheight
  mouse.screencol = top_col(index)
  left_release()
end

local function click_selected_row()
  local entry = current_entry()
  if not entry then
    return false
  end
  local visible_row = (entry.selected or 1) - (entry.scroll_top or 1) + 1
  mouse.screenrow = entry.content_row + visible_row - 1
  mouse.screencol = entry.content_col + 1
  left_mouse()
  return true
end

local function click_outside()
  mouse.screenrow = 1
  mouse.screencol = vim.o.columns
  left_mouse()
end

local function visible_item_keys()
  local keys = {}
  for _, entry in ipairs(state.menu_stack) do
    for _, item in ipairs(entry.items or {}) do
      if item.kind ~= "separator" then
        if item.key and item.key ~= "" then
          table.insert(keys, item.key)
        elseif item.accelerator and item.accelerator ~= "" then
          table.insert(keys, item.accelerator)
        end
      end
    end
  end
  return keys
end

local operations = {
  {
    name = "open_key",
    run = function()
      open_key()
    end,
  },
  {
    name = "mouse_top",
    run = function()
      click_top(math.random(1, menu_count()))
    end,
  },
  {
    name = "mouse_top_release",
    run = function()
      release_top(math.random(1, menu_count()))
    end,
  },
  {
    name = "mouse_outside",
    run = function()
      click_outside()
    end,
  },
  {
    name = "move_top_next",
    run = function()
      popup.move_top(1)
    end,
  },
  {
    name = "move_top_prev",
    run = function()
      popup.move_top(-1)
    end,
  },
  {
    name = "select_row_down",
    run = function()
      popup.select_row(1)
    end,
  },
  {
    name = "select_row_up",
    run = function()
      popup.select_row(-1)
    end,
  },
  {
    name = "activate_selected",
    run = function()
      popup.activate_selected()
    end,
  },
  {
    name = "go_back",
    run = function()
      popup.go_back()
    end,
  },
  {
    name = "click_selected_row",
    run = function()
      click_selected_row()
    end,
  },
  {
    name = "activate_item_key",
    run = function()
      local keys = visible_item_keys()
      if #keys > 0 then
        popup.activate_item_key(keys[math.random(1, #keys)])
      end
    end,
  },
  {
    name = "activate_top_key",
    run = function()
      local keys = {}
      for _, menu in ipairs(state.config.menus or {}) do
        if menu.key then
          table.insert(keys, menu.key)
        elseif menu.accelerator then
          table.insert(keys, menu.accelerator)
        end
      end
      popup.activate_top_key(keys[math.random(1, #keys)])
    end,
  },
}

local operations_by_name = {}
for _, operation in ipairs(operations) do
  operations_by_name[operation.name] = operation
end

local replay_steps = {}
if type(replay) == "string" and replay ~= "" then
  for part in replay:gmatch("[^,]+") do
    table.insert(replay_steps, part)
  end
end

local total_steps = #replay_steps > 0 and #replay_steps or 120

for step = 1, total_steps do
  local operation
  if #replay_steps > 0 then
    operation = operations_by_name[replay_steps[step]]
    if not operation then
      fail("unknown replay operation: " .. tostring(replay_steps[step]))
    end
  else
    operation = operations[math.random(1, #operations)]
  end
  record(step, operation.name)
  local ok, err = pcall(operation.run)
  if not ok then
    fail("operation error: " .. err)
  end
  H.flush()
  assert_invariants(operation.name)
end

restore()
H.finish()
print("ok - tests/integration/randomized_stress.lua")
