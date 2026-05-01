local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local actions = require("orca_menu.actions")

local M = {
  hydra = nil,
}

local hydra_exit_pending = false

local function debug_log(lines)
  local logfile = "/tmp/orca_menu_hydra.log"
  local fd = io.open(logfile, "a")
  if not fd then
    return
  end
  fd:write(os.date("[%Y-%m-%d %H:%M:%S] "))
  fd:write(table.concat(lines, " | "))
  fd:write("\n")
  fd:close()
end

local function close_hydra_mode()
  debug_log({
    "hydra=close_hydra_mode",
    string.format("menu_mode=%s stack=%d open=%s", tostring(state.menu_mode), #state.menu_stack, tostring(popup.is_open())),
  })
  popup.close_all()
  if M.hydra and not hydra_exit_pending then
    hydra_exit_pending = true
    vim.schedule(function()
      if M.hydra then
        debug_log({
          "hydra=scheduled_exit",
          string.format(
            "menu_mode=%s stack=%d open=%s layer=%s",
            tostring(state.menu_mode),
            #state.menu_stack,
            tostring(popup.is_open()),
            tostring(M.hydra.layer ~= nil)
          ),
        })
        if M.hydra.layer then
          M.hydra.layer:exit()
        else
          M.hydra:exit()
        end
      end
    end)
  end
end

local function hydra_go_back()
  debug_log({
    "hydra=go_back",
    string.format("stack=%d open=%s", #state.menu_stack, tostring(popup.is_open())),
  })
  if #state.menu_stack > 1 then
    popup.go_back()
  else
    close_hydra_mode()
  end
end

local function hydra_activate_selected()
  local had_popup = popup.is_open()
  debug_log({
    "hydra=activate_selected_before",
    string.format("had_popup=%s stack=%d", tostring(had_popup), #state.menu_stack),
  })
  popup.activate_selected()
  debug_log({
    "hydra=activate_selected_after",
    string.format("open=%s stack=%d menu_mode=%s", tostring(popup.is_open()), #state.menu_stack, tostring(state.menu_mode)),
  })
  if had_popup and not popup.is_open() then
    close_hydra_mode()
  end
end

local function hydra_activate_item_key(key)
  local had_popup = popup.is_open()
  debug_log({
    "hydra=activate_item_key_before",
    string.format("key=%s had_popup=%s stack=%d", tostring(key), tostring(had_popup), #state.menu_stack),
  })
  local activated = popup.activate_item_key(key)
  debug_log({
    "hydra=activate_item_key_after",
    string.format("key=%s activated=%s open=%s stack=%d menu_mode=%s", tostring(key), tostring(activated), tostring(popup.is_open()), #state.menu_stack, tostring(state.menu_mode)),
  })
  if had_popup and activated and not popup.is_open() then
    close_hydra_mode()
  end
  return activated
end

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
    { "<CR>", hydra_activate_selected, { desc = "select" } },
    { "<BS>", hydra_go_back, { desc = "back" } },
    { "<Esc>", hydra_go_back, { desc = "back" } },
    { "q", close_hydra_mode, { exit = true, desc = "close" } },
  }

  for _, key in ipairs(collect_dynamic_keys()) do
    table.insert(heads, {
      key,
      function()
        if popup.is_open() then
          if not hydra_activate_item_key(key) then
            popup.activate_top_key(key)
          end
        else
          if not popup.activate_top_key(key) then
            hydra_activate_item_key(key)
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
        debug_log({ "hydra=on_enter", string.format("active_top=%s", tostring(state.active_top)) })
        popup.enter_menu_mode(state.active_top)
      end,
      on_exit = function()
        local pending_action = state.pending_action
        state.pending_action = nil
        hydra_exit_pending = false
        if popup.is_open() or #state.menu_stack > 0 or state.menu_mode then
          popup.close_all()
        else
          state.menu_mode = false
          state.menu_stack = {}
        end
        debug_log({
          "hydra=on_exit",
          string.format("menu_mode=%s stack=%d open=%s", tostring(state.menu_mode), #state.menu_stack, tostring(popup.is_open())),
        })
        if pending_action then
          vim.schedule(function()
            actions.execute_item(pending_action)
          end)
        end
      end,
    },
  })

  return M.hydra
end

return M
