local state = require("orca_menu.state")
local layout = require("orca_menu.layout")
local actions = require("orca_menu.actions")

local M = {}

local function debug_log(lines)
  local logfile = "/tmp/orca_menu_mouse.log"
  local fd = io.open(logfile, "a")
  if not fd then
    return
  end
  fd:write(os.date("[%Y-%m-%d %H:%M:%S] "))
  fd:write(table.concat(lines, " | "))
  fd:write("\n")
  fd:close()
end

local function destroy_windows_only()
  for _, win in ipairs(vim.deepcopy(state.windows)) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  for _, buf in ipairs(vim.deepcopy(state.buffers)) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  state.windows = {}
  state.buffers = {}
end

function M.close_all()
  destroy_windows_only()
  state.menu_stack = {}
  state.menu_mode = false
  require("orca_menu.input").disable_keys()
end

function M.is_open()
  return #state.windows > 0
end

function M.enter_menu_mode(index)
  state.active_top = index or state.active_top
  state.menu_mode = true
  state.menu_stack = {}
  require("orca_menu.input").enable_keys()
end

local function highlight_entry(buf, entry)
  vim.api.nvim_buf_clear_namespace(buf, state.namespace, 0, -1)
  for idx, item in ipairs(entry.items) do
    local hl = idx == (entry.selected or 1) and state.config.highlights.menu_sel or state.config.highlights.menu
    vim.api.nvim_buf_add_highlight(buf, state.namespace, hl, idx - 1, 0, -1)
    if entry.rendered_lines and entry.rendered_lines[idx] and entry.rendered_lines[idx].hint_start and entry.rendered_lines[idx].hint_end then
      vim.api.nvim_buf_add_highlight(
        buf,
        state.namespace,
        state.config.highlights.accelerator,
        idx - 1,
        entry.rendered_lines[idx].hint_start,
        entry.rendered_lines[idx].hint_end
      )
    end
    if item.accelerator_index and item.kind ~= "separator" and not (item.key and item.key ~= "") then
      vim.api.nvim_buf_add_highlight(buf, state.namespace, state.config.highlights.accelerator, idx - 1, item.accelerator_index - 1, item.accelerator_index)
    end
  end
end

