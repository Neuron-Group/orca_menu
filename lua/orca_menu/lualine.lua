local state = require("orca_menu.state")
local layout = require("orca_menu.layout")

local M = {}
local marker_prefix = "zzzom_label_"

local function trim_right_cell(text)
  if type(text) ~= "string" or text == "" then
    return ""
  end

  local target_width = vim.fn.strdisplaywidth(text) - 1
  if target_width <= 0 then
    return ""
  end

  local out = {}
  local width = 0
  for _, char in ipairs(vim.fn.split(text, [[\zs]])) do
    local char_width = vim.fn.strdisplaywidth(char)
    if width + char_width > target_width then
      break
    end
    table.insert(out, char)
    width = width + char_width
  end

  return table.concat(out)
end

function M.statusline_marker_text(index, is_end)
  return string.format("%s%d_%s__", marker_prefix, index, is_end and "E" or "S")
end

function M.statusline_marker(index, is_end)
  if not state.collecting_label_positions then
    return ""
  end

  return M.statusline_marker_text(index, is_end == 1)
end

_G.orca_menu_statusline_marker = function(index, is_end)
  return require("orca_menu.lualine").statusline_marker(index, is_end)
end

local function make_component(fn)
  return {
    fn,
    padding = { left = 0, right = 0 },
    orca_menu_component = true,
  }
end

function M.component_at(index)
  if not state.config then
    return ""
  end
  local menu = state.config.menus[index]
  if not menu then
    return ""
  end
  local label = layout.top_bar_display_label(menu, index)
  local spacing = state.config.lualine.spacing or " "
  local right_spacing = spacing
  local end_marker = string.format("%%{v:lua.orca_menu_statusline_marker(%d,1)}", index)
  if not layout.top_menu_enabled(menu) then
    label = string.format("%%#%s#%s%%*", state.config.highlights.disabled, label)
    right_spacing = trim_right_cell(spacing)
  end
  if state.config.enable_mouse == false then
    return string.format("%s%s%s", spacing, label, end_marker .. right_spacing)
  end
  return string.format("%s%%@v:lua.orca_menu_click_menu_%d@%s%%X%s%s", spacing, index, label, end_marker, right_spacing)
end

function M.anchor_component()
  return ""
end

function M.register()
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end
  local config = lualine.get_config()
  config.sections = config.sections or {}
  local section_name = "lualine_" .. (state.config.lualine.section or "y")
  local section = config.sections[section_name] or {}
  local preserved = {}

  for _, component in ipairs(section) do
    if type(component) ~= "table" or component.orca_menu_component ~= true then
      table.insert(preserved, component)
    end
  end

  config.sections[section_name] = preserved

  table.insert(config.sections[section_name], make_component(function()
    return require("orca_menu.lualine").anchor_component()
  end))

  for index, _ in ipairs(state.config.menus) do
    table.insert(config.sections[section_name], make_component(function()
      return require("orca_menu").lualine_component_at(index)
    end))
  end

  lualine.setup(config)
end

return M
