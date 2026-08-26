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
local mouse_press_keys = {
  "<LeftMouse>",
  "<2-LeftMouse>",
  "<3-LeftMouse>",
  "<4-LeftMouse>",
}
local mouse_press_keycode_lookup = {}
local mouse_press_keytrans_lookup = {}
for _, key in ipairs(mouse_press_keys) do
  mouse_press_keycode_lookup[vim.keycode(key)] = true
  mouse_press_keytrans_lookup[key] = true
end
local special_key_prefix = string.char(128)
local mouse_key_hook_ns = vim.api.nvim_create_namespace("orca_menu_mouse_key_hook")
local mouse_mapping_desc = "Orca menu mouse handling"

local function current_map_mode()
  local current = vim.fn.mode()
  if current:sub(1, 1) == "i" then
    return "i"
  end
  if current == "v" or current == "V" or current == "\22" then
    return "x"
  end
  return "n"
end

local function mouse_mapping_summary(mode_name)
  local mapping = vim.fn.maparg("<LeftMouse>", mode_name, false, true)
  if type(mapping) ~= "table" or mapping.lhs == nil or mapping.lhs == "" then
    return nil
  end

  return {
    lhs = mapping.lhs,
    rhs = mapping.rhs,
    mode = mapping.mode,
    buffer = mapping.buffer,
    callback = mapping.callback ~= nil,
    expr = mapping.expr == 1,
    noremap = mapping.noremap == 1,
    silent = mapping.silent == 1,
    nowait = mapping.nowait == 1,
    desc = mapping.desc,
  }
end

local function mouse_mapping_owned_by_orca(mapping)
  return type(mapping) == "table" and mapping.desc == mouse_mapping_desc
end

local function position_summary(position)
  if type(position) ~= "table" then
    return nil
  end

  return {
    visible = position.visible,
    logical = vim.deepcopy(position.logical),
    screen = vim.deepcopy(position.screen),
  }
end

local function mouse_geometry_summary(layout)
  local labels = {}
  for index, menu in ipairs(state.config.menus or {}) do
    local label = layout.top_bar_display_label(menu, index)
    local label_width = vim.fn.strdisplaywidth(label)
    local label_start = state.label_positions[index]
    labels[index] = {
      label = label,
      label_width = label_width,
      label_start = label_start,
      label_end = label_start and label_start + label_width - 1 or nil,
      component = position_summary(state.component_positions[index]),
    }
  end

  local popups = {}
  for level, entry in ipairs(state.menu_stack or {}) do
    popups[level] = {
      content_row = entry.content_row,
      content_col = entry.content_col,
      content_width = entry.content_width,
      content_height = entry.content_height,
      frame_row = entry.frame_row,
      frame_col = entry.frame_col,
      frame_width = entry.frame_width,
      frame_height = entry.frame_height,
    }
  end

  return {
    statusline_row = vim.o.lines - vim.o.cmdheight,
    labels = labels,
    popups = popups,
  }
end

local trace_mouse = state.trace_mouse

local function capture_cursor_restore()
  local winid = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(winid) then
    return nil
  end

  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, winid)
  if not ok or type(cursor) ~= "table" then
    return nil
  end

  return {
    winid = winid,
    cursor = { cursor[1], cursor[2] },
  }
end

local function restore_cursor_after_mouse(snapshot)
  if not snapshot then
    return
  end

  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(snapshot.winid) then
      return
    end

    pcall(vim.api.nvim_win_set_cursor, snapshot.winid, snapshot.cursor)
  end)
end

local function is_mouse_press(typed)
  if type(typed) ~= "string" then
    return false
  end

  if mouse_press_keycode_lookup[typed] then
    return true
  end

  if typed:sub(1, 1) ~= special_key_prefix then
    return false
  end

  return mouse_press_keytrans_lookup[vim.fn.keytrans(typed)] == true
end

