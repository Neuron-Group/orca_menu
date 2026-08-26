local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.g.orca_infoview_shadow_hits = 0

vim.keymap.set("n", "<Esc>", function()
  vim.g.orca_infoview_shadow_hits = vim.g.orca_infoview_shadow_hits + 1
end, { buffer = 0, silent = true })

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
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

local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")
local state = require("orca_menu.state")

H.render_statusline()
layout.refresh_label_positions()

local mouse = { screenrow = vim.o.lines - vim.o.cmdheight, screencol = state.label_positions[1] + 1 }
local restore_mouse = H.stub_mouse(mouse)

local function open_by_click()
  _G.orca_menu_click_menu_1()
end

local function open_by_api()
  require("orca_menu").open_menu(1)
end

for _, scenario in ipairs({
  { name = "api", open = open_by_api },
  { name = "click", open = open_by_click },
}) do
  scenario.open()
  H.truthy(popup.is_open(), scenario.name .. " open should show the popup")
  H.eq(vim.g.orca_infoview_shadow_hits, 0, scenario.name .. " open should not trigger the local Esc mapping yet")

  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "xt", false)
  H.flush()

  H.falsy(popup.is_open(), scenario.name .. " open should close on Esc even with a buffer-local shadow mapping")
  H.eq(vim.g.orca_infoview_shadow_hits, 0, scenario.name .. " open should let Orca win over the local Esc mapping")
end

restore_mouse()
H.finish()
print("ok - tests/integration/infoview_local_key_shadow.lua")
