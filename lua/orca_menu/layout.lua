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

  if right_section_width > 0 then
    local right_width = vim.fn.strdisplaywidth(right)
    line = line .. string.rep(" ", gap)
    if check_section_width > 0 then
      line = line .. string.rep(" ", math.max(check_section_width - vim.fn.strdisplaywidth(check), 0))
      line = line .. check
      line = line .. " "
    end
    line = line .. string.rep(" ", math.max(hint_width - right_width, 0))
    hint_start = vim.fn.strdisplaywidth(line)
    line = line .. right
    hint_end = hint_start + right_width
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

local function evaluated_statusline()
  local ok, evaluated = pcall(vim.api.nvim_eval_statusline, vim.wo.statusline, {
    winid = vim.api.nvim_get_current_win(),
    maxwidth = vim.o.columns,
    highlights = false,
    use_winbar = false,
  })
  if not ok or not evaluated or type(evaluated.str) ~= "string" then
    return nil
  end
  return evaluated.str
end

function M.refresh_label_positions()
  state.label_positions = {}
  state.visible_labels = {}
  state.label_visibility_known = false

  local rendered = evaluated_statusline()
  if not rendered then
    return
  end

  local search_from = 1
  local found_any_label = false
  for index, menu in ipairs(state.config.menus) do
    local label = M.top_bar_display_label(menu, index)
    local start_byte = rendered:find(label, search_from, true)
    if start_byte then
      state.label_positions[index] = math.max(vim.fn.strdisplaywidth(rendered:sub(1, start_byte - 1)) + 1, 1)
      state.visible_labels[index] = true
      search_from = start_byte + #label
      found_any_label = true
    end
  end

  state.label_visibility_known = found_any_label
end

function M.is_top_visible(index)
  M.refresh_label_positions()
  if not state.label_visibility_known then
    return true
  end
  return state.visible_labels and state.visible_labels[index] == true
end

function M.label_hit_at_col(col)
  local mouse = vim.fn.getmousepos()
  local statusline_row = vim.o.lines - vim.o.cmdheight - 1
  if (mouse.screenrow or 0) ~= (statusline_row + 1) then
    return nil
  end

  M.refresh_label_positions()

  for index, menu in ipairs(state.config.menus) do
    local start_col = state.label_positions[index]
    if start_col then
      local label_width = vim.fn.strdisplaywidth(M.top_bar_display_label(menu, index))
      local end_col = start_col + label_width - 1
      if col >= start_col and col <= end_col then
        return index
      end
    end
  end
  return nil
end

function M.resolve_anchor(index, items)
  M.refresh_label_positions()
  local start_col = state.label_positions[index]
  local menu = state.config.menus[index]
  local label_width = vim.fn.strdisplaywidth(M.top_bar_display_label(menu, index))
  local popup_width = M.submenu_width(items)
  local col

  if start_col then
    local right_aligned_col = start_col + label_width - popup_width
    col = math.max(math.min(right_aligned_col - 3, vim.o.columns - popup_width + 1), 1)
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
