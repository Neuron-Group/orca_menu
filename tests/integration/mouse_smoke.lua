local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_mouse_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
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
            vim.g.orca_mouse_action = vim.g.orca_mouse_action + 1
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

H.render_statusline()
layout.refresh_label_positions()

local statusline_row = vim.o.lines - vim.o.cmdheight
local restore = H.stub_mouse({
  screenrow = statusline_row,
  screencol = state.label_positions[1],
})

popup.handle_mouse()
H.truthy(popup.is_open(), "mouse click on visible top label should open popup")
H.eq(state.active_top, 1, "mouse click should target the clicked top menu")

popup.handle_mouse()
H.falsy(popup.is_open(), "clicking the same top label should close the popup tree")
restore()

for index, position in pairs(state.component_positions) do
  local item = position.screen.item or position.screen
  local content_end = item.end_col
  local restore_component_edge = H.stub_mouse({
    screenrow = statusline_row,
    screencol = content_end,
  })
  popup.handle_mouse()
  H.truthy(popup.is_open(), "the right edge of a lualine component should open its menu")
  H.eq(state.active_top, index, "the right edge should target its lualine menu")
  popup.close_all()
  restore_component_edge()
end

for index, position in pairs(state.component_positions) do
  local item = position.screen.item or position.screen
  local content_end = item.end_col
  for col = item.start_col, content_end do
    local restore_component_cell = H.stub_mouse({
      screenrow = statusline_row,
      screencol = col,
    })
    popup.handle_mouse()
    H.truthy(popup.is_open(), "every rendered component cell should open its menu")
    H.eq(state.active_top, index, "every rendered component cell should target its menu")
    popup.close_all()
    restore_component_cell()
  end
end

local first_position = state.component_positions[1]
local first_item = first_position.screen.item or first_position.screen
local first_content_end = first_item.end_col
if first_content_end < vim.o.columns then
  local restore_separator_mouse = H.stub_mouse({
    screenrow = statusline_row,
    screencol = first_content_end + 1,
  })
  popup.handle_mouse()
  H.falsy(popup.is_open(), "a lualine separator should not belong to the preceding menu")
  restore_separator_mouse()
end

local native_clicks = 0
local trace_path = vim.fn.tempname() .. "-orca-mouse-map.jsonl"
vim.fn.writefile({}, trace_path)
state.mouse_trace_path = trace_path
vim.keymap.set("n", "<LeftMouse>", function()
  native_clicks = native_clicks + 1
end, { buffer = 0 })

local restore_statusline_mouse = H.stub_mouse({
  screenrow = statusline_row,
  screencol = (state.component_positions[1].screen.item or state.component_positions[1].screen).end_col,
})
vim.fn.feedkeys(vim.keycode("<LeftMouse>"), "xt")
H.flush()
H.flush()

H.truthy(popup.is_open(), "topbar click should open from a buffer with a local mouse mapping")
H.eq(native_clicks, 0, "Orca should intercept a topbar click before the local mapping")

local trace
for _, line in ipairs(vim.fn.readfile(trace_path)) do
  local candidate = vim.json.decode(line)
  if candidate.extra and candidate.extra.phase == "pre_mapping" then
    trace = candidate
    break
  end
end
H.truthy(trace, "mouse trace should contain the pre-mapping phase")
H.eq(trace.extra.phase, "pre_mapping", "mouse trace should record the pre-mapping phase")
H.eq(trace.extra.mapping.buffer, 1, "mouse trace should identify the buffer-local mapping")
H.eq(trace.extra.statusline_hit, true, "mouse trace should identify the topbar hit")
H.eq(trace.extra.geometry.statusline_row, statusline_row, "mouse trace should record the statusline row")
H.eq(trace.extra.geometry.labels[1].label_start, state.label_positions[1], "mouse trace should record the label start")
H.eq(
  trace.extra.geometry.labels[1].label_end,
  state.label_positions[1] + vim.fn.strdisplaywidth("File(f)") - 1,
  "mouse trace should record the complete label hitbox"
)

popup.close_all()
H.flush()
local non_orca_mouse = {
  screenrow = 1,
  screencol = vim.o.columns,
}
restore_statusline_mouse()
local restore_native_mouse = H.stub_mouse(non_orca_mouse)
vim.fn.feedkeys(vim.keycode("<LeftMouse>"), "xt")
H.flush()
H.eq(native_clicks, 1, "non-Orca clicks should reach the existing local mapping")
restore_native_mouse()

for index, position in pairs(state.component_positions) do
  local item = position.screen.item or position.screen
  local content_end = item.end_col
  for col = item.start_col, content_end do
    local restore_component_cell = H.stub_mouse({
      screenrow = statusline_row,
      screencol = col,
    })
    popup.close_all()
    vim.fn.feedkeys(vim.keycode("<LeftMouse>"), "xt")
    H.flush()
    H.flush()
    H.truthy(popup.is_open(), "real mouse clicks should open every component cell")
    H.eq(state.active_top, index, "real mouse clicks should target their component")
    restore_component_cell()
  end
end

state.mouse_trace_path = nil

require("orca_menu").open_menu(1)
local entry = state.menu_stack[1]
local restore_item = H.stub_mouse({
  screenrow = entry.content_row,
  screencol = entry.content_col,
})

vim.fn.feedkeys(vim.keycode("<LeftMouse>"), "xt")
H.flush()
H.eq(vim.g.orca_mouse_action, 1, "mouse click on a deepest popup item should execute its action")
H.falsy(popup.is_open(), "mouse item activation should close popup tree")

restore_item()
H.finish()
print("ok - tests/integration/mouse_smoke.lua")