local function install_mouse_key_hook()
  if state.mouse_key_hook_installed then
    return
  end

  vim.on_key(function(_, typed)
    if not is_mouse_press(typed) then
      return
    end

    local mouse = vim.fn.getmousepos()
    local mode_name = current_map_mode()
    local layout = require("orca_menu.layout")
    local popup_open = popup.is_open()
    local bar_index = layout.label_hit_at_col(math.max((mouse.screencol or 1), 1), mouse)
    local mapping = mouse_mapping_summary(mode_name)
    local trace_extra = {
      phase = "pre_mapping",
      typed = vim.fn.keytrans(typed),
      map_mode = mode_name,
      mapping = mapping,
      current_win = vim.api.nvim_get_current_win(),
      current_buf = vim.api.nvim_get_current_buf(),
      bar_index = bar_index,
      statusline_hit = bar_index ~= nil,
      popup_open = popup_open,
      geometry = mouse_geometry_summary(layout),
    }
    trace_mouse("<LeftMouse>", trace_extra, mouse)

    -- Popup mappings already own this event. The hook only needs to take over
    -- when another buffer-local mapping would otherwise steal it from Orca.
    if popup_open and mouse_mapping_owned_by_orca(mapping) then
      return
    end

    if popup_open then
      local cursor_restore = bar_index and capture_cursor_restore() or nil
      mode.run_after_editor_mode(function()
        popup.handle_mouse(mouse)
        trace_extra.phase = "intercepted_popup"
        trace_mouse("<LeftMouse>", trace_extra, mouse)
      end)
      restore_cursor_after_mouse(cursor_restore)
      return ""
    end

    if not bar_index then
      return
    end

    local cursor_restore = capture_cursor_restore()
    require("orca_menu").click(bar_index, mouse)
    restore_cursor_after_mouse(cursor_restore)
    trace_extra.phase = "intercepted_statusline"
    trace_mouse("<LeftMouse>", trace_extra, mouse)
    return ""
  end, mouse_key_hook_ns)

  state.mouse_key_hook_installed = true
end

local function disable_mouse_key_hook()
  if not state.mouse_key_hook_installed then
    return
  end

  vim.on_key(nil, mouse_key_hook_ns)
  state.mouse_key_hook_installed = false
end

local function bind(keys, fn, opts)
  opts = vim.tbl_extend("force", { silent = true, noremap = true }, opts or {})
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

local function restore_mousemoveevent()
  if state.mousemoveevent_was_enabled == nil then
    return
  end

  vim.o.mousemoveevent = state.mousemoveevent_was_enabled
  state.mousemoveevent_was_enabled = nil
end

local function enable_mousemoveevent()
  if state.mousemoveevent_was_enabled ~= nil then
    return
  end

  state.mousemoveevent_was_enabled = vim.o.mousemoveevent
  if not vim.o.mousemoveevent then
    vim.o.mousemoveevent = true
  end
end

local function hover_topbar_enabled()
  return state.config
    and state.config.enable_mouse ~= false
    and state.config.submenu
    and state.config.submenu.hover_topbar == true
end

local function hover_select_enabled()
  return state.config
    and state.config.enable_mouse ~= false
    and state.config.submenu
    and state.config.submenu.hover_select == true
end

local function handle_mousemove()
  trace_mouse("<MouseMove>", { phase = "start" })
  if mode.is_insert() then
    trace_mouse("<MouseMove>", { phase = "ignored_insert" })
    return
  end

  local handled = false
  if hover_select_enabled() then
    handled = popup.hover_at_mouse()
  end
  if not handled and hover_topbar_enabled() then
    handled = popup.hover_topbar_at_mouse()
  end
  if handled then
    trace_mouse("<MouseMove>", { phase = "handled_popup" })
  end
end

local function should_install_mousemove()
  if state.config and state.config.enable_mouse == false then
    return false
  end

  if not popup.is_open() then
    return false
  end

  return hover_select_enabled() or hover_topbar_enabled()
end

local function install_mousemove_binding()
  if not should_install_mousemove() then
    return
  end

  enable_mousemoveevent()
  vim.keymap.set({ "n", "i" }, "<MouseMove>", handle_mousemove, { silent = true })
end

local function disable_mousemove_binding()
  pcall(vim.keymap.del, "n", "<MouseMove>")
  pcall(vim.keymap.del, "i", "<MouseMove>")
  restore_mousemoveevent()
end

