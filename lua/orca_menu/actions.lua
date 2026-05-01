local state = require("orca_menu.state")

local M = {}

function M.execute_item(item)
  if type(item.action) == "function" then
    item.action()
    return
  end
  if type(item.lua) == "function" then
    item.lua()
    return
  end
  if type(item.lua) == "string" then
    local chunk, err = loadstring(item.lua)
    if not chunk then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    chunk()
    return
  end
  if item.command then
    vim.cmd(item.command)
    return
  end
  if item.keys then
    vim.api.nvim_feedkeys(vim.keycode(item.keys), "n", false)
  end
end

function M.run(item)
  require("orca_menu.popup").close_all()
  local hydra_mode = require("orca_menu.hydra_mode")
  if state.config and state.config.keys.mode_backend == "hydra" and hydra_mode.is_active() then
    state.pending_action = item
    hydra_mode.exit()
    return
  end
  vim.schedule(function()
    M.execute_item(item)
  end)
end

function M.current_items()
  local menu = state.config.menus[state.active_top]
  return menu.items or {}
end

return M