local function draw_level(level)
  local entry = state.menu_stack[level]
  if not entry then
    return
  end

  local width = layout.submenu_width(entry.items)
  local max_hint_width = layout.max_hint_width(entry.items)
  local arrow_width = layout.arrow_width(entry.items)
  local lines = {}
  local rendered_lines = {}
  for _, item in ipairs(entry.items) do
    local rendered = layout.format_item_line(item, width, max_hint_width, arrow_width)
    table.insert(rendered_lines, rendered)
    table.insert(lines, rendered.text)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  table.insert(state.buffers, buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local row, col
  local border_size = state.config.submenu.border and 1 or 0
  if level == 1 then
    row = state.anchor.row
    col = state.anchor.col
    debug_log({
      "orca_menu_version=child-align-v2",
      string.format("draw_level=%d kind=top anchor_row=%s anchor_col=%s", level, tostring(row), tostring(col)),
    })
  else
    local prev = state.menu_stack[level - 1]
    local target_content_row = (prev.content_row or prev.row) + math.max((prev.selected or 1) - 1, 0)
    row = target_content_row - border_size - 1
    col = (prev.content_col or prev.col) + (prev.content_width or prev.width)
    local max_row = math.max(0, vim.o.lines - vim.o.cmdheight - #lines - 3)
    row = math.min(row, max_row)
    debug_log({
      "orca_menu_version=child-align-v2",
      string.format("draw_level=%d kind=child prev_selected=%s prev_content_row=%s target_content_row=%s border_size=%s requested_row=%s requested_col=%s", level, tostring(prev.selected), tostring(prev.content_row or prev.row), tostring(target_content_row), tostring(border_size), tostring(row), tostring(col)),
    })
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = math.max(#lines, 1),
    focusable = false,
    style = "minimal",
    border = state.config.submenu.border,
    zindex = 250 + level,
  })
  table.insert(state.windows, win)
  vim.api.nvim_set_option_value("winhl", "Normal:" .. state.config.highlights.menu, { win = win })

  local screen_pos = vim.fn.win_screenpos(win)
  local cell_pos = vim.fn.screenpos(win, 1, 1)
  local ok_win_pos, win_pos = pcall(vim.api.nvim_win_get_position, win)
  local actual_row = math.max((screen_pos[1] or 1), 1)
  local actual_col = math.max((screen_pos[2] or 1), 1)
  local actual_width = vim.api.nvim_win_get_width(win)
  local actual_height = vim.api.nvim_win_get_height(win)
  local win_config = vim.api.nvim_win_get_config(win)
  local win_pos_row = ok_win_pos and win_pos and win_pos[1] and (win_pos[1] + 1) or nil
  local win_pos_col = ok_win_pos and win_pos and win_pos[2] and (win_pos[2] + 1) or nil
  local raw_content_row = math.max(tonumber(cell_pos.row) or win_pos_row or actual_row, 1)
  local raw_content_col = math.max(tonumber(cell_pos.col) or win_pos_col or actual_col, 1)
  local raw_frame_row = raw_content_row - border_size
  local raw_frame_col = raw_content_col - border_size
  local frame_width = actual_width + (border_size * 2)
  local frame_height = actual_height + (border_size * 2)
  local max_frame_col = math.max(vim.o.columns - frame_width + 1, 1)
  local max_frame_row = math.max(vim.o.lines - vim.o.cmdheight - frame_height, 1)
  local visible_frame_row = math.min(math.max(raw_frame_row, 1), max_frame_row)
  local visible_frame_col = math.min(math.max(raw_frame_col, 1), max_frame_col)
  local content_row = visible_frame_row + border_size
  local content_col = visible_frame_col + border_size

  entry.buf = buf
  entry.win = win
  entry.row = actual_row
  entry.col = actual_col
  entry.width = actual_width
  entry.height = actual_height
  entry.content_row = content_row
  entry.content_col = content_col
  entry.content_width = actual_width
  entry.content_height = actual_height
  entry.frame_row = visible_frame_row
  entry.frame_col = visible_frame_col
  entry.frame_width = frame_width
  entry.frame_height = frame_height
  entry.rendered_lines = rendered_lines
  highlight_entry(buf, entry)

  debug_log({
    "orca_menu_version=child-align-v2",
    string.format("drawn level=%d frame_row=%s frame_col=%s content_row=%s content_col=%s width=%s height=%s", level, tostring(entry.frame_row), tostring(entry.frame_col), tostring(entry.content_row), tostring(entry.content_col), tostring(entry.content_width), tostring(entry.content_height)),
  })
end

function M.redraw_all()
  local stack = vim.deepcopy(state.menu_stack)
  destroy_windows_only()
  state.menu_stack = stack
  for level = 1, #state.menu_stack do
    draw_level(level)
  end
end

function M.open_top(index)
  if index and not layout.is_top_visible(index) then
    return
  end
  state.active_top = index or state.active_top
  local items = actions.current_items()
  state.anchor = layout.resolve_anchor(state.active_top, items)
  state.menu_mode = true
  require("orca_menu.input").enable_keys()
  state.menu_stack = {
    { items = items, selected = 1 },
  }
  M.redraw_all()
end

function M.move_top(delta)
  if not M.is_open() then
    M.enter_menu_mode(state.active_top)
  end
  local count = #state.config.menus
  for offset = 1, count do
    local next_index = ((state.active_top - 1 + (delta * offset)) % count) + 1
    if layout.is_top_visible(next_index) then
      state.active_top = next_index
      if M.is_open() then
        M.open_top(state.active_top)
      end
      return
    end
  end
end

function M.select_row(delta)
  local entry = state.menu_stack[#state.menu_stack]
  if not entry then
    return
  end
  local idx = entry.selected or 1
  for _ = 1, #entry.items do
    idx = ((idx - 1 + delta) % #entry.items) + 1
    if entry.items[idx].kind ~= "separator" then
      entry.selected = idx
      M.redraw_all()
      return
    end
  end
end

function M.activate_selected()
  if not M.is_open() then
    M.open_top(state.active_top)
    return
  end
  local entry = state.menu_stack[#state.menu_stack]
  if not entry then
    return
  end
  local item = entry.items[entry.selected or 1]
  if not item or item.kind == "separator" then
    return
  end
  if item.kind == "submenu" then
    table.insert(state.menu_stack, {
      items = item.items or {},
      selected = 1,
    })
    M.redraw_all()
    return
  end
  actions.run(item)
end

function M.activate_item_key(key)
  if not key or key == "" then
    return false
  end

  local entry = state.menu_stack[#state.menu_stack]
  if not entry then
    return false
  end

  local lowered_key = key:lower()
  for idx, item in ipairs(entry.items or {}) do
    if item.kind ~= "separator" and type(item.key) == "string" and item.key:lower() == lowered_key then
      entry.selected = idx
      M.redraw_all()
      M.activate_selected()
      return true
    end
  end

  for idx, item in ipairs(entry.items or {}) do
    if item.kind ~= "separator" and item.accelerator == lowered_key then
      entry.selected = idx
      M.redraw_all()
      M.activate_selected()
      return true
    end
  end

  return false
end

function M.activate_top_key(key)
  if not key or key == "" then
    return false
  end

  local lowered_key = key:lower()
  for index, menu in ipairs(state.config.menus or {}) do
    if layout.is_top_visible(index) and type(menu.key) == "string" and menu.key:lower() == lowered_key then
      state.active_top = index
      M.open_top(index)
      return true
    end
  end

  for index, menu in ipairs(state.config.menus or {}) do
    if layout.is_top_visible(index) and menu.accelerator == lowered_key then
      state.active_top = index
      M.open_top(index)
      return true
    end
  end

  return false
end

local function trim_stack_to(level)
  while #state.menu_stack > level do
    table.remove(state.menu_stack)
  end
end

local function item_at_level_row(level, screen_row)
  local entry = state.menu_stack[level]
  if not entry then
    return nil, nil
  end

  local row = screen_row - entry.content_row + 1
  if row < 1 or row > #(entry.items or {}) then
    return nil, row
  end

  return entry.items[row], row
end

local function activate_item_at_level(level, row)
  local entry = state.menu_stack[level]
  if not entry then
    return
  end

  local item = entry.items[row]
  if not item or item.kind == "separator" then
    return
  end

  local had_children = #state.menu_stack > level
  local was_selected = entry.selected or 1
  entry.selected = row

  if item.kind == "submenu" then
    local same_selected_parent = had_children and was_selected == row
    trim_stack_to(level)
    if same_selected_parent then
      M.redraw_all()
      return
    end

    table.insert(state.menu_stack, {
      items = item.items or {},
      selected = 1,
    })
    M.redraw_all()
    return
  end

  trim_stack_to(level)
  actions.run(item)
end

function M.go_back()
  if #state.menu_stack > 1 then
    table.remove(state.menu_stack)
    M.redraw_all()
  else
    M.close_all()
  end
end

function M.handle_mouse()
  local mouse = vim.fn.getmousepos()
  local screen_col = math.max((mouse.screencol or 1), 1)
  local bar_index = layout.label_hit_at_col(screen_col)

  if bar_index then
    if state.active_top == bar_index and M.is_open() then
      M.close_all()
    else
      M.open_top(bar_index)
    end
    return
  end

  local screen_row = math.max((mouse.screenrow or 1), 1)
  local content_hit_level
  local frame_hit_level

  for idx = #state.menu_stack, 1, -1 do
    local entry = state.menu_stack[idx]
    local row_start = entry.content_row or entry.row
    local row_end = row_start + (entry.content_height or entry.height) - 1
    local col_start = entry.content_col or entry.col
    local col_end = col_start + (entry.content_width or entry.width) - 1
    if screen_row >= row_start and screen_row <= row_end and screen_col >= col_start and screen_col <= col_end then
      content_hit_level = idx
      break
    end
  end

  for idx = #state.menu_stack, 1, -1 do
    local entry = state.menu_stack[idx]
    local row_start = entry.frame_row or entry.row
    local row_end = row_start + (entry.frame_height or entry.height) - 1
    local col_start = entry.frame_col or entry.col
    local col_end = col_start + (entry.frame_width or entry.width) - 1
    if screen_row >= row_start and screen_row <= row_end and screen_col >= col_start and screen_col <= col_end then
      frame_hit_level = idx
      break
    end
  end

  local clicked_level = content_hit_level or frame_hit_level

  if not clicked_level then
    M.close_all()
    return
  end

  local entry = state.menu_stack[clicked_level]
  local row = screen_row - (entry.content_row or entry.row) + 1
  local item = item_at_level_row(clicked_level, screen_row)

  if not item then
    return
  end

  activate_item_at_level(clicked_level, row)
end

return M
