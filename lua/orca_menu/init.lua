local M = {}

local state = require("orca_menu.state")
local config = require("orca_menu.config")
local popup = require("orca_menu.popup")
local input = require("orca_menu.input")
local lualine = require("orca_menu.lualine")
local hydra_mode = require("orca_menu.hydra_mode")
local mode = require("orca_menu.mode")

local augroup = vim.api.nvim_create_augroup("OrcaMenu", { clear = true })

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

local function rebuild_click_handlers()
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

local function apply_open_key_binding()
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

local function refresh_config()
  local was_open = popup.is_open()
  local was_menu_mode = state.menu_mode
  local active_top = state.active_top

  state.config = config.resolve(state.base_config or {}, active_lsp_names())
  state.active_top = math.min(math.max(state.active_top or 1, 1), math.max(#(state.config.menus or {}), 1))
  rebuild_click_handlers()
  apply_open_key_binding()
  input.install_mouse()
  lualine.register()

  if was_open then
    popup.open_top(math.min(active_top or 1, math.max(#(state.config.menus or {}), 1)))
  elseif was_menu_mode then
    popup.enter_menu_mode(math.min(active_top or 1, math.max(#(state.config.menus or {}), 1)))
  end
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

function M.setup(user_config)
  state.base_config = vim.deepcopy(user_config or {})
  state.config = config.resolve(state.base_config, active_lsp_names())
  state.mouse_trace_path = vim.env.ORCA_MENU_MOUSE_TRACE
  rebuild_click_handlers()

  vim.api.nvim_create_user_command("OrcaMenu", function(opts)
    if opts.args ~= "" then
      M.open_menu(tonumber(opts.args) or 1, false)
    else
      M.toggle()
    end
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("OrcaMenuMouseTrace", function(opts)
    if opts.args == "off" then
      state.mouse_trace_path = nil
      vim.notify("OrcaMenu mouse tracing disabled")
      return
    end

    local path = opts.args ~= "" and opts.args or vim.env.ORCA_MENU_MOUSE_TRACE
    if not path or path == "" then
      vim.notify("Provide a log path or set ORCA_MENU_MOUSE_TRACE", vim.log.levels.ERROR)
      return
    end

    state.mouse_trace_path = path
    vim.fn.writefile({}, path)
    vim.notify("OrcaMenu mouse tracing -> " .. path)
  end, {
    nargs = "?",
    complete = function()
      return { "off" }
    end,
  })

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
    callback = function()
      refresh_config()
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroup,
    callback = function()
      vim.schedule(refresh_config)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = augroup,
    callback = function()
      refresh_config()
    end,
  })

  apply_open_key_binding()
  input.install_mouse()
  M.register_lualine()
end

return M
