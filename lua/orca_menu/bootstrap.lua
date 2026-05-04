local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

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
  vim.api.nvim_create_autocmd("VimResized", {
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
      refresh()
    end,
  })

  vim.api.nvim_create_autocmd("LspDetach", {
    group = augroup,
    callback = function()
      vim.schedule(refresh)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      refresh()
    end,
  })
end

return M
