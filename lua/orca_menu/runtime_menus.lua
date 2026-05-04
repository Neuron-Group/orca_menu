local state = require("orca_menu.state")
local config = require("orca_menu.config")

local M = {}

local function validate_menu_id(id, method_name)
  if type(id) ~= "string" or id == "" then
    error(string.format("orca_menu.%s: id must be a non-empty string", method_name))
  end
end

local function validate_menu_spec(menu, method_name)
  if type(menu) ~= "table" then
    error(string.format("orca_menu.%s: menu must be a table", method_name))
  end
end

function M.reset()
  state.dynamic_menus = {}
  state.dynamic_menu_order = {}
end

function M.specs()
  local menus = {}

  for _, id in ipairs(state.dynamic_menu_order or {}) do
    local menu = state.dynamic_menus[id]
    if menu ~= nil then
      table.insert(menus, vim.deepcopy(menu))
    end
  end

  return menus
end

function M.append_to(base_menus)
  local menus = M.specs()
  if #menus == 0 then
    return vim.deepcopy(base_menus or {})
  end

  return config.append_menus(base_menus, menus)
end

function M.register(id, menu)
  validate_menu_id(id, "register_menu")
  validate_menu_spec(menu, "register_menu")

  local is_new = state.dynamic_menus[id] == nil
  state.dynamic_menus[id] = vim.deepcopy(menu)

  if is_new then
    table.insert(state.dynamic_menu_order, id)
  end
end

function M.update(id, menu)
  validate_menu_id(id, "update_menu")
  validate_menu_spec(menu, "update_menu")
  M.register(id, menu)
end

function M.unregister(id)
  validate_menu_id(id, "unregister_menu")

  if state.dynamic_menus[id] == nil then
    return false
  end

  state.dynamic_menus[id] = nil

  for index, existing_id in ipairs(state.dynamic_menu_order) do
    if existing_id == id then
      table.remove(state.dynamic_menu_order, index)
      break
    end
  end

  return true
end

return M
