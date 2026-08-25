local state = require("orca_menu.state")

local M = {}

local function top_bar_base_label(menu, index)
  return (menu and menu.label ~= "") and menu.label or tostring(index)
end

local function has_popup_border()
  local border = state.config and state.config.submenu and state.config.submenu.border
  return border ~= nil and border ~= false
end

local function truncate_display(text, max_width)
  if max_width <= 0 then
    return ""
  end

  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end

  if max_width <= 3 then
    return string.rep(".", max_width)
  end

  local target = max_width - 3
  local out = {}
  local width = 0
  for _, char in ipairs(vim.fn.split(text, [[\zs]])) do
    local char_width = vim.fn.strdisplaywidth(char)
    if width + char_width > target then
      break
    end
    table.insert(out, char)
    width = width + char_width
  end
  return table.concat(out) .. "..."
end

local function checked_icon()
  local submenu = state.config and state.config.submenu or {}
  if type(submenu.checked_icon) == "string" and submenu.checked_icon ~= "" then
    return submenu.checked_icon
  end
  return ""
end

function M.item_checked(item)
  if not item or item.kind == "separator" then
    return false
  end

  if type(item.checked) == "function" then
    local ok, value = pcall(item.checked, item)
    return ok and not not value or false
  end

  return not not item.checked
end

function M.item_enabled(item)
  if not item or item.kind == "separator" then
    return false
  end

  if type(item.enabled) == "function" then
    local ok, value = pcall(item.enabled, item)
    return ok and not not value or false
  end

  if item.enabled ~= nil then
    return not not item.enabled
  end

  if type(item.executable) == "function" then
    local ok, value = pcall(item.executable, item)
    return ok and not not value or false
  end

  if item.executable ~= nil then
    return not not item.executable
  end

  return true
end

function M.top_menu_enabled(menu)
  return M.item_enabled(menu)
end

function M.display_key_hint(key)
  if type(key) ~= "string" or key == "" then
    return ""
  end

  local named = {
    ["<Space>"] = "Space",
    ["<Tab>"] = "Tab",
    ["<CR>"] = "Enter",
    ["<Enter>"] = "Enter",
    ["<Esc>"] = "Esc",
    ["<BS>"] = "Back",
    ["<Del>"] = "Del",
    ["<Up>"] = "↑",
    ["<Down>"] = "↓",
    ["<Left>"] = "←",
    ["<Right>"] = "→",
  }

  if named[key] then
    return named[key]
  end

  local modifier, tail = key:match("^<([CASM])%-(.+)>$")
  if modifier and tail then
    local modifier_names = {
      C = "Ctrl",
      A = "Alt",
      S = "Shift",
      M = "Meta",
    }
    local tail_display = named["<" .. tail .. ">"] or tail
    return string.format("%s+%s", modifier_names[modifier] or modifier, tail_display)
  end

  return key:gsub("^<", ""):gsub(">$", "")
end

function M.top_bar_display_label(menu, index)
  local label = top_bar_base_label(menu, index)
  local hint = M.display_key_hint(menu and menu.key)
  if hint == "" then
    return label
  end

  local format = state.config
    and state.config.topbar
    and state.config.topbar.hint_format
    or "{label}({hint})"

  if type(format) == "function" then
    local ok, rendered = pcall(format, {
      label = label,
      hint = hint,
      menu = menu,
      index = index,
    })
    if ok and type(rendered) == "string" and rendered ~= "" then
      return rendered
    end
    return label
  end

  if type(format) ~= "string" or format == "" then
    format = "{label}({hint})"
  end

  local rendered = format
    :gsub("{label}", label)
    :gsub("{hint}", hint)

  return rendered
end

function M.item_right_hint(item)
  if not item or item.kind == "separator" then
    return ""
  end

  return M.display_key_hint(item.key)
end

function M.max_hint_width(items)
  local width = 0
  for _, item in ipairs(items or {}) do
    width = math.max(width, vim.fn.strdisplaywidth(M.item_right_hint(item)))
  end
  return width
end

function M.arrow_width(items)
  for _, item in ipairs(items or {}) do
    if item.kind == "submenu" then
      return vim.fn.strdisplaywidth("›")
    end
  end
  return 0
end

function M.check_width(items)
  for _, item in ipairs(items or {}) do
    if M.item_checked(item) then
      return vim.fn.strdisplaywidth(checked_icon())
    end
  end
  return 0
