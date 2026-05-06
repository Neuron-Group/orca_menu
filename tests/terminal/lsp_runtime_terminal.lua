local outfile = vim.env.ORCA_TERMINAL_RESULT
local timeout_ms = tonumber(vim.env.ORCA_TERMINAL_TIMEOUT_MS or "2500")

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.g.mapleader = " "

local original_get_clients = vim.lsp.get_clients
local active_clients = {}

vim.lsp.get_clients = function(opts)
  if opts and opts.bufnr and opts.bufnr ~= vim.api.nvim_get_current_buf() then
    return {}
  end
  return vim.deepcopy(active_clients)
end

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F12>",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "&Open", key = "o", action = function() end },
      },
    },
  },
  lsp_overrides = {
    leanls = {
      menus = {
        {
          label = "&Lean",
          key = "l",
          items = {
            { label = "&Goals", key = "g", action = function() end },
          },
        },
      },
    },
  },
})

local orca = require("orca_menu")
local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

orca.register_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    { label = "&Build", key = "b", action = function() end },
  },
})

local phase = "attach"
local finished = false
local start = vim.loop.hrtime()

local function write_result(status, extra)
  if finished then
    return
  end

  finished = true
  local result = vim.tbl_extend("force", {
    status = status,
    phase = phase,
    menu_count = #(state.config.menus or {}),
    active_top = state.active_top,
    popup_open = popup.is_open() and true or false,
    first_label = state.config.menus[1] and state.config.menus[1].label or nil,
    second_label = state.config.menus[2] and state.config.menus[2].label or nil,
    first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
      and state.menu_stack[1].items[1].label or nil,
    first_label_col = state.label_positions[1],
    second_label_col = state.label_positions[2],
  }, extra or {})

  vim.fn.writefile({ vim.json.encode(result) }, outfile)
  vim.lsp.get_clients = original_get_clients
  vim.cmd("qa!")
end

local function fail(message)
  write_result("error", { message = message })
end

local timer = vim.loop.new_timer()
timer:start(80, 80, vim.schedule_wrap(function()
  if finished then
    return
  end

  layout.refresh_label_positions()

  if phase == "attach" then
    active_clients = {
      { name = "leanls" },
    }
    vim.api.nvim_exec_autocmds("LspAttach", { group = "OrcaMenu", buffer = 0, data = { client_id = 1 } })
    phase = "verify_attach"
    return
  end

  if phase == "verify_attach" then
    if #(state.config.menus or {}) ~= 2 then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out waiting for attached LSP menu refresh")
      end
      return
    end

    if not state.config.menus[1] or state.config.menus[1].label ~= "Lean" then
      timer:stop()
      timer:close()
      fail("expected Lean override menu after LspAttach")
      return
    end

    if not state.config.menus[2] or state.config.menus[2].label ~= "Tools" then
      timer:stop()
      timer:close()
      fail("expected runtime menu to survive LspAttach")
      return
    end

    if not state.label_positions[1] or not state.label_positions[2] then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out waiting for visible topbar labels after LspAttach")
      end
      return
    end

    popup.open_top(1)
    if not popup.is_open() or state.active_top ~= 1 then
      timer:stop()
      timer:close()
      fail("expected Lean top menu to open after LspAttach")
      return
    end

    local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
    if not first_item or first_item.label ~= "Goals" then
      timer:stop()
      timer:close()
      fail("expected Lean popup contents after LspAttach")
      return
    end

    popup.close_all()
    active_clients = {}
    vim.api.nvim_exec_autocmds("LspDetach", { group = "OrcaMenu", buffer = 0, data = { client_id = 1 } })
    phase = "verify_detach"
    return
  end

  if phase == "verify_detach" then
    if #(state.config.menus or {}) ~= 2 then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out waiting for detached LSP menu refresh")
      end
      return
    end

    if not state.config.menus[1] or state.config.menus[1].label ~= "File" then
      timer:stop()
      timer:close()
      fail("expected File base menu after LspDetach")
      return
    end

    if not state.config.menus[2] or state.config.menus[2].label ~= "Tools" then
      timer:stop()
      timer:close()
      fail("expected runtime menu to survive LspDetach")
      return
    end

    if not state.label_positions[1] or not state.label_positions[2] then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out waiting for visible topbar labels after LspDetach")
      end
      return
    end

    popup.open_top(2)
    if not popup.is_open() then
      timer:stop()
      timer:close()
      fail("expected runtime menu to remain openable after LspDetach")
      return
    end

    local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
    if not first_item or first_item.label ~= "Build" then
      timer:stop()
      timer:close()
      fail("expected runtime popup contents after LspDetach")
      return
    end

    timer:stop()
    timer:close()
    write_result("ok")
  end
end))
