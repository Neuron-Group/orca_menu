local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.mapleader = " "

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<leader>m",
    mode_backend = "builtin",
    next = { "l" },
    prev = { "h" },
    down = { "j" },
    up = { "k" },
    select = { "<CR>" },
    back = { "<Esc>" },
    close = { "q" },
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "&Open", key = "o", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local function press_leader_open_typed(mode_prefix)
  vim.fn.feedkeys((mode_prefix or "") .. vim.keycode("<leader>m"), "xt")
  H.flush()
  H.flush()
end

local visual_map = vim.fn.maparg("<leader>m", "x", false, true)
local insert_map = vim.fn.maparg("<leader>m", "i", false, true)
local normal_map = vim.fn.maparg("<leader>m", "n", false, true)

H.truthy(visual_map.callback, "leader open key should be mapped in visual mode")
H.truthy(insert_map.callback, "leader open key should be mapped in insert mode")
H.truthy(normal_map.callback, "leader open key should be mapped in normal mode")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta" })
vim.cmd("normal! gg0v$")
press_leader_open_typed()
H.eq(vim.fn.mode(), "n", "leader open key should leave visual mode")
H.truthy(state.menu_mode, "leader open key from visual mode should enable menu mode")
H.falsy(popup.is_open(), "leader open key from visual mode should not open popup immediately")

popup.close_all()
vim.cmd("normal! gg0")
press_leader_open_typed("i")
H.eq(vim.fn.mode(), "n", "leader open key should leave insert mode")
H.truthy(state.menu_mode, "leader open key from insert mode should enable menu mode")
H.falsy(popup.is_open(), "leader open key from insert mode should not open popup immediately")

popup.close_all()
press_leader_open_typed()
H.truthy(state.menu_mode, "leader open key from normal mode should enable menu mode")
H.falsy(popup.is_open(), "leader open key from normal mode should not open popup immediately")

H.finish()
print("ok - tests/integration/leader_open_key.lua")
