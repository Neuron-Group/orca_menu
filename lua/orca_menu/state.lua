local M = {
  config = nil,
  base_config = nil,
  dynamic_menus = {},
  dynamic_menu_order = {},
  active_top = 1,
  windows = {},
  buffers = {},
  menu_stack = {},
  pending_action = nil,
  pending_context = nil,
  menu_context = nil,
  last_visual_context = nil,
  last_visual_exit_ns = 0,
  menu_owner_win = nil,
  last_topbar_hit = nil,
  anchor = { row = nil, col = nil },
  label_positions = {},
  component_positions = {},
  menu_mode = false,
  opening_top_popup = false,
  global_mouse_installed = false,
  keymaps_installed = false,
  current_open_key = nil,
  last_refresh_signature = nil,
  mouse_trace_path = nil,
  mouse_key_hook_installed = false,
  mousemoveevent_was_enabled = nil,
  selection_namespace = vim.api.nvim_create_namespace("orca_menu_selection"),
  namespace = vim.api.nvim_create_namespace("orca_menu"),
}

function M.trace_mouse(event, extra, mouse)
  local trace_path = M.mouse_trace_path or vim.env.ORCA_MENU_MOUSE_TRACE
  if type(trace_path) ~= "string" or trace_path == "" then
    return
  end

  mouse = mouse or vim.fn.getmousepos()
  local line = vim.json.encode({
    event = event,
    mouse = mouse,
    mode = vim.fn.mode(),
    popup_open = #M.windows > 0,
    menu_mode = M.menu_mode,
    active_top = M.active_top,
    stack_depth = #M.menu_stack,
    extra = extra,
    time = vim.loop.hrtime(),
  })

  if not line then
    return
  end

  pcall(vim.fn.writefile, { line }, trace_path, "a")
end

return M