end

function M.format_item_line(item, total_width, hint_width, arrow_width, check_width)
  if item.kind == "separator" then
    return {
      text = string.rep("─", total_width),
      hint_start = nil,
      hint_end = nil,
      check_start = nil,
      check_end = nil,
    }
  end

  local right = M.item_right_hint(item)
  local check = M.item_checked(item) and checked_icon() or ""
  local arrow = item.kind == "submenu" and "›" or ""
  local check_section_width = check_width or vim.fn.strdisplaywidth(check)
  local right_section_width = hint_width
  if check_section_width > 0 then
    right_section_width = right_section_width + 1 + check_section_width
  end
  if arrow_width > 0 then
    right_section_width = right_section_width + 1 + arrow_width
  end
  local gap = right_section_width > 0 and 2 or 0
  local available_label_width = math.max(total_width - right_section_width - gap, 1)
  local label = truncate_display(item.label, available_label_width)
  local label_width = vim.fn.strdisplaywidth(label)
  local label_pad = math.max(available_label_width - label_width, 0)
  local line = label .. string.rep(" ", label_pad)
  local hint_start = nil
  local hint_end = nil
  local check_start = nil
  local check_end = nil

  if right_section_width > 0 then
    local right_width = vim.fn.strdisplaywidth(right)
    line = line .. string.rep(" ", gap)
    if check_section_width > 0 then
      line = line .. string.rep(" ", math.max(check_section_width - vim.fn.strdisplaywidth(check), 0))
      check_start = #line
      line = line .. check
      check_end = #line
      line = line .. " "
    end
    line = line .. string.rep(" ", math.max(hint_width - right_width, 0))
    hint_start = #line
    line = line .. right
    hint_end = #line
    if arrow_width > 0 then
      line = line .. " "
      line = line .. string.rep(" ", math.max(arrow_width - vim.fn.strdisplaywidth(arrow), 0))
      line = line .. arrow
    end
  end

  return {
    text = line,
    hint_start = hint_start,
    hint_end = hint_end,
    check_start = check_start,
    check_end = check_end,
  }
end

function M.current_menu()
  return state.config.menus[state.active_top]
end

function M.submenu_width(items)
  local width = state.config.submenu.min_width
  local hint_width = M.max_hint_width(items)
  local arrow_width = M.arrow_width(items)
  local check_width = M.check_width(items)
  for _, item in ipairs(items or {}) do
    local right_section_width = hint_width
    if check_width > 0 then
      right_section_width = right_section_width + 1 + check_width
    end
    if arrow_width > 0 then
      right_section_width = right_section_width + 1 + arrow_width
    end
    local gap = right_section_width > 0 and 2 or 0
    width = math.max(width, vim.fn.strdisplaywidth(item.label) + gap + right_section_width)
  end
  width = math.min(width, math.max(vim.o.columns - 4, state.config.submenu.min_width))
  return width
end

