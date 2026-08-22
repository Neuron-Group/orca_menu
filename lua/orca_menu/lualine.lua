local state = require("orca_menu.state")
local layout = require("orca_menu.layout")

local M = {}
local last_register_signature = nil

local function active_top_is_open(index, menu)
  local popup = require("orca_menu.popup")
  return popup.is_open() and state.active_top == index and layout.top_menu_enabled(menu)
end

local function to_hex(color)
  if type(color) ~= "number" then
    return color
  end

  return string.format("#%06x", color)
end

local function topbar_text_color(source, preserve_bg)
  local source_hl = vim.api.nvim_get_hl(0, { name = source, link = false })
  if source_hl and (source_hl.fg ~= nil or (not preserve_bg and source_hl.bg ~= nil)) then
    local gui = {}
    if source_hl.bold then
      table.insert(gui, "bold")
    end
    if source_hl.italic then
      table.insert(gui, "italic")
    end
    if source_hl.underline then
      table.insert(gui, "underline")
    end
    if source_hl.undercurl then
      table.insert(gui, "undercurl")
    end
    if source_hl.strikethrough then
      table.insert(gui, "strikethrough")
    end
    local bg = nil
    if not preserve_bg then
      bg = to_hex(source_hl.bg)
    end
    return {
      fg = to_hex(source_hl.fg),
      bg = bg,
      gui = #gui > 0 and table.concat(gui, ",") or nil,
    }
  end

  return nil
end

function M.topbar_disabled_color()
  local source = state.config.highlights.topbar_disabled or state.config.highlights.disabled
  return topbar_text_color(source, true)
end

function M.topbar_active_color()
  local source = state.config.highlights.topbar_active or state.config.highlights.menu_sel
  return topbar_text_color(source, state.config.highlights.topbar_active_preserve_bg ~= false)
end

function M.refresh()
  local ok, lualine = pcall(require, "lualine")
  if ok and type(lualine.refresh) == "function" then
    pcall(lualine.refresh, { place = { "statusline" } })
    return
  end

  pcall(vim.cmd, "redrawstatus")
end

local function component_parts(menu, index)
  local label = layout.top_bar_display_label(menu, index)
  local spacing = state.config.lualine.spacing or " "
  return label, spacing, spacing
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

local function make_component(fn, color_fn, component_id)
  return {
    fn,
    color = color_fn,
    padding = { left = 0, right = 0 },
    orca_menu_component = true,
    component_id = component_id,
  }
end

local function register_signature()
  return vim.json.encode({
    section = state.config and state.config.lualine and state.config.lualine.section or "y",
    enable_mouse = state.config and state.config.enable_mouse ~= false or false,
    menu_count = state.config and state.config.menus and #state.config.menus or 0,
  })
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
  return string.format(
    "%%@v:lua.orca_menu_click_menu_%d@%s%s%s%%X",
    index,
    spacing,
    label,
    right_spacing
  )
end

function M.anchor_component()
  return ""
end

function M.register()
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end
  if type(lualine.get_component_positions) ~= "function" then
    error("orca_menu requires lualine.nvim with get_component_positions support")
  end

  local signature = register_signature()
  if signature == last_register_signature then
    return
  end

  local config = lualine.get_config()
  config.sections = config.sections or {}
  for section_name, section in pairs(config.sections) do
    local preserved = {}
    for _, component in ipairs(section or {}) do
      if type(component) ~= "table" or component.orca_menu_component ~= true then
        table.insert(preserved, component)
      end
    end
    config.sections[section_name] = preserved
  end
  config.inactive_sections = config.inactive_sections or {}
  for section_name, section in pairs(config.inactive_sections) do
    local preserved = {}
    for _, component in ipairs(section or {}) do
      if type(component) ~= "table" or component.orca_menu_component ~= true then
        table.insert(preserved, component)
      end
    end
    config.inactive_sections[section_name] = preserved
  end

  local section_name = "lualine_" .. (state.config.lualine.section or "y")
  local function append_components(section_group)
    section_group[section_name] = section_group[section_name] or {}

    table.insert(section_group[section_name], make_component(function()
      return require("orca_menu.lualine").anchor_component()
    end))

    for index, _ in ipairs(state.config.menus) do
      table.insert(section_group[section_name], make_component(function()
        return require("orca_menu").lualine_component_at(index)
      end, function()
        local menu = state.config and state.config.menus[index]
        if active_top_is_open(index, menu) then
          return require("orca_menu.lualine").topbar_active_color()
        end
        if menu and not layout.top_menu_enabled(menu) then
          return require("orca_menu.lualine").topbar_disabled_color()
        end
        return nil
      end, "orca_menu:" .. index))
    end
  end

  append_components(config.sections)
  append_components(config.inactive_sections)

  lualine.setup(config)
  last_register_signature = signature
end

return M
