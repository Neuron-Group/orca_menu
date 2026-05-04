local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "gm",
  },
  menus = {
    { label = "&File", key = "f", items = { { label = "&Open", key = "o", action = function() end } } },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local function press_typed(keys)
  vim.fn.feedkeys(keys, "xt")
  H.flush()
  H.flush()
end

local visual_map = vim.fn.maparg("gm", "x", false, true)
local insert_map = vim.fn.maparg("gm", "i", false, true)
local normal_map = vim.fn.maparg("gm", "n", false, true)

H.truthy(visual_map.callback, "multi-key open sequence should be mapped in visual mode")
H.truthy(insert_map.callback, "multi-key open sequence should be mapped in insert mode")
H.truthy(normal_map.callback, "multi-key open sequence should be mapped in normal mode")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta" })
vim.cmd("normal! gg0v$")
press_typed("gm")
H.eq(vim.fn.mode(), "n", "typed gm should leave visual mode")
H.truthy(state.menu_mode, "typed gm should enable menu mode from visual mode")
H.falsy(popup.is_open(), "typed gm should not open popup immediately from visual mode")

popup.close_all()
vim.cmd("normal! gg0")
vim.fn.feedkeys("igm", "xt")
H.flush()
H.flush()
H.eq(vim.fn.mode(), "n", "typed gm should leave insert mode")
H.truthy(state.menu_mode, "typed gm should enable menu mode from insert mode")
H.falsy(popup.is_open(), "typed gm should not open popup immediately from insert mode")

popup.close_all()
press_typed("gm")
H.truthy(state.menu_mode, "typed gm should enable menu mode from normal mode")
H.falsy(popup.is_open(), "typed gm should not open popup immediately from normal mode")

H.finish()
print("ok - tests/integration/multi_key_open.lua")
