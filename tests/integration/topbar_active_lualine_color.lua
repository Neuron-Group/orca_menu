local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

vim.api.nvim_set_hl(0, "OrcaMenuTopbarActiveIT", {
  fg = 0x123456,
  bg = 0x654321,
  bold = true,
})

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
    topbar_active = "OrcaMenuTopbarActiveIT",
    topbar_active_preserve_bg = false,
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
local layout = require("orca_menu.layout")
local state = require("orca_menu.state")
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
local active_hl = vim.api.nvim_get_hl(0, { name = "OrcaMenuTopbarActiveIT", link = false })

H.eq(tools_component.color(), nil, "inactive top menu should not override lualine colors before popup opens")

popup.enter_menu_mode(1)
H.falsy(popup.is_open(), "entering menu mode alone should not open popup")
H.eq(tools_component.color(), nil, "top menu should not highlight until its popup is actually open")

orca.open_menu(1)
H.truthy(popup.is_open(), "opening a top menu should show popup")
H.eq(tools_component.color().fg, string.format("#%06x", active_hl.fg), "active top menu should expose the configured active foreground to lualine")
H.eq(tools_component.color().bg, string.format("#%06x", active_hl.bg), "active top menu should reuse the configured background when requested")
H.eq(tools_component.color().gui, "bold", "active top menu should preserve gui attributes")
H.eq(view_component.color(), nil, "inactive sibling top menu should keep lualine colors")

H.render_statusline()
layout.refresh_label_positions()
local popup_width = layout.submenu_width(state.config.menus[1].items)
local component = state.component_positions[1]
H.eq(
  state.anchor.col,
  H.expected_popup_anchor(component, popup_width, state.config.submenu.border),
  "first popup open should already align to lualine's highlighted component and host geometry"
)

popup.close_all()
H.eq(tools_component.color(), nil, "closing popup should clear active top menu color override")

H.finish()
print("ok - tests/integration/topbar_active_lualine_color.lua")
