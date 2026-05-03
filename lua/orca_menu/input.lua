local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local mode = require("orca_menu.mode")

local M = {}

local dynamic_item_keys = {}
local dynamic_top_keys = {}
local keymap_modes = { "n", "x" }
local entry_modes = { "n", "x", "i" }
local nonvisual_entry_modes = { "n", "i" }
local mouse_keys = {
  "<LeftMouse>",
  "<2-LeftMouse>",
  "<3-LeftMouse>",
  "<4-LeftMouse>",
  "<LeftRelease>",
  "<2-LeftRelease>",
  "<3-LeftRelease>",
  "<4-LeftRelease>",
  "<LeftDrag>",
  "<2-LeftDrag>",
  "<3-LeftDrag>",
  "<4-LeftDrag>",
  "<ScrollWheelUp>",
  "<ScrollWheelDown>",
}
local mouse_key_lookup = {}

for _, key in ipairs(mouse_keys) do
  mouse_key_lookup[key] = true
end

local function trace_mouse(event, extra)
  local trace_path = state.mouse_trace_path or vim.env.ORCA_MENU_MOUSE_TRACE
  if type(trace_path) ~= "string" or trace_path == "" then
    return
  end

  local mouse = vim.fn.getmousepos()
  local line = vim.json.encode({
    event = event,
    mouse = mouse,
    mode = vim.fn.mode(),
    popup_open = popup.is_open(),
    menu_mode = state.menu_mode,
    active_top = state.active_top,
    stack_depth = #state.menu_stack,
    extra = extra,
    time = vim.loop.hrtime(),
  })

  if not line then
    return
  end

  pcall(vim.fn.writefile, { line }, trace_path, "a")
end

local function bind(keys, fn)
  local opts = { silent = true, noremap = true }
  for _, key in ipairs(keys or {}) do
    vim.keymap.set(keymap_modes, key, function()
      fn()
    end, opts)
  end
end

local function replay_key(key)
  if mode.is_visual() then
    vim.api.nvim_feedkeys(vim.keycode(key), "x", false)
  elseif mode.is_insert() then
    vim.api.nvim_feedkeys(vim.keycode(key), "i", false)
  else
    vim.api.nvim_feedkeys(vim.keycode(key), "n", false)
  end

  if mouse_key_lookup[key] then
    vim.schedule(function()
      M.install_mouse()
    end)
  end
end

