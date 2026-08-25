local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

require("orca_menu").setup({
  enable_mouse = true,
  lualine = {
    section = "y",
    spacing = " ",
  },
  topbar = {
    hint_format = "{hint}->{label}",
  },
  highlights = {
    disabled = "Comment",
    topbar_disabled = "Comment",
  },
  menus = {
    {
      label = "&Tools",
      key = "t",
      items = {
        { label = "&Shell", key = "s", action = function() end },
      },
    },
    {
      label = "&LSP",
      key = "p",
      enabled = false,
      items = {
        { label = "&Rename", key = "r", action = function() end },
      },
    },
    {
      label = "&View",
      key = "v",
      items = {
        { label = "&Tree", key = "t", action = function() end },
      },
    },
  },
})

local lualine = require("lualine")
local config = lualine.get_config()
local section = config.sections.lualine_y
local orca_components = {}

H.truthy(section, "lualine_y section should be configured")
for _, component in ipairs(section) do
  if type(component) == "table" and component.orca_menu_component == true then
    table.insert(orca_components, component)
  end
end
H.eq(#orca_components, 4, "orca should register anchor plus one component per top menu")

local disabled_component = orca_components[3]
H.truthy(type(disabled_component) == "table", "disabled top menu component should be a lualine table component")
H.truthy(type(disabled_component[1]) == "function", "disabled top menu component should expose a render callback")
H.truthy(type(disabled_component.color) == "function", "disabled top menu component should expose a color callback")

local disabled_text = disabled_component[1]()
local disabled_color = disabled_component.color()
local comment_hl = vim.api.nvim_get_hl(0, { name = "Comment", link = false })

H.eq(disabled_text, "p->LSP", "disabled top menu should hand lualine the unpadded label")
H.eq(disabled_component.padding.left, 1, "lualine should own disabled top-menu left padding")
H.eq(disabled_component.padding.right, 1, "lualine should own disabled top-menu right padding")
H.eq(disabled_color.fg, string.format("#%06x", comment_hl.fg), "disabled top menu should hand lualine the configured foreground color")
H.eq(disabled_color.bg, nil, "disabled top menu color should leave background unset so lualine keeps its own section background")

local enabled_component = orca_components[2]
H.eq(enabled_component.color(), nil, "enabled top menu should not override lualine section colors")

H.finish()
print("ok - tests/integration/topbar_disabled_lualine_color.lua")
