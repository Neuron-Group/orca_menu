local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F12>",
  },
  menus = {
    { label = "&File", key = "f", items = { { label = "&Open", key = "o", action = function() end } } },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

local function press_typed(keys)
  vim.fn.feedkeys(vim.keycode(keys), "xt")
  H.flush()
  H.flush()
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta" })
vim.cmd("normal! gg0v$")
press_typed("<F12>")
H.eq(vim.fn.mode(), "n", "typed <F12> should leave visual mode")
H.truthy(state.menu_mode, "typed <F12> should enable menu mode from visual mode")
H.falsy(popup.is_open(), "typed <F12> should not open popup immediately from visual mode")

popup.close_all()
vim.cmd("normal! gg0")
vim.fn.feedkeys("i" .. vim.keycode("<F12>"), "xt")
H.flush()
H.flush()
H.eq(vim.fn.mode(), "n", "typed <F12> should leave insert mode")
H.truthy(state.menu_mode, "typed <F12> should enable menu mode from insert mode")
H.falsy(popup.is_open(), "typed <F12> should not open popup immediately from insert mode")

H.finish()
print("ok - tests/integration/function_key_open.lua")
