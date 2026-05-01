local M = {
  config = nil,
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
  namespace = vim.api.nvim_create_namespace("orca_menu"),
}

return M
