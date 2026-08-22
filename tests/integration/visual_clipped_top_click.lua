local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&Help",
      key = "h",
      items = {
        { label = "&About", key = "a", action = function() end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Explorer", key = "e", action = function() end },
      },
    },
    {
      label = "&Search",
      key = "s",
      items = {
        { label = "&Find", key = "f", action = function() end },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

vim.o.laststatus = 2
vim.cmd("set columns=25")
H.render_statusline()

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
vim.cmd("normal! gg0v$")
H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "test should enter visual mode")

local mouse = {
  screenrow = vim.o.lines - vim.o.cmdheight,
  screencol = 1,
}
local restore_mouse = H.stub_mouse(mouse)

_G.orca_menu_click_menu_2()
H.flush()
H.flush()

H.truthy(vim.fn.mode() == "v" or vim.fn.mode() == "V", "clipped top-bar fragment click should not leave visual mode")
H.falsy(state.menu_mode, "clipped top-bar fragment click should not enter menu mode")
H.falsy(popup.is_open(), "clipped top-bar fragment click should not open popup")
H.falsy(state.menu_context and state.menu_context.selection, "clipped top-bar fragment click should not preserve Orca selection context")

restore_mouse()
H.finish()
print("ok - tests/integration/visual_clipped_top_click.lua")
