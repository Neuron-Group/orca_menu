local state = require("orca_menu.state")

local M = {}

local function line_text(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  return line or ""
end

local function line_length(bufnr, row)
  return #line_text(bufnr, row)
end

local function clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function ordered_visual_positions(anchor, cursor)
  local a_row = math.max((anchor[2] or 1) - 1, 0)
  local a_col = math.max((anchor[3] or 1) - 1, 0)
  local c_row = math.max((cursor[2] or 1) - 1, 0)
  local c_col = math.max((cursor[3] or 1) - 1, 0)

  if a_row < c_row or (a_row == c_row and a_col <= c_col) then
    return a_row, a_col, c_row, c_col
  end

  return c_row, c_col, a_row, a_col
end

local function valid_position(pos)
  return type(pos) == "table" and (pos[2] or 0) > 0
end

local function position_span(anchor, pos)
  if not valid_position(anchor) or not valid_position(pos) then
    return -1
  end

  local row_delta = math.abs((pos[2] or 1) - (anchor[2] or 1))
  local col_delta = math.abs((pos[3] or 1) - (anchor[3] or 1))
  return (row_delta * 1000000) + col_delta
end

local function furthest_position(anchor, candidates)
  local selected = nil
  local best_span = -1

  for _, candidate in ipairs(candidates or {}) do
    local span = position_span(anchor, candidate)
    if span > best_span then
      selected = candidate
      best_span = span
    end
  end

  return selected
end

local function charwise_regions(bufnr, start_row, start_col, end_row, end_col)
  local regions = {}
  if start_row == end_row then
    table.insert(regions, {
      row = start_row,
      start_col = clamp(start_col, 0, line_length(bufnr, start_row)),
      end_col = clamp(end_col + 1, 0, line_length(bufnr, start_row)),
    })
    return regions
  end

  for row = start_row, end_row do
    local row_length = line_length(bufnr, row)
    local region_start = 0
    local region_end = row_length

    if row == start_row then
      region_start = clamp(start_col, 0, row_length)
    end

    if row == end_row then
      region_end = clamp(end_col + 1, 0, row_length)
    end

    table.insert(regions, {
      row = row,
      start_col = region_start,
      end_col = region_end,
    })
  end

  return regions
end

local function linewise_regions(bufnr, start_row, end_row)
  local regions = {}
  for row = start_row, end_row do
    table.insert(regions, {
      row = row,
      start_col = 0,
      end_col = line_length(bufnr, row),
      hl_eol = true,
    })
  end
  return regions
end

local function blockwise_regions(bufnr, start_row, start_col, end_row, end_col)
  local regions = {}
  local left = math.min(start_col, end_col)
  local right = math.max(start_col, end_col) + 1

  for row = start_row, end_row do
    local row_length = line_length(bufnr, row)
    table.insert(regions, {
      row = row,
      start_col = clamp(left, 0, row_length),
      end_col = clamp(right, 0, row_length),
    })
  end

  return regions
end

local function selection_lines(bufnr, regions)
  local lines = {}
  for _, region in ipairs(regions) do
    local chunks = vim.api.nvim_buf_get_text(bufnr, region.row, region.start_col, region.row, region.end_col, {})
    table.insert(lines, chunks[1] or "")
  end
  return lines
end

function M.capture(opts)
  local options = opts or {}
  local mode = vim.fn.mode()
  local context = {
    source_mode = mode,
    bufnr = vim.api.nvim_get_current_buf(),
    winid = vim.api.nvim_get_current_win(),
  }

  local selection_mode = mode
  local anchor
  local cursor

  if mode == "v" or mode == "V" or mode == "\22" then
    anchor = vim.fn.getpos("v")
    cursor = vim.fn.getpos(".")
  elseif options.preserve_visual then
    local start_mark = vim.fn.getpos("'<")
    local last_visual_mode = vim.fn.visualmode()
    selection_mode = last_visual_mode == "" and "v" or last_visual_mode
    local end_mark = furthest_position(start_mark, {
      vim.fn.getpos("'>"),
      vim.fn.getpos("."),
      vim.fn.getpos("v"),
    })
    if valid_position(start_mark) and valid_position(end_mark) then
      context.source_mode = selection_mode
      anchor = start_mark
      cursor = end_mark
    end
  end

  if not anchor or not cursor then
    return context
  end
  local start_row, start_col, end_row, end_col = ordered_visual_positions(anchor, cursor)
  local regions

  if selection_mode == "V" then
    regions = linewise_regions(context.bufnr, start_row, end_row)
  elseif selection_mode == "\22" then
    regions = blockwise_regions(context.bufnr, start_row, start_col, end_row, end_col)
  else
    regions = charwise_regions(context.bufnr, start_row, start_col, end_row, end_col)
  end

  context.selection = {
    mode = selection_mode,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    regions = regions,
    lines = selection_lines(context.bufnr, regions),
  }

  return context
end

function M.clear()
  local context = state.menu_context
  if context and context.selection and context.bufnr and vim.api.nvim_buf_is_valid(context.bufnr) then
    vim.api.nvim_buf_clear_namespace(context.bufnr, state.selection_namespace, 0, -1)
    pcall(vim.fn.setpos, "'<", { 0, 0, 0, 0 })
    pcall(vim.fn.setpos, "'>", { 0, 0, 0, 0 })
  end
  state.menu_context = nil
end

function M.activate(context)
  local existing_context = state.menu_context
  if context and not context.selection and state.menu_mode and existing_context and existing_context.selection then
    return
  end

  M.clear()

  if not context or not context.selection then
    state.menu_context = context
    return
  end

  state.menu_context = context

  if not vim.api.nvim_buf_is_valid(context.bufnr) then
    return
  end

  for _, region in ipairs(context.selection.regions or {}) do
    vim.api.nvim_buf_set_extmark(context.bufnr, state.selection_namespace, region.row, region.start_col, {
      end_row = region.row,
      end_col = region.end_col,
      hl_group = "Visual",
      hl_eol = region.hl_eol or false,
      priority = 200,
      strict = false,
    })
  end
end

function M.reselect(context)
  if not context or not context.selection then
    return false
  end

  if not context.winid or not vim.api.nvim_win_is_valid(context.winid) then
    return false
  end

  if not context.bufnr or not vim.api.nvim_buf_is_valid(context.bufnr) then
    return false
  end

  if vim.api.nvim_win_get_buf(context.winid) ~= context.bufnr then
    return false
  end

  local selection = context.selection
  vim.api.nvim_set_current_win(context.winid)
  vim.fn.setpos("'<", { 0, selection.start_row + 1, selection.start_col + 1, 0 })
  vim.fn.setpos("'>", { 0, selection.end_row + 1, selection.end_col + 1, 0 })
  vim.api.nvim_win_set_cursor(context.winid, { selection.end_row + 1, selection.end_col })
  vim.cmd.normal({ args = { "gv" }, bang = true })
  return true
end

return M