local function refresh_mousemove_binding()
  if should_install_mousemove() then
    install_mousemove_binding()
  else
    disable_mousemove_binding()
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
  local hydra_mode = require("orca_menu.hydra_mode")
  if hydra_mode.is_active() then
    return
  end
  if state.keymaps_installed then
    return
  end
  refresh_dynamic_top_keys()
  refresh_dynamic_item_keys()
  local keymap_opts = { silent = true, noremap = true }
  local owner_buf = state.menu_owner_buf
  if owner_buf then
    keymap_opts.buffer = owner_buf
  end
  bind(state.config.keys.next, function() popup.move_top(1) end, keymap_opts)
  bind(state.config.keys.prev, function() popup.move_top(-1) end, keymap_opts)
  bind(state.config.keys.down, function() popup.select_row(1) end, keymap_opts)
  bind(state.config.keys.up, function() popup.select_row(-1) end, keymap_opts)
  bind(state.config.keys.select, popup.activate_selected, keymap_opts)
  bind(state.config.keys.back, popup.go_back, keymap_opts)
  bind(state.config.keys.close, popup.close_all, keymap_opts)
  for _, key in ipairs(dynamic_top_keys) do
    vim.keymap.set(keymap_modes, key, function()
      mode.run_after_editor_mode(function()
        if not popup.activate_top_key(key) and not popup.activate_item_key(key) then
          replay_key(key)
        end
      end)
    end, keymap_opts)
  end
  for _, key in ipairs(dynamic_item_keys) do
    vim.keymap.set(keymap_modes, key, function()
      mode.run_after_editor_mode(function()
        if not popup.activate_top_key(key) and not popup.activate_item_key(key) then
          replay_key(key)
        end
      end)
    end, keymap_opts)
  end
  state.keymaps_installed = true
end

function M.disable_keys(owner_buf)
  if not state.keymaps_installed then
    return
  end
  local keymap_opts = { }
  local buffer = owner_buf or state.menu_owner_buf
  if buffer then
    keymap_opts.buffer = buffer
  end
  for _, key in ipairs(all_keys()) do
    pcall(vim.keymap.del, "n", key, keymap_opts)
    pcall(vim.keymap.del, "x", key, keymap_opts)
  end
  state.keymaps_installed = false
end

local function valid_buffer(bufnr)
  return type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr)
end

local function buffer_mapping(bufnr, mode_name, lhs)
  if not valid_buffer(bufnr) then
    return nil
  end

  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode_name)) do
    if mapping.lhs == lhs then
      return mapping
    end
  end

  return nil
end

local function mapping_bool(value)
  return value == true or value == 1
end

local function restore_buffer_mapping(bufnr, mapping)
  if not valid_buffer(bufnr) or type(mapping) ~= "table" then
    return
  end

  local rhs = mapping.callback or mapping.rhs
  if rhs == nil then
    return
  end

  local opts = {
    buffer = bufnr,
    expr = mapping_bool(mapping.expr),
    nowait = mapping_bool(mapping.nowait),
    remap = not mapping_bool(mapping.noremap),
    silent = mapping_bool(mapping.silent),
  }
  if mapping.desc and mapping.desc ~= "" then
    opts.desc = mapping.desc
  end

  pcall(vim.keymap.set, mapping.mode, mapping.lhs, rhs, opts)
end

local function owner_mapping_key(mode_name, lhs)
  return mode_name .. "\n" .. lhs
end

local function remember_owner_mapping(bufnr, mode_name, lhs)
  if not valid_buffer(bufnr) then
    return
  end

  state.mouse_owner_mappings = state.mouse_owner_mappings or {}
  local key = owner_mapping_key(mode_name, lhs)
  if state.mouse_owner_mappings[key] ~= nil then
    return
  end

  state.mouse_owner_mappings[key] = buffer_mapping(bufnr, mode_name, lhs) or false
end

local function restore_owner_mouse_mappings(bufnr)
  local saved = state.mouse_owner_mappings
  state.mouse_owner_mappings = nil
  if not saved or not valid_buffer(bufnr) then
    return
  end

  for key, mapping in pairs(saved) do
    local mode_name, lhs = key:match("^(.-)\n(.+)$")
    if mode_name and lhs then
      pcall(vim.keymap.del, mode_name, lhs, { buffer = bufnr })
      if mapping then
        restore_buffer_mapping(bufnr, mapping)
      end
    end
  end
end

function M.disable_mouse(owner_buf)
  restore_owner_mouse_mappings(owner_buf or state.mouse_owner_buf)
  state.mouse_owner_buf = nil

  for _, key in ipairs(mouse_keys) do
    pcall(vim.keymap.del, "n", key)
    pcall(vim.keymap.del, "x", key)
    pcall(vim.keymap.del, "i", key)
  end

  state.global_mouse_installed = false
  refresh_mousemove_binding()
