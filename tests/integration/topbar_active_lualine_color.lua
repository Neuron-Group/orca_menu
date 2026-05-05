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
    topbar_active = "Special",
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
      label = "&View",
      key = "v",
      items = {
        { label = "&Tree", key = "t", action = function() end },
      },
    },
  },
})

local orca = require("orca_menu")
local popup = require("orca_menu.popup")
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
H.eq(#orca_components, 3, "orca should register anchor plus one component per top menu")

local tools_component = orca_components[2]
local view_component = orca_components[3]
local special_hl = vim.api.nvim_get_hl(0, { name = "Special", link = false })

H.eq(tools_component.color(), nil, "inactive top menu should not override lualine colors before popup opens")

orca.open_menu(1)
H.truthy(popup.is_open(), "opening a top menu should show popup")
H.eq(tools_component.color().fg, string.format("#%06x", special_hl.fg), "active top menu should expose the configured active foreground to lualine")
H.eq(tools_component.color().bg, nil, "active top menu should leave background unset so lualine keeps its section background")
H.eq(view_component.color(), nil, "inactive sibling top menu should keep lualine colors")

popup.close_all()
H.eq(tools_component.color(), nil, "closing popup should clear active top menu color override")

H.finish()
print("ok - tests/integration/topbar_active_lualine_color.lua")