local function replay_mouse(key)
  M.disable_mouse()
  vim.api.nvim_input(vim.keycode(key))

  vim.schedule(function()
    M.install_mouse()
  end)
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
  local hydra_mode = require("orca_menu.hydra_mode")
  if hydra_mode.is_active() then
    return
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
    vim.keymap.set(keymap_modes, key, function()
      mode.run_after_editor_mode(function()
        if not popup.activate_top_key(key) and not popup.activate_item_key(key) then
          replay_key(key)
        end
      end)
    end, { silent = true, noremap = true })
  end
  for _, key in ipairs(dynamic_item_keys) do
    vim.keymap.set(keymap_modes, key, function()
      mode.run_after_editor_mode(function()
        if not popup.activate_top_key(key) and not popup.activate_item_key(key) then
          replay_key(key)
        end
      end)
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
    pcall(vim.keymap.del, "x", key)
  end
  state.keymaps_installed = false
end

function M.disable_mouse()
  for _, key in ipairs(mouse_keys) do
    pcall(vim.keymap.del, "n", key)
    pcall(vim.keymap.del, "x", key)
    pcall(vim.keymap.del, "i", key)
  end

  state.global_mouse_installed = false
end

function M.install_mouse()
  if state.config and state.config.enable_mouse == false then
    M.disable_mouse()
    return
  end

  if not popup.is_open() then
    M.disable_mouse()
    return
  end

  if state.global_mouse_installed then
    return
  end

  local function fallback_mouse(keys)
    trace_mouse("fallback", { keys = keys })
    replay_mouse(keys)
  end

  local function handle_left_mouse(event, keys, allow_menu_click)
    trace_mouse(event, { phase = "start", keys = keys, allow_menu_click = allow_menu_click })
    if not allow_menu_click then
      if popup.is_open() then
        trace_mouse(event, { phase = "swallowed_popup", keys = keys })
      else
        trace_mouse(event, { phase = "fallback_inactive", keys = keys })
        fallback_mouse(keys)
      end
      return
    end

    if popup.is_open() then
      mode.run_after_editor_mode(function()
        popup.handle_mouse()
        trace_mouse(event, { phase = "handled_popup", keys = keys })
      end)
    else
      local mouse = vim.fn.getmousepos()
      local layout = require("orca_menu.layout")
      local bar_index = layout.label_hit_at_col(math.max((mouse.screencol or 1) - 1, 0))
      if bar_index then
        mode.run_after_editor_mode(function()
          popup.open_top(bar_index)
          trace_mouse(event, { phase = "opened_top", keys = keys, bar_index = bar_index })
        end)
      else
        fallback_mouse(keys)
      end
    end
  end

  vim.keymap.set(entry_modes, "<LeftMouse>", function()
    handle_left_mouse("<LeftMouse>", "<LeftMouse>", true)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<2-LeftMouse>", function()
    handle_left_mouse("<2-LeftMouse>", "<2-LeftMouse>", true)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<3-LeftMouse>", function()
    handle_left_mouse("<3-LeftMouse>", "<3-LeftMouse>", true)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<4-LeftMouse>", function()
    handle_left_mouse("<4-LeftMouse>", "<4-LeftMouse>", true)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<LeftRelease>", function()
    handle_left_mouse("<LeftRelease>", "<LeftRelease>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<2-LeftRelease>", function()
    handle_left_mouse("<2-LeftRelease>", "<2-LeftRelease>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<3-LeftRelease>", function()
    handle_left_mouse("<3-LeftRelease>", "<3-LeftRelease>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<4-LeftRelease>", function()
    handle_left_mouse("<4-LeftRelease>", "<4-LeftRelease>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<LeftDrag>", function()
    handle_left_mouse("<LeftDrag>", "<LeftDrag>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<2-LeftDrag>", function()
    handle_left_mouse("<2-LeftDrag>", "<2-LeftDrag>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<3-LeftDrag>", function()
    handle_left_mouse("<3-LeftDrag>", "<3-LeftDrag>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<4-LeftDrag>", function()
    handle_left_mouse("<4-LeftDrag>", "<4-LeftDrag>", false)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<ScrollWheelUp>", function()
    trace_mouse("<ScrollWheelUp>", { phase = "start" })
    mode.run_after_editor_mode(function()
      if not popup.scroll_at_mouse(-1) then
        fallback_mouse("<ScrollWheelUp>")
      else
        trace_mouse("<ScrollWheelUp>", { phase = "handled_popup" })
      end
    end)
  end, { silent = true })

  vim.keymap.set(nonvisual_entry_modes, "<ScrollWheelDown>", function()
    trace_mouse("<ScrollWheelDown>", { phase = "start" })
    mode.run_after_editor_mode(function()
      if not popup.scroll_at_mouse(1) then
        fallback_mouse("<ScrollWheelDown>")
      else
        trace_mouse("<ScrollWheelDown>", { phase = "handled_popup" })
      end
    end)
  end, { silent = true })

  for _, key in ipairs({ "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>" }) do
    pcall(vim.keymap.del, "x", key)
  end

  for _, key in ipairs({
    "<LeftRelease>",
    "<2-LeftRelease>",
    "<3-LeftRelease>",
    "<4-LeftRelease>",
    "<LeftDrag>",
    "<2-LeftDrag>",
    "<3-LeftDrag>",
    "<4-LeftDrag>",
    "<ScrollWheelUp>",
    "<ScrollWheelDown>",
  }) do
    pcall(vim.keymap.del, "x", key)
  end

  state.global_mouse_installed = true
end

return M
