local state = require("orca_menu.state")
local layout = require("orca_menu.layout")
local actions = require("orca_menu.actions")

local M = {}
local activate_item_at_level

local function sync_hydra_exit_if_needed()
  if state.config and state.config.keys.mode_backend == "hydra" then
    local hydra_mode = require("orca_menu.hydra_mode")
    if hydra_mode.is_active() then
      hydra_mode.exit()
      return true
    end
  end
  return false
end

local function available_content_height()
  local border_rows = state.config.submenu.border and 2 or 0
  return math.max(vim.o.lines - vim.o.cmdheight - border_rows - 2, 1)
end

local function visible_height_for(entry)
  return math.max(math.min(#(entry.items or {}), available_content_height()), 1)
end

local function ensure_valid_selection(entry)
  local items = entry.items or {}
  if #items == 0 then
    entry.selected = 1
    return
  end

  local selected = math.max(math.min(entry.selected or 1, #items), 1)
  if items[selected] and items[selected].kind ~= "separator" then
    entry.selected = selected
    return
  end

  for idx, item in ipairs(items) do
    if item.kind ~= "separator" then
      entry.selected = idx
      return
    end
  end

  entry.selected = 1
end

local function ensure_scroll_visible(entry)
  ensure_valid_selection(entry)

  local visible_height = visible_height_for(entry)
  local max_scroll_top = math.max(#(entry.items or {}) - visible_height + 1, 1)
  local scroll_top = math.max(math.min(entry.scroll_top or 1, max_scroll_top), 1)
  local selected = entry.selected or 1

  if selected < scroll_top then
    scroll_top = selected
  elseif selected >= scroll_top + visible_height then
    scroll_top = selected - visible_height + 1
  end

  entry.scroll_top = math.max(math.min(scroll_top, max_scroll_top), 1)
  entry.visible_height = visible_height
end

local function selected_visible_index(entry)
  ensure_scroll_visible(entry)
  return math.max((entry.selected or 1) - (entry.scroll_top or 1) + 1, 1)
end

local function move_selection(entry, direction, steps, wrap)
  if not entry or #(entry.items or {}) == 0 then
    return false
  end

  local items = entry.items
  local selected = math.max(math.min(entry.selected or 1, #items), 1)
  local moved = false

  for _ = 1, math.max(steps or 1, 1) do
    local next_idx = selected

    while true do
      next_idx = next_idx + direction

      if wrap then
        if next_idx < 1 then
          next_idx = #items
        elseif next_idx > #items then
          next_idx = 1
        end
        if next_idx == selected then
          break
        end
      elseif next_idx < 1 or next_idx > #items then
        next_idx = selected
        break
      end

      if items[next_idx].kind ~= "separator" then
        selected = next_idx
        moved = true
        break
      end
    end

    if next_idx == selected and not moved then
      break
    end
  end

  if moved then
    entry.selected = selected
  end

  return moved
end

local function ensure_highlights()
  local normal_float = vim.api.nvim_get_hl(0, { name = state.config.highlights.menu, link = false })
  local menu_fg = normal_float.fg
  local menu_bg = normal_float.bg
  local special = vim.api.nvim_get_hl(0, { name = "Special", link = false })
  local pink_fg = special.fg

  vim.api.nvim_set_hl(0, "OrcaMenuHint", {
    fg = pink_fg,
    bg = menu_bg,
    default = false,
  })

  vim.api.nvim_set_hl(0, "OrcaMenuSelected", {
    fg = pink_fg,
    bg = menu_bg,
    bold = true,
    default = false,
  })
end

local function resolve_border_chars(border)
  if not border then
    return nil
  end

  if type(border) == "table" then
    local chars = vim.deepcopy(border)
    if #chars == 8 then
      return chars
    end
    return nil
  end

  local presets = {
    none = { "", "", "", "", "", "", "", "" },
    single = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
    double = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
    rounded = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    solid = { " ", " ", " ", " ", " ", " ", " ", " " },
    shadow = { "", "", " ", " ", " ", " ", "", "" },
  }

  return presets[border]
end

local function border_with_scroll_indicators(entry)
  local border = state.config.submenu.border
  local indicator_up = state.config.submenu.scroll_indicator_up
  local indicator_down = state.config.submenu.scroll_indicator_down
  local chars = resolve_border_chars(border)
  if not chars then
    return border
  end

  local max_scroll_top = math.max(#(entry.items or {}) - (entry.visible_height or #(entry.items or {})) + 1, 1)
  local has_up = (entry.scroll_top or 1) > 1
  local has_down = (entry.scroll_top or 1) < max_scroll_top
  local resolved_up = (type(indicator_up) == "string" and indicator_up ~= "") and indicator_up or "↑"
  local resolved_down = (type(indicator_down) == "string" and indicator_down ~= "") and indicator_down or "↓"

  if vim.fn.strdisplaywidth(resolved_up) ~= 1 then
    resolved_up = "↑"
  end

  if vim.fn.strdisplaywidth(resolved_down) ~= 1 then
    resolved_down = "↓"
  end

  if has_up then
    chars[3] = resolved_up
  end

  if has_down then
    chars[5] = resolved_down
  end

  return chars
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
  sync_hydra_exit_if_needed()
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
  local scroll_top = entry.scroll_top or 1
  local visible_end = math.min(scroll_top + (entry.visible_height or #entry.items) - 1, #entry.items)
  for idx = scroll_top, visible_end do
    local item = entry.items[idx]
    local line_idx = idx - scroll_top
    local hl = idx == (entry.selected or 1) and state.config.highlights.menu_sel or state.config.highlights.menu
    vim.api.nvim_buf_add_highlight(buf, state.namespace, hl, line_idx, 0, -1)
    if entry.rendered_lines and entry.rendered_lines[line_idx + 1] and entry.rendered_lines[line_idx + 1].hint_start and entry.rendered_lines[line_idx + 1].hint_end then
      vim.api.nvim_buf_add_highlight(
        buf,
        state.namespace,
        state.config.highlights.accelerator,
        line_idx,
        entry.rendered_lines[line_idx + 1].hint_start,
        entry.rendered_lines[line_idx + 1].hint_end
      )
    end
  end
end

local function draw_level(level)
  local entry = state.menu_stack[level]
  if not entry then
    return
  end

  ensure_scroll_visible(entry)

  local width = layout.submenu_width(entry.items)
  local max_hint_width = layout.max_hint_width(entry.items)
  local arrow_width = layout.arrow_width(entry.items)
  local lines = {}
  local rendered_lines = {}
  local scroll_top = entry.scroll_top or 1
  local visible_end = math.min(scroll_top + (entry.visible_height or #entry.items) - 1, #entry.items)
  for idx = scroll_top, visible_end do
    local item = entry.items[idx]
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
  else
    local prev = state.menu_stack[level - 1]
    local target_content_row = (prev.content_row or prev.row) + math.max(selected_visible_index(prev) - 1, 0)
    row = target_content_row - border_size - 1
    col = (prev.content_col or prev.col) + (prev.content_width or prev.width)

    local max_row = math.max(0, vim.o.lines - vim.o.cmdheight - #lines - (border_size * 2) - 1)
    row = math.max(math.min(row, max_row), 0)
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = math.max(#lines, 1),
    focusable = false,
    style = "minimal",
    border = border_with_scroll_indicators(entry),
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
end

function M.redraw_all()
  ensure_highlights()
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
    { items = items, selected = 1, scroll_top = 1 },
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
  if #(entry.items or {}) == 0 then
    return
  end
  if move_selection(entry, delta < 0 and -1 or 1, 1, true) then
    M.redraw_all()
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
      scroll_top = 1,
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

  if #state.menu_stack == 0 then
    return false
  end

  local lowered_key = key:lower()
  for level = #state.menu_stack, 1, -1 do
    local entry = state.menu_stack[level]
    for idx, item in ipairs(entry.items or {}) do
      if item.kind ~= "separator" and type(item.key) == "string" and item.key:lower() == lowered_key then
        activate_item_at_level(level, idx)
        return true
      end
    end

    for idx, item in ipairs(entry.items or {}) do
      if item.kind ~= "separator" and item.accelerator == lowered_key then
        activate_item_at_level(level, idx)
        return true
      end
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

local function content_hit_level_at(screen_row, screen_col)
  for idx = #state.menu_stack, 1, -1 do
    local entry = state.menu_stack[idx]
    local row_start = entry.content_row or entry.row
    local row_end = row_start + (entry.content_height or entry.height) - 1
    local col_start = entry.content_col or entry.col
    local col_end = col_start + (entry.content_width or entry.width) - 1
    if screen_row >= row_start and screen_row <= row_end and screen_col >= col_start and screen_col <= col_end then
      return idx
    end
  end
  return nil
end

local function frame_hit_level_at(screen_row, screen_col)
  for idx = #state.menu_stack, 1, -1 do
    local entry = state.menu_stack[idx]
    local row_start = entry.frame_row or entry.row
    local row_end = row_start + (entry.frame_height or entry.height) - 1
    local col_start = entry.frame_col or entry.col
    local col_end = col_start + (entry.frame_width or entry.width) - 1
    if screen_row >= row_start and screen_row <= row_end and screen_col >= col_start and screen_col <= col_end then
      return idx
    end
  end
  return nil
end

local function hit_level_at(screen_row, screen_col)
  return content_hit_level_at(screen_row, screen_col) or frame_hit_level_at(screen_row, screen_col)
end

function M.scroll_at_mouse(delta)
  if not M.is_open() or #state.menu_stack == 0 then
    return false
  end

  local mouse = vim.fn.getmousepos()
  local screen_row = math.max((mouse.screenrow or 1), 1)
  local screen_col = math.max((mouse.screencol or 1), 1)
  local level = hit_level_at(screen_row, screen_col)
  if not level then
    return false
  end

  trim_stack_to(level)

  local entry = state.menu_stack[level]
  if not entry or #(entry.items or {}) == 0 then
    return true
  end

  ensure_scroll_visible(entry)
  local step = math.max((entry.visible_height or 1) - 1, 1)
  if move_selection(entry, delta < 0 and -1 or 1, step, false) then
    M.redraw_all()
  end

  return true
end

local function item_at_level_row(level, screen_row)
  local entry = state.menu_stack[level]
  if not entry then
    return nil, nil
  end

  local visible_row = screen_row - entry.content_row + 1
  local visible_height = entry.visible_height or #(entry.items or {})
  if visible_row < 1 or visible_row > visible_height then
    return nil, visible_row
  end

  local row = (entry.scroll_top or 1) + visible_row - 1

  if row < 1 or row > #(entry.items or {}) then
    return nil, row
  end

  return entry.items[row], row
end

activate_item_at_level = function(level, row)
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
    if same_selected_parent then
      trim_stack_to(level)
      M.redraw_all()
      return
    end

    trim_stack_to(level)

    table.insert(state.menu_stack, {
      items = item.items or {},
      selected = 1,
      scroll_top = 1,
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
  local content_hit_level = content_hit_level_at(screen_row, screen_col)
  local frame_hit_level = frame_hit_level_at(screen_row, screen_col)

  local clicked_level = content_hit_level or frame_hit_level

  if not clicked_level then
    M.close_all()
    return
  end

  local entry = state.menu_stack[clicked_level]
  local item, row = item_at_level_row(clicked_level, screen_row)

  if not item then
    return
  end

  activate_item_at_level(clicked_level, row)
end

return M