function M.popup_height(items)
  local border_rows = has_popup_border() and 2 or 0
  local max_height = math.max(vim.o.lines - vim.o.cmdheight - border_rows - 2, 1)
  return math.max(math.min(#(items or {}), max_height), 1)
end

local function position_window(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    return winid
  end
  if state.menu_owner_win and vim.api.nvim_win_is_valid(state.menu_owner_win) then
    return state.menu_owner_win
  end
  return vim.api.nvim_get_current_win()
end

local function position_id(index)
  return "orca_menu:" .. index
end

-- Lualine's component span also includes its trailing separator. The click
-- marker only covers Orca's rendered content, so derive that narrower span.
local function component_content_width(index)
  return vim.fn.strdisplaywidth(require("orca_menu.lualine").visible_component_at(index))
end

function M.refresh_label_positions(winid)
  winid = position_window(winid)
  state.label_positions = {}
  state.component_positions = {}
  state.visible_labels = {}

  local lualine = require("lualine")
  local positions = lualine.get_component_positions({
    place = "statusline",
    winid = winid,
  }) or {}
  local spacing = state.config.lualine.spacing or " "
  local spacing_width = vim.fn.strdisplaywidth(spacing)

  for index, menu in ipairs(state.config.menus or {}) do
    local position = positions[position_id(index)]
    if position and position.visible and position.screen then
      local label = M.top_bar_display_label(menu, index)
      local label_start = position.screen.start_col + spacing_width
      local label_width = vim.fn.strdisplaywidth(label)
      local label_end = label_start + label_width - 1
      if label_width > 0 and label_end <= position.screen.end_col then
        state.label_positions[index] = label_start
        state.component_positions[index] = position
        state.visible_labels[index] = true
      end
    end
  end
end

function M.is_top_visible(index)
  M.refresh_label_positions()
  return state.visible_labels and state.visible_labels[index] == true
end

function M.is_statusline_row(row)
  for _, position in pairs(state.component_positions or {}) do
    if position.screen and position.screen.row == row then
      return true
    end
  end
  return false
end

function M.label_hit_at_col(col, mouse)
  mouse = mouse or vim.fn.getmousepos()
  M.refresh_label_positions(mouse.winid)

  local statusline_hit = M.is_statusline_row(mouse.screenrow)
  local candidates = {}
  local hit

  for index, menu in ipairs(state.config.menus) do
    local start_col = state.label_positions[index]
    local position = state.component_positions[index]
    local display_label = M.top_bar_display_label(menu, index)
    local label_width = vim.fn.strdisplaywidth(display_label)
    local end_col = start_col and start_col + label_width - 1 or nil
    local row_match = position and position.screen and position.screen.row == mouse.screenrow or false
    local component_start_col = position and position.screen and position.screen.start_col
    local component_end_col = position and position.screen and position.screen.end_col
    local hit_start_col = component_start_col
    local content_width = component_content_width(index)
    local hit_end_col = hit_start_col and content_width > 0 and hit_start_col + content_width - 1 or nil
    if hit_end_col and component_end_col then
      hit_end_col = math.min(hit_end_col, component_end_col)
    end
    local col_match = hit_start_col
      and hit_end_col
      and col >= hit_start_col
      and col <= hit_end_col
      or false
    local candidate = {
      index = index,
      start_col = start_col,
      end_col = end_col,
      hit_start_col = hit_start_col,
      hit_end_col = hit_end_col,
      content_width = content_width,
      label_width = label_width,
      row_match = row_match,
      col_match = col_match,
      hit = start_col ~= nil and position ~= nil and position.screen ~= nil and statusline_hit and row_match and col_match
        or false,
    }
    if position and position.screen then
      candidate.component_row = position.screen.row
      candidate.component_start_col = position.screen.start_col
      candidate.component_end_col = position.screen.end_col
    end
    table.insert(candidates, candidate)

    if candidate.hit then
      hit = index
      break
    end
  end

  state.trace_mouse("label_hit_at_col", {
    phase = "label_hit_test",
    input_col = col,
    mouse_screenrow = mouse.screenrow,
    mouse_screencol = mouse.screencol,
    mouse_winid = mouse.winid,
    statusline_hit = statusline_hit,
    hit = hit,
    candidates = candidates,
  }, mouse)

  return hit
end

function M.resolve_anchor(index, items)
  M.refresh_label_positions()
  local start_col = state.label_positions[index]
  local component_position = state.component_positions[index]
  local winid = position_window(component_position and component_position.winid)
  local menu = state.config.menus[index]
  local display_label = M.top_bar_display_label(menu, index)
  local label_width = vim.fn.strdisplaywidth(display_label)
  local popup_width = M.submenu_width(items)
  local col

  if start_col then
    local right_anchor = start_col + label_width - 1
    local highlight_extends_right = state.menu_mode
      and state.active_top == index
      and state.config
      and state.config.highlights
      and state.config.highlights.topbar_active_preserve_bg == false

    if highlight_extends_right and component_position.screen then
      right_anchor = component_position.screen.end_col
    end

    local right_aligned_col = right_anchor - popup_width + 1
    local screen_origin = 1
    if vim.o.laststatus ~= 3 then
      local ok, screen_pos = pcall(vim.fn.win_screenpos, winid)
      if ok and screen_pos and screen_pos[2] then
        screen_origin = screen_pos[2]
      end
    end
    local relative_col = right_aligned_col - screen_origin + 1
    local available_width = vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(winid)
    col = math.max(math.min(relative_col - 3, available_width - popup_width + 1), 1)
  else
    col = math.max(state.anchor.col or 1, 1)
  end

  local height = M.popup_height(items)
  local border_rows = has_popup_border() and 2 or 0
  local statusline_row = vim.o.lines - vim.o.cmdheight
  local row = math.max(1, statusline_row - height - border_rows - 1)
  return { row = row, col = col }
end

return M
