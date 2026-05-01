local M = {}

local state = require("orca_menu.state")
local config = require("orca_menu.config")
local popup = require("orca_menu.popup")
local input = require("orca_menu.input")
local lualine = require("orca_menu.lualine")

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
  state.config = config.normalize(user_config)

  for index, _ in ipairs(state.config.menus) do
    _G["orca_menu_click_menu_" .. index] = function()
      require("orca_menu").open_menu(index, true)
    end
  end

  vim.api.nvim_create_user_command("OrcaMenu", function(opts)
    if opts.args ~= "" then
      M.open_menu(tonumber(opts.args) or 1, false)
    else
      M.toggle()
    end
  end, { nargs = "?" })

  if state.config.keys.open and state.config.keys.open ~= "" then
    vim.keymap.set("n", state.config.keys.open, function()
      require("orca_menu").toggle()
    end, { desc = "Toggle Orca menu", silent = true })
  end

  input.install_mouse()
  M.register_lualine()
end

return M
