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

local function sorted_client_names()
  local names = active_lsp_names()
  table.sort(names)
  return names
end

local function refresh_signature()
  return vim.json.encode({
    lsp_clients = sorted_client_names(),
  })
end

local function lualine_structure_signature(resolved_config)
  return vim.json.encode({
    section = resolved_config and resolved_config.lualine and resolved_config.lualine.section or "y",
    enable_mouse = resolved_config and resolved_config.enable_mouse ~= false or false,
    menu_count = resolved_config and resolved_config.menus and #resolved_config.menus or 0,
  })
end

local function build_config()
  local resolved = config.resolve(state.base_config or {}, active_lsp_names())
  resolved.menus = runtime_menus.append_to(resolved.menus)
  return resolved
end

local function base_menu_count()
  local resolved = config.resolve(state.base_config or {}, active_lsp_names())
  return #(resolved.menus or {})
end

local function runtime_menu_index(id)
  local base_count = base_menu_count()
  for offset, existing_id in ipairs(state.dynamic_menu_order or {}) do
    if existing_id == id then
      return base_count + offset
    end
  end
  return nil
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
  local previous_structure_signature = state.config and lualine_structure_signature(state.config) or nil

  state.config = build_config()
  local next_structure_signature = lualine_structure_signature(state.config)

  state.active_top = bounded_top_index(state.active_top)
  rebuild_click_handlers()
  apply_open_key_binding()
  input.install_mouse()

  if previous_structure_signature ~= next_structure_signature then
    lualine.register()
  else
    lualine.refresh()
  end
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
  local desired_open_key = state.config.keys.open
  local current_open_key = state.current_open_key

  if current_open_key == desired_open_key then
    return
  end

  if current_open_key and current_open_key ~= "" then
    pcall(vim.keymap.del, "n", current_open_key)
    pcall(vim.keymap.del, "x", current_open_key)
    pcall(vim.keymap.del, "i", current_open_key)
  end

  state.current_open_key = desired_open_key

  if not desired_open_key or desired_open_key == "" then
    hydra_mode.reset()
    return
  end

  hydra_mode.reset()
  hydra_mode.setup()

  vim.keymap.set("n", desired_open_key, function()
    mode.run_after_editor_mode(function()
      hydra_mode.activate()
    end, { preserve_visual = true })
  end, { desc = "Enter Orca menu", silent = true })

  vim.keymap.set("x", desired_open_key, function()
    mode.run_after_editor_mode(function()
      hydra_mode.activate()
    end, { preserve_visual = true })
  end, { desc = "Enter Orca menu", silent = true })

  vim.keymap.set("i", desired_open_key, function()
    mode.run_after_editor_mode(function()
      hydra_mode.activate()
    end)
  end, { desc = "Enter Orca menu", silent = true })
end

function refresh_config(opts)
  opts = opts or {}
  local signature = refresh_signature()
  if not opts.force and state.last_refresh_signature == signature then
    return false
  end

  local snapshot = capture_ui_state()
  apply_resolved_config()
  state.last_refresh_signature = signature
  restore_ui_state(snapshot)
  return true
end

function M.open_menu(index, _use_mouse)
  local target = index or state.active_top
  if _use_mouse then
    mode.run_after_editor_mode(function()
      popup.open_top(target)
    end, { preserve_visual = true })
    return
  end
  popup.open_top(target)
end

function M.click(index)
  local target = index or state.active_top
  mode.run_after_editor_mode(function()
    local mouse = vim.fn.getmousepos()
    local hit = require("orca_menu.layout").label_hit_at_col(math.max((mouse.screencol or 1), 1))
    if hit ~= target then
      return
    end

    if not require("orca_menu.layout").top_menu_enabled(state.config.menus[target]) then
      return
    end

    if popup.is_open() and state.active_top == target then
      popup.close_all()
    else
      popup.open_top(target)
    end
  end, { preserve_visual = true })
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
  refresh_config({ source = "api.refresh", force = true })
end

function M.register_menu(id, menu)
  runtime_menus.register(id, menu)
  refresh_config({ source = "api.register_menu", force = true })
end

function M.update_menu(id, menu)
  runtime_menus.update(id, menu)
  refresh_config({ source = "api.update_menu", force = true })
end

function M.unregister_menu(id)
  local removed_index = runtime_menu_index(id)
  local removed_menu_was_active = removed_index ~= nil
    and state.active_top == removed_index
    and (popup.is_open() or state.menu_mode)

  if removed_menu_was_active then
    popup.close_all()
  end

  local removed = runtime_menus.unregister(id)
  if not removed then
    return false
  end

  refresh_config({ source = "api.unregister_menu", force = true })
  return true
end

function M.setup(user_config)
  state.base_config = vim.deepcopy(user_config or {})
  runtime_menus.reset()
  state.mouse_trace_path = vim.env.ORCA_MENU_MOUSE_TRACE
  apply_resolved_config()
  state.last_refresh_signature = refresh_signature()
  bootstrap.install_user_commands(M)
  bootstrap.install_autocmds(augroup, refresh_config)
end

return M
