local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
  },
  menus = {
    {
      label = "&File",
      items = {
        {
          label = "&Open",
          action = function() end,
        },
      },
    },
  },
})

local popup = require("orca_menu.popup")

popup.enter_menu_mode(1)

H.eq(vim.fn.maparg("f", "n", false, true), {}, "top accelerator should not create a dedicated mapping")
H.eq(vim.fn.maparg("fi", "n", false, true), {}, "top accelerator should not create a multi-key mapping")
H.eq(vim.fn.maparg("o", "n", false, true), {}, "item accelerator should not create a dedicated mapping")
H.eq(vim.fn.maparg("op", "n", false, true), {}, "item accelerator should not create a multi-key mapping")

H.falsy(popup.activate_top_key("fi"), "multi-key top accelerator should not activate")
popup.activate_top_key("f")
H.truthy(popup.is_open(), "single-key top accelerator should still activate")
H.falsy(popup.activate_item_key("op"), "multi-key item accelerator should not activate")
H.truthy(popup.activate_item_key("o"), "single-key item accelerator should still activate")

H.finish()
print("ok - tests/integration/accelerator_single_key.lua")
