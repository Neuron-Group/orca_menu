local M = {}

local state = require("orca_menu.state")
local config = require("orca_menu.config")
local popup = require("orca_menu.popup")
local input = require("orca_menu.input")
local lualine = require("orca_menu.lualine")
local hydra_mode = require("orca_menu.hydra_mode")

local augroup = vim.api.nvim_create_augroup("OrcaMenu", { clear = true })

local function active_lsp_names()
  local names = {}
  for _, client_id in ipairs(state.lsp_client_ids or {}) do
    local client = vim.lsp.get_client_by_id(client_id)
    if client and client.name then
      table.insert(names, client.name)
    end
  end
  return names
end

local function rebuild_click_handlers()
  for key, _ in pairs(_G) do
    if type(key) == "string" and key:match("^orca_menu_click_menu_%d+$") then
      _G[key] = nil
    end
  end

  for index, _ in ipairs(state.config.menus or {}) do
    _G["orca_menu_click_menu_" .. index] = function()
      require("orca_menu").open_menu(index, true)
    end
  end
end

local function apply_open_key_binding()
  if state.current_open_key and state.current_open_key ~= "" then
    pcall(vim.keymap.del, "n", state.current_open_key)
  end

  state.current_open_key = state.config.keys.open
  state.current_open_backend = state.config.keys.mode_backend

  if not state.current_open_key or state.current_open_key == "" then
    return
  end

  if state.current_open_backend == "hydra" then
    hydra_mode.reset()
    hydra_mode.setup()
  else
    vim.keymap.set("n", state.current_open_key, function()
      require("orca_menu").toggle()
    end, { desc = "Toggle Orca menu", silent = true })
  end
end

local function refresh_config()
  popup.close_all()
  state.config = config.resolve(state.base_config or {}, active_lsp_names())
  state.active_top = math.min(math.max(state.active_top or 1, 1), math.max(#(state.config.menus or {}), 1))
  rebuild_click_handlers()
  apply_open_key_binding()
  input.install_mouse()
  lualine.register()
end

local function track_lsp_client(client_id)
  local seen = {}
  local ordered_ids = {}
  for _, existing_id in ipairs(state.lsp_client_ids or {}) do
    local client = vim.lsp.get_client_by_id(existing_id)
    if client and not seen[existing_id] then
      seen[existing_id] = true
      table.insert(ordered_ids, existing_id)
    end
  end
  if client_id and vim.lsp.get_client_by_id(client_id) and not seen[client_id] then
    table.insert(ordered_ids, client_id)
  end
  state.lsp_client_ids = ordered_ids
end

local function untrack_lsp_client(client_id)
  local kept_ids = {}
  for _, existing_id in ipairs(state.lsp_client_ids or {}) do
    if existing_id ~= client_id and vim.lsp.get_client_by_id(existing_id) then
      table.insert(kept_ids, existing_id)
    end
  end
  state.lsp_client_ids = kept_ids
end

function M.open_menu(index, _use_mouse)
  popup.open_top(index or state.active_top)
end

function M.click(index)
  M.open_menu(index, true)
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

function M.setup(user_config)
  state.base_config = vim.deepcopy(user_config or {})
  state.lsp_client_ids = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    table.insert(state.lsp_client_ids, client.id)
  end
  state.config = config.resolve(state.base_config, active_lsp_names())
  rebuild_click_handlers()

  vim.api.nvim_create_user_command("OrcaMenu", function(opts)
    if opts.args ~= "" then
      M.open_menu(tonumber(opts.args) or 1, false)
    else
      M.toggle()
    end
  end, { nargs = "?" })

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = augroup,
    callback = function()
      if state.menu_mode or popup.is_open() or #state.menu_stack > 0 then
        popup.close_all()
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function(args)
      track_lsp_client(args.data and args.data.client_id or nil)
      refresh_config()
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroup,
    callback = function(args)
      untrack_lsp_client(args.data and args.data.client_id or nil)
      refresh_config()
    end,
  })

  apply_open_key_binding()
  input.install_mouse()
  M.register_lualine()
end

return M
