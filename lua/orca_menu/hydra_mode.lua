local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local M = {
  hydra = nil,
}

local function collect_dynamic_keys()
  local seen = {}
  local keys = {}

  local function add(key)
    if key and key ~= "" and not seen[key] then
      seen[key] = true
      table.insert(keys, key)
    end
  end

  local function walk(items)
    for _, item in ipairs(items or {}) do
      add(item.key)
      if item.items then
        walk(item.items)
      end
    end
  end

  for _, menu in ipairs(state.config.menus or {}) do
    add(menu.key)
    walk(menu.items)
  end

  return keys
end

function M.setup()
  if M.hydra then
    return M.hydra
  end

  local ok, Hydra = pcall(require, "hydra")
  if not ok then
    return nil
  end

  local heads = {
    { "<Left>", function() popup.move_top(-1) end, { desc = "prev menu" } },
    { "<Right>", function() popup.move_top(1) end, { desc = "next menu" } },
    { "h", function() popup.move_top(-1) end, { desc = "prev menu" } },
    { "l", function() popup.move_top(1) end, { desc = "next menu" } },
    { "<Down>", function() popup.select_row(1) end, { desc = "down" } },
    { "<Up>", function() popup.select_row(-1) end, { desc = "up" } },
    { "j", function() popup.select_row(1) end, { desc = "down" } },
    { "k", function() popup.select_row(-1) end, { desc = "up" } },
    { "<CR>", popup.activate_selected, { desc = "select" } },
    { "<BS>", popup.go_back, { desc = "back" } },
    { "<Esc>", popup.close_all, { exit = true, desc = "close" } },
    { "q", popup.close_all, { exit = true, desc = "close" } },
  }

  for _, key in ipairs(collect_dynamic_keys()) do
    table.insert(heads, {
      key,
      function()
        if popup.is_open() then
          if not popup.activate_item_key(key) then
            popup.activate_top_key(key)
          end
        else
          if not popup.activate_top_key(key) then
            popup.activate_item_key(key)
          end
        end
      end,
      { desc = key },
    })
  end

  M.hydra = Hydra({
    name = "Orca Menu",
    mode = "n",
    body = state.config.keys.open,
    heads = heads,
    config = {
      color = "pink",
      invoke_on_body = true,
      hint = false,
      on_enter = function()
        popup.enter_menu_mode(state.active_top)
      end,
      on_exit = function()
        popup.close_all()
      end,
    },
  })

  return M.hydra
end

return M
