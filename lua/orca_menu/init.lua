local M = {}

local state = require("orca_menu.state")
local config = require("orca_menu.config")
local popup = require("orca_menu.popup")
local input = require("orca_menu.input")
local lualine = require("orca_menu.lualine")
local hydra_mode = require("orca_menu.hydra_mode")
local mode = require("orca_menu.mode")
local runtime_menus = require("orca_menu.runtime_menus")
local bootstrap = require("orca_menu.bootstrap")

local augroup = vim.api.nvim_create_augroup("OrcaMenu", { clear = true })
local rebuild_click_handlers
local apply_open_key_binding
local refresh_config

local function active_lsp_names()
  local current_buf = vim.api.nvim_get_current_buf()
  local names = {}
  local clients = vim.lsp.get_clients({ bufnr = current_buf })
  for _, client in ipairs(clients) do
    if client and client.name then
      table.insert(names, client.name)
    end
  end
  return names
end

local function build_config()
  local resolved = config.resolve(state.base_config or {}, active_lsp_names())
  resolved.menus = runtime_menus.append_to(resolved.menus)
  return resolved
end

local function bounded_top_index(index)
  return math.min(math.max(index or 1, 1), math.max(#(state.config.menus or {}), 1))
end

local function capture_ui_state()
  return {
    was_open = popup.is_open(),
    was_menu_mode = state.menu_mode,
    active_top = state.active_top,
  }
end

local function apply_resolved_config()
  state.config = build_config()
  state.active_top = bounded_top_index(state.active_top)
  rebuild_click_handlers()
  apply_open_key_binding()
  input.install_mouse()
  lualine.register()
end

local function restore_ui_state(snapshot)
  local active_top = bounded_top_index(snapshot.active_top)

  if snapshot.was_open then
    popup.open_top(active_top)
  elseif snapshot.was_menu_mode then
    popup.enter_menu_mode(active_top)
  end
end

function rebuild_click_handlers()
  for key, _ in pairs(_G) do
    if type(key) == "string" and key:match("^orca_menu_click_menu_%d+$") then
      _G[key] = nil
    end
  end

  for index, _ in ipairs(state.config.menus or {}) do
    _G["orca_menu_click_menu_" .. index] = function()
      require("orca_menu").click(index)
    end
  end
end

function apply_open_key_binding()
  if state.current_open_key and state.current_open_key ~= "" then
    pcall(vim.keymap.del, "n", state.current_open_key)
    pcall(vim.keymap.del, "x", state.current_open_key)
    pcall(vim.keymap.del, "i", state.current_open_key)
  end

  state.current_open_key = state.config.keys.open

  if not state.current_open_key or state.current_open_key == "" then
    return
  end

  hydra_mode.reset()
  hydra_mode.setup()

  vim.keymap.set({ "n", "x", "i" }, state.current_open_key, function()
    mode.run_after_editor_mode(function()
      hydra_mode.activate()
    end)
  end, { desc = "Enter Orca menu", silent = true })
end

function refresh_config()
  local snapshot = capture_ui_state()
  apply_resolved_config()
  restore_ui_state(snapshot)
end

function M.open_menu(index, _use_mouse)
  local target = index or state.active_top
  if _use_mouse then
    mode.run_after_editor_mode(function()
      popup.open_top(target)
    end)
    return
  end
  popup.open_top(target)
end

function M.click(index)
  local target = index or state.active_top
  mode.run_after_editor_mode(function()
    if not require("orca_menu.layout").top_menu_enabled(state.config.menus[target]) then
      return
    end

    if popup.is_open() and state.active_top == target then
      popup.close_all()
    else
      popup.open_top(target)
    end
  end)
end

function M.toggle()
  if state.menu_mode then
    popup.close_all()
  else
    popup.enter_menu_mode(state.active_top)
  end
end

function M.lualine_component_at(index)
  return lualine.component_at(index)
end

function M.components()
  local parts = {}
  for index, _ in ipairs(state.config.menus or {}) do
    table.insert(parts, index)
  end
  return parts
end

function M.register_lualine()
  lualine.register()
end

function M.refresh()
  refresh_config()
end

function M.register_menu(id, menu)
  runtime_menus.register(id, menu)
  refresh_config()
end

function M.update_menu(id, menu)
  runtime_menus.update(id, menu)
  refresh_config()
end

function M.unregister_menu(id)
  local removed = runtime_menus.unregister(id)
  if not removed then
    return false
  end

  refresh_config()
  return true
end

function M.setup(user_config)
  state.base_config = vim.deepcopy(user_config or {})
  runtime_menus.reset()
  state.mouse_trace_path = vim.env.ORCA_MENU_MOUSE_TRACE
  apply_resolved_config()
  bootstrap.install_user_commands(M)
  bootstrap.install_autocmds(augroup, refresh_config)
end

return M
