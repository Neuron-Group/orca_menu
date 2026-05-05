local state = require("orca_menu.state")
local layout = require("orca_menu.layout")

local M = {}

local function to_hex(color)
  if type(color) ~= "number" then
    return color
  end

  return string.format("#%06x", color)
end

function M.topbar_disabled_color()
  local source = state.config.highlights.topbar_disabled or state.config.highlights.disabled
  local source_hl = vim.api.nvim_get_hl(0, { name = source, link = false })
  if source_hl and source_hl.fg ~= nil then
    local gui = {}
    if source_hl.bold then
      table.insert(gui, "bold")
    end
    if source_hl.italic then
      table.insert(gui, "italic")
    end
    return { fg = to_hex(source_hl.fg), gui = #gui > 0 and table.concat(gui, ",") or nil }
  end

  return nil
end

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

local function component_parts(menu, index)
  local label = layout.top_bar_display_label(menu, index)
  local spacing = state.config.lualine.spacing or " "
  local right_spacing = spacing
  if not layout.top_menu_enabled(menu) then
    right_spacing = trim_right_cell(spacing)
  end
  return label, spacing, right_spacing
end

function M.visible_component_at(index)
  if not state.config then
    return ""
  end
  local menu = state.config.menus[index]
  if not menu then
    return ""
  end

  local label, spacing, right_spacing = component_parts(menu, index)
  return string.format("%s%s%s", spacing, label, right_spacing)
end

local function make_component(fn, color_fn)
  return {
    fn,
    color = color_fn,
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
  local label, spacing, right_spacing = component_parts(menu, index)
  if state.config.enable_mouse == false then
    return string.format("%s%s%s", spacing, label, right_spacing)
  end
  return string.format("%s%%@v:lua.orca_menu_click_menu_%d@%s%%X%s", spacing, index, label, right_spacing)
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
    end, function()
      local menu = state.config and state.config.menus[index]
      if menu and not layout.top_menu_enabled(menu) then
        return require("orca_menu.lualine").topbar_disabled_color()
      end
      return nil
    end))
  end

  lualine.setup(config)
end

return M
