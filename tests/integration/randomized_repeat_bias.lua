local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_repeat_bias_action = 0

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
            { label = "&Nested", key = "n", action = function() vim.g.orca_repeat_bias_action = vim.g.orca_repeat_bias_action + 1 end },
            { label = "Ne&xt", key = "m", action = function() vim.g.orca_repeat_bias_action = vim.g.orca_repeat_bias_action + 2 end },
          },
        },
        { label = "&Open", key = "o", action = function() vim.g.orca_repeat_bias_action = vim.g.orca_repeat_bias_action + 10 end },
      },
    },
    {
      label = "&Edit",
      key = "e",
      items = {
        { label = "Cu&t", key = "x", action = function() vim.g.orca_repeat_bias_action = vim.g.orca_repeat_bias_action + 100 end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "Tree", key = "r", action = function() vim.g.orca_repeat_bias_action = vim.g.orca_repeat_bias_action + 1000 end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

local seed = 424242
math.randomseed(seed)
local replay = vim.env.ORCA_MENU_REPLAY

local history = {}

local function record(step, detail)
  table.insert(history, string.format("%03d:%s", step, detail))
end

local function fail(message)
  local replay_value = table.concat(history, ",")
  local replay_cmd = string.format(
    "ORCA_MENU_REPLAY='%s' nvim --headless -u tests/minimal_init.lua -l tests/integration/randomized_repeat_bias.lua",
    replay_value
  )
  error(message .. "\nseed: " .. seed .. "\nhistory:\n" .. table.concat(history, "\n") .. "\nreplay:\n" .. replay_cmd)
end

local function expect(condition, message)
  if not condition then
    fail(message)
  end
end

local function refresh_topbar()
  H.render_statusline()
  layout.refresh_label_positions()
end

local function assert_invariants(label)
  local count = #(state.config.menus or {})
  expect(state.active_top >= 1 and state.active_top <= count, label .. ": active_top out of bounds")

  if popup.is_open() then
    expect(state.menu_mode, label .. ": popup open but menu_mode false")
    expect(#state.menu_stack >= 1, label .. ": popup open but stack empty")
    expect(#state.windows > 0, label .. ": popup open but no windows")
  else
    expect(#state.menu_stack == 0, label .. ": popup closed but stack not empty")
    expect(#state.windows == 0, label .. ": popup closed but windows remain")
  end
end

refresh_topbar()

local mouse = { screenrow = 1, screencol = 1 }
local restore = H.stub_mouse(mouse)
local left_mouse = vim.fn.maparg("<LeftMouse>", "n", false, true).callback
local left_release = vim.fn.maparg("<LeftRelease>", "n", false, true).callback
local double_left_mouse = vim.fn.maparg("<2-LeftMouse>", "n", false, true).callback
local open_key = vim.fn.maparg("<F13>", "n", false, true).callback

expect(left_mouse ~= nil, "left mouse mapping missing")
expect(left_release ~= nil, "left release mapping missing")
expect(double_left_mouse ~= nil, "double left mouse mapping missing")
expect(open_key ~= nil, "open key mapping missing")

local function top_col(index)
  refresh_topbar()
  local start_col = state.label_positions[index]
  local width = vim.fn.strdisplaywidth(layout.top_bar_display_label(state.config.menus[index], index))
  return start_col + math.floor(width / 2)
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

local function double_click_top(index)
  mouse.screenrow = vim.o.lines - vim.o.cmdheight
  mouse.screencol = top_col(index)
  double_left_mouse()
end

local function ensure_file_popup()
  if state.active_top ~= 1 or not popup.is_open() then
    click_top(1)
  end
  if state.active_top ~= 1 then
    popup.activate_top_key("f")
  end
  if not popup.is_open() then
    popup.activate_top_key("f")
  end
end

local function click_parent_submenu_row()
  ensure_file_popup()
  local entry = state.menu_stack[1]
  entry.selected = 1
  popup.redraw_all()
  entry = state.menu_stack[1]
  local visible_row = (entry.selected or 1) - (entry.scroll_top or 1) + 1
  mouse.screenrow = entry.content_row + visible_row - 1
  mouse.screencol = entry.content_col + 1
  left_mouse()
end

local function double_click_parent_submenu_row()
  ensure_file_popup()
  local entry = state.menu_stack[1]
  entry.selected = 1
  popup.redraw_all()
  entry = state.menu_stack[1]
  local visible_row = (entry.selected or 1) - (entry.scroll_top or 1) + 1
  mouse.screenrow = entry.content_row + visible_row - 1
  mouse.screencol = entry.content_col + 1
  double_left_mouse()
end

local operations = {
  { name = "open_key", weight = 4, run = function() open_key() end },
  { name = "top_file_click", weight = 10, run = function() click_top(1) end },
  { name = "top_file_release", weight = 8, run = function() release_top(1) end },
  { name = "top_file_double", weight = 8, run = function() double_click_top(1) end },
  { name = "top_random_click", weight = 8, run = function() click_top(math.random(1, 3)) end },
  { name = "submenu_mouse_toggle", weight = 12, run = function() click_parent_submenu_row() end },
  { name = "submenu_mouse_double", weight = 10, run = function() double_click_parent_submenu_row() end },
  { name = "submenu_key_toggle", weight = 12, run = function() popup.activate_item_key("t") end },
  { name = "submenu_child_key", weight = 6, run = function() popup.activate_item_key("n") end },
  { name = "top_key_file", weight = 8, run = function() popup.activate_top_key("f") end },
  { name = "top_key_edit", weight = 6, run = function() popup.activate_top_key("e") end },
  { name = "go_back", weight = 6, run = function() popup.go_back() end },
  { name = "select_down", weight = 4, run = function() popup.select_row(1) end },
  { name = "activate_selected", weight = 4, run = function() popup.activate_selected() end },
}

local operations_by_name = {}
for _, operation in ipairs(operations) do
  operations_by_name[operation.name] = operation
end

local weighted = {}
for _, operation in ipairs(operations) do
  for _ = 1, operation.weight do
    table.insert(weighted, operation)
  end
end

local replay_steps = {}
if type(replay) == "string" and replay ~= "" then
  for part in replay:gmatch("[^,]+") do
    table.insert(replay_steps, part)
  end
end

local total_steps = #replay_steps > 0 and #replay_steps or 180

for step = 1, total_steps do
  local operation
  if #replay_steps > 0 then
    operation = operations_by_name[replay_steps[step]]
    if not operation then
      fail("unknown replay operation: " .. tostring(replay_steps[step]))
    end
  else
    operation = weighted[math.random(1, #weighted)]
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
print("ok - tests/integration/randomized_repeat_bias.lua")