end

function M.install_mouse()
  if state.config and state.config.enable_mouse == false then
    M.disable_mouse()
    disable_mouse_key_hook()
    return
  end

  install_mouse_key_hook()
  refresh_mousemove_binding()

  if not popup.is_open() then
    M.disable_mouse()
    return
  end

  local owner_buf = valid_buffer(state.menu_owner_buf) and state.menu_owner_buf or nil
  if state.global_mouse_installed and state.mouse_owner_buf == owner_buf then
    return
  end

  if state.global_mouse_installed or state.mouse_owner_buf then
    M.disable_mouse()
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
      local mouse = vim.fn.getmousepos()
      mode.run_after_editor_mode(function()
        popup.handle_mouse(mouse)
        trace_mouse(event, { phase = "handled_popup", keys = keys })
      end)
    else
      local mouse = vim.fn.getmousepos()
      local layout = require("orca_menu.layout")
      local bar_index = layout.label_hit_at_col(math.max((mouse.screencol or 1), 1), mouse)
      if bar_index then
        local hit_context = layout.last_topbar_hit(bar_index)
        mode.run_after_editor_mode(function()
          popup.open_top(bar_index, hit_context)
          trace_mouse(event, { phase = "opened_top", keys = keys, bar_index = bar_index })
        end)
      else
        fallback_mouse(keys)
      end
    end
  end

  local function mouse_opts(opts)
    return vim.tbl_extend("force", {
      desc = mouse_mapping_desc,
      silent = true,
    }, opts or {})
  end

  local function set_mouse_map(modes, lhs, callback, opts)
    if opts and opts.buffer then
      for _, mode_name in ipairs(modes) do
        remember_owner_mapping(opts.buffer, mode_name, lhs)
      end
    end

    vim.keymap.set(modes, lhs, callback, mouse_opts(opts))
  end

  local function install_mouse_maps(opts)
    set_mouse_map(entry_modes, "<LeftMouse>", function()
      handle_left_mouse("<LeftMouse>", "<LeftMouse>", true)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<2-LeftMouse>", function()
      handle_left_mouse("<2-LeftMouse>", "<2-LeftMouse>", true)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<3-LeftMouse>", function()
      handle_left_mouse("<3-LeftMouse>", "<3-LeftMouse>", true)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<4-LeftMouse>", function()
      handle_left_mouse("<4-LeftMouse>", "<4-LeftMouse>", true)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<LeftRelease>", function()
      handle_left_mouse("<LeftRelease>", "<LeftRelease>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<2-LeftRelease>", function()
      handle_left_mouse("<2-LeftRelease>", "<2-LeftRelease>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<3-LeftRelease>", function()
      handle_left_mouse("<3-LeftRelease>", "<3-LeftRelease>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<4-LeftRelease>", function()
      handle_left_mouse("<4-LeftRelease>", "<4-LeftRelease>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<LeftDrag>", function()
      handle_left_mouse("<LeftDrag>", "<LeftDrag>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<2-LeftDrag>", function()
      handle_left_mouse("<2-LeftDrag>", "<2-LeftDrag>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<3-LeftDrag>", function()
      handle_left_mouse("<3-LeftDrag>", "<3-LeftDrag>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<4-LeftDrag>", function()
      handle_left_mouse("<4-LeftDrag>", "<4-LeftDrag>", false)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<ScrollWheelUp>", function()
      trace_mouse("<ScrollWheelUp>", { phase = "start" })
      mode.run_after_editor_mode(function()
        if not popup.scroll_at_mouse(-1) then
          fallback_mouse("<ScrollWheelUp>")
        else
          trace_mouse("<ScrollWheelUp>", { phase = "handled_popup" })
        end
      end)
    end, opts)

    set_mouse_map(nonvisual_entry_modes, "<ScrollWheelDown>", function()
      trace_mouse("<ScrollWheelDown>", { phase = "start" })
      mode.run_after_editor_mode(function()
        if not popup.scroll_at_mouse(1) then
          fallback_mouse("<ScrollWheelDown>")
        else
          trace_mouse("<ScrollWheelDown>", { phase = "handled_popup" })
        end
      end)
    end, opts)
  end

  install_mouse_maps()
  if owner_buf then
    install_mouse_maps({ buffer = owner_buf })
  end

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
  state.mouse_owner_buf = owner_buf
end

return M
