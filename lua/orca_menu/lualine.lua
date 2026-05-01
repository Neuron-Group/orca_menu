local state = require("orca_menu.state")
local layout = require("orca_menu.layout")

local M = {}

function M.component_at(index)
  if not state.config then
    return ""
  end
  local menu = state.config.menus[index]
  if not menu then
    return ""
  end
  local label = menu.label ~= "" and menu.label or tostring(index)
  local key_hint = layout.display_key_hint(menu.key)
  if key_hint ~= "" then
    label = string.format("%s(%s)", label, key_hint)
  end
  local spacing = state.config.lualine.spacing or " "
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
  config.sections[section_name] = config.sections[section_name] or {}

  table.insert(config.sections[section_name], {
    function()
      return require("orca_menu.lualine").anchor_component()
    end,
    padding = { left = 0, right = 0 },
  })

  for index, _ in ipairs(state.config.menus) do
    table.insert(config.sections[section_name], {
      function()
        return require("orca_menu").lualine_component_at(index)
      end,
      padding = { left = 0, right = 0 },
    })
  end

  lualine.setup(config)
end

return M
