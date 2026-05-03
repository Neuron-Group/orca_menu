local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_notify_regression_count = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
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
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_notify_regression_count = vim.g.orca_notify_regression_count + 1

            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "transient notify" })

            local notify_win = vim.api.nvim_open_win(buf, true, {
              relative = "editor",
              row = 1,
              col = math.max(vim.o.columns - 20, 1),
              width = 18,
              height = 1,
              focusable = true,
              style = "minimal",
              border = "rounded",
            })

            vim.defer_fn(function()
              if vim.api.nvim_win_is_valid(notify_win) then
                vim.api.nvim_win_close(notify_win, true)
              end
            end, 60)
          end,
        },
      },
    },
  },
})

local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

H.render_statusline()

require("orca_menu").open_menu(1)
H.truthy(popup.is_open(), "menu should open before executing the notify action")

popup.activate_selected()
H.flush()

H.eq(vim.g.orca_notify_regression_count, 1, "notify-like action should run once")
H.falsy(popup.is_open(), "action execution should close the original menu")

H.flush()

require("orca_menu").open_menu(1)
H.truthy(popup.is_open(), "menu should reopen before the transient notify closes")
H.eq(#state.menu_stack, 1, "reopened menu should contain the root popup")

vim.api.nvim_exec_autocmds("WinResized", { modeline = false })
H.flush()

H.truthy(popup.is_open(), "unrelated WinResized should not close a newly opened menu")
H.eq(#state.menu_stack, 1, "menu stack should stay intact after unrelated WinResized")

vim.wait(120, function()
  return false
end, 5)

H.truthy(popup.is_open(), "notify dismissal should not close a newly opened menu")
H.eq(#state.menu_stack, 1, "menu stack should stay intact after notify dismissal")
H.truthy(state.menu_mode, "menu mode should remain enabled after notify dismissal")

H.finish()
print("ok - tests/integration/notify_dismiss_regression.lua")
