local M = {
  config = nil,
  base_config = nil,
  active_top = 1,
  windows = {},
  buffers = {},
  menu_stack = {},
  pending_action = nil,
  anchor = { row = nil, col = nil },
  label_positions = {},
  menu_mode = false,
  global_mouse_installed = false,
  keymaps_installed = false,
  current_open_key = nil,
  current_open_backend = nil,
  mouse_trace_path = nil,
  namespace = vim.api.nvim_create_namespace("orca_menu"),
}

return M
