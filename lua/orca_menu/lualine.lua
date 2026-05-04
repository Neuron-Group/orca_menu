local state = require("orca_menu.state")
local layout = require("orca_menu.layout")

local M = {}

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
  if not layout.top_menu_enabled(menu) then
    label = string.format("%%#%s#%s%%*", state.config.highlights.disabled, label)
  end
  if state.config.enable_mouse == false then
    return string.format("%s%s%s", spacing, label, spacing)
  end
  return string.format("%s%%@v:lua.orca_menu_click_menu_%d@%s%%X%s", spacing, index, label, spacing)
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
