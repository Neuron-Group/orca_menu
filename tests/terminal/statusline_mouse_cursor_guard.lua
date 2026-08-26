local outfile = vim.env.ORCA_TERMINAL_RESULT
local readyfile = vim.env.ORCA_TERMINAL_READY

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

if not readyfile or readyfile == "" then
  error("ORCA_TERMINAL_READY is required")
end

vim.o.mouse = "a"
vim.o.laststatus = 2
vim.o.cmdheight = 1

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "ten",
})
vim.api.nvim_win_set_cursor(0, { 5, 3 })

vim.g.orca_terminal_action = 0
vim.g.orca_terminal_local_mouse = 0
vim.keymap.set("n", "<Plug>(OrcaTerminalOriginalMouse)", function()
  vim.g.orca_terminal_local_mouse = vim.g.orca_terminal_local_mouse + 1
end, { buffer = 0, desc = "Original buffer-local mouse mapping" })
vim.keymap.set(
  "n",
  "<LeftMouse>",
  "<Plug>(OrcaTerminalOriginalMouse)",
  { buffer = 0, desc = "Original buffer-local mouse mapping", remap = true }
)

local lualine = require("lualine")
lualine.setup({
  options = {
    globalstatus = false,
  },
  sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
})

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_terminal_action = vim.g.orca_terminal_action + 1
            vim.api.nvim_win_set_cursor(0, { 3, 2 })
          end,
        },
      },
    },
  },
})

local layout = require("orca_menu.layout")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

lualine.refresh({ force = true, scope = "all", place = { "statusline" } })
layout.refresh_label_positions()
vim.cmd("redrawstatus")
vim.cmd("redraw")

local component = assert(state.component_positions[1] and state.component_positions[1].screen)
local item = component.item or component
vim.fn.writefile({ vim.json.encode({
  row = item.row,
  col = item.start_col,
}) }, readyfile)

local popup_readyfile = readyfile .. ".popup"
local function write_popup_ready()
  local entry = state.menu_stack[1]
  if popup.is_open() and entry then
    vim.fn.writefile({ vim.json.encode({
      row = entry.content_row,
      col = entry.content_col,
    }) }, popup_readyfile)
    return
  end

  vim.defer_fn(write_popup_ready, 50)
end

write_popup_ready()

vim.defer_fn(function()
  local restored_mapping = vim.fn.maparg("<LeftMouse>", "n", false, true)
  vim.fn.writefile({ vim.json.encode({
    action = vim.g.orca_terminal_action,
    popup_open = popup.is_open(),
    local_mouse = vim.g.orca_terminal_local_mouse,
    cursor = vim.api.nvim_win_get_cursor(0),
    current_win = vim.api.nvim_get_current_win(),
    mouse = vim.fn.getmousepos(),
    restored_mapping = {
      desc = restored_mapping.desc,
      rhs = restored_mapping.rhs,
      buffer = restored_mapping.buffer,
      noremap = restored_mapping.noremap,
    },
  }) }, outfile)
  vim.cmd("qa!")
end, 1500)
