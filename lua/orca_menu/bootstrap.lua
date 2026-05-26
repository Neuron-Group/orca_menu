local state = require("orca_menu.state")
local mode = require("orca_menu.mode")
local popup = require("orca_menu.popup")
local selection = require("orca_menu.selection")

local M = {}

function M.install_user_commands(api)
  vim.api.nvim_create_user_command("OrcaMenu", function(opts)
    if opts.args ~= "" then
      api.open_menu(tonumber(opts.args) or 1, false)
    else
      api.toggle()
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
end

function M.install_autocmds(augroup, refresh)
  local function menu_ui_active()
    return state.menu_mode or popup.is_open() or #state.menu_stack > 0
  end

  local function current_window_is_floating()
    local current_win = vim.api.nvim_get_current_win()
    local config = vim.api.nvim_win_get_config(current_win)
    return config and config.relative and config.relative ~= ""
  end

  local function should_close_menu_for_context_change()
    if not menu_ui_active() then
      return false
    end

    if current_window_is_floating() then
      return false
    end

    return state.menu_owner_win ~= nil and state.menu_owner_win ~= vim.api.nvim_get_current_win()
  end

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup,
    callback = function()
      if not mode.is_visual() then
        return
      end

      local context = selection.capture()
      if context and context.selection then
        state.last_visual_context = context
      end
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = augroup,
    pattern = { "*:v", "*:V", "*:\22", "v:*", "V:*", "\22:*" },
    callback = function()
      if mode.is_visual() then
        local context = selection.capture()
        if context and context.selection then
          state.last_visual_context = context
        end
        return
      end

      if state.last_visual_context and state.last_visual_context.selection then
        state.last_visual_exit_ns = vim.loop.hrtime()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      if menu_ui_active() then
        popup.close_all()
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = augroup,
    callback = function()
      refresh({ source = "LspAttach" })
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroup,
    callback = function()
      vim.schedule(function()
        refresh({ source = "LspDetach" })
      end)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      if should_close_menu_for_context_change() then
        popup.close_all()
      end
      refresh({ source = "BufEnter" })
    end,
  })

  vim.api.nvim_create_autocmd({ "WinEnter", "TermEnter" }, {
    group = augroup,
    callback = function()
      if should_close_menu_for_context_change() then
        popup.close_all()
      end
      refresh({ source = "WindowEnter", force = true })
    end,
  })
end

return M
