local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local M = {}

local dynamic_item_keys = {}
local dynamic_top_keys = {}

local function bind(keys, fn)
  local opts = { silent = true, noremap = true }
  for _, key in ipairs(keys or {}) do
    vim.keymap.set("n", key, function()
      fn()
    end, opts)
  end
end

local function all_keys()
  local keys = {}
  local seen = {}
  local function add(list)
    for _, key in ipairs(list or {}) do
      if not seen[key] then
        table.insert(keys, key)
        seen[key] = true
      end
    end
  end
  local function add_key(key)
    if key and not seen[key] then
      table.insert(keys, key)
      seen[key] = true
    end
  end
  add(state.config.keys.next)
  add(state.config.keys.prev)
  add(state.config.keys.down)
  add(state.config.keys.up)
  add(state.config.keys.select)
  add(state.config.keys.back)
  add(state.config.keys.close)
  for _, key in ipairs(dynamic_top_keys) do
    add_key(key)
  end
  for _, key in ipairs(dynamic_item_keys) do
    add_key(key)
  end
  return keys
end

local function collect_item_keys(items, seen)
  for _, item in ipairs(items or {}) do
    if item.key and item.key ~= "" and not seen[item.key] then
      table.insert(dynamic_item_keys, item.key)
      seen[item.key] = true
    end
    if item.items then
      collect_item_keys(item.items, seen)
    end
  end
end

local function refresh_dynamic_item_keys()
  dynamic_item_keys = {}
  local seen = {}
  for _, menu in ipairs(state.config.menus or {}) do
    collect_item_keys(menu.items, seen)
  end
end

local function refresh_dynamic_top_keys()
  dynamic_top_keys = {}
  local seen = {}
  for _, menu in ipairs(state.config.menus or {}) do
    if menu.key and menu.key ~= "" and not seen[menu.key] then
      table.insert(dynamic_top_keys, menu.key)
      seen[menu.key] = true
    end
  end
end

function M.enable_keys()
  if state.config and state.config.keys.mode_backend == "hydra" then
    local hydra_mode = require("orca_menu.hydra_mode")
    if hydra_mode.is_active() then
      return
    end
  end
  if state.keymaps_installed then
    return
  end
  refresh_dynamic_top_keys()
  refresh_dynamic_item_keys()
  bind(state.config.keys.next, function() popup.move_top(1) end)
  bind(state.config.keys.prev, function() popup.move_top(-1) end)
  bind(state.config.keys.down, function() popup.select_row(1) end)
  bind(state.config.keys.up, function() popup.select_row(-1) end)
  bind(state.config.keys.select, popup.activate_selected)
  bind(state.config.keys.back, popup.go_back)
  bind(state.config.keys.close, popup.close_all)
  for _, key in ipairs(dynamic_top_keys) do
    vim.keymap.set("n", key, function()
      if not popup.activate_top_key(key) and not popup.activate_item_key(key) then
        local fallback = vim.fn.keytrans(key)
        vim.cmd.exec(string.format('"normal! %s"', fallback))
      end
    end, { silent = true, noremap = true })
  end
  for _, key in ipairs(dynamic_item_keys) do
    vim.keymap.set("n", key, function()
      if not popup.activate_top_key(key) and not popup.activate_item_key(key) then
        local fallback = vim.fn.keytrans(key)
        vim.cmd.exec(string.format('"normal! %s"', fallback))
      end
    end, { silent = true, noremap = true })
  end
  state.keymaps_installed = true
end

function M.disable_keys()
  if not state.keymaps_installed then
    return
  end
  for _, key in ipairs(all_keys()) do
    pcall(vim.keymap.del, "n", key)
  end
  state.keymaps_installed = false
end

function M.install_mouse()
  if state.global_mouse_installed then
    return
  end
  if state.config and state.config.enable_mouse == false then
    return
  end

  local function fallback_mouse(keys)
    vim.cmd.exec(string.format('"normal! %s"', keys))
  end

  vim.keymap.set("n", "<LeftMouse>", function()
    if popup.is_open() then
      popup.handle_mouse()
    else
      local mouse = vim.fn.getmousepos()
      local layout = require("orca_menu.layout")
      local bar_index = layout.label_hit_at_col(math.max((mouse.screencol or 1) - 1, 0))
      if bar_index then
        popup.open_top(bar_index)
      else
        fallback_mouse("\\<LeftMouse>")
      end
    end
  end, { silent = true })

  vim.keymap.set("n", "<ScrollWheelUp>", function()
    if not popup.scroll_at_mouse(-1) then
      fallback_mouse("\\<ScrollWheelUp>")
    end
  end, { silent = true })

  vim.keymap.set("n", "<ScrollWheelDown>", function()
    if not popup.scroll_at_mouse(1) then
      fallback_mouse("\\<ScrollWheelDown>")
    end
  end, { silent = true })

  state.global_mouse_installed = true
end

return M
