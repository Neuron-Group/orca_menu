local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local config = require("orca_menu.config")
local layout = require("orca_menu.layout")
local state = require("orca_menu.state")

local normalized = config.normalize({
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        { label = "Sa&ve", key = "j", command = "write" },
        { label = "-" },
        { label = "Sub&tools", items = { { label = "&Nested" } } },
      },
    },
  },
})

H.eq(normalized.menus[1].label, "File", "top label should be normalized")
H.eq(normalized.menus[1].accelerator, "f", "top accelerator should be parsed")
H.eq(normalized.menus[1].key, "f", "explicit non-reserved top key should be kept")
H.eq(normalized.menus[1].items[1].label, "Save", "item label should be normalized")
H.eq(normalized.menus[1].items[1].accelerator, "v", "item accelerator should be parsed")
H.eq(normalized.menus[1].items[1].key, nil, "reserved navigation keys should be filtered")
H.eq(normalized.menus[1].items[2].kind, "separator", "separator should be normalized")
H.eq(normalized.menus[1].items[3].kind, "submenu", "submenu should be detected")
H.eq(normalized.menus[1].items[3].items[1].label, "Nested", "nested submenu item should be normalized")

local resolved = config.resolve({
  topbar = { hint_format = "{label}({hint})" },
  menus = {
    { label = "&File", items = {} },
  },
  lsp_overrides = {
    leanls = {
      topbar = { hint_format = "{hint}->{label}" },
      menus = {
        { label = "&Lean", key = "y", items = {} },
      },
    },
  },
}, { "leanls" })

H.eq(#resolved.menus, 1, "override should replace menus list")
H.eq(resolved.menus[1].label, "Lean", "override menus should win")
H.eq(resolved.topbar.hint_format, "{hint}->{label}", "non-menu fields should deep-merge")

state.config = config.normalize({
  topbar = {
    hint_format = "{hint}->{label}",
  },
  menus = {
    { label = "&File", key = "<C-x>", items = {} },
  },
})

H.eq(layout.display_key_hint("<C-x>"), "Ctrl+x", "modifier key hint should be formatted")
H.eq(layout.display_key_hint("<Down>"), "↓", "named key hint should be formatted")
H.eq(layout.top_bar_display_label(state.config.menus[1], 1), "Ctrl+x->File", "topbar hint format should be applied")

local line = layout.format_item_line({ kind = "submenu", label = "Inspect", key = "<Tab>" }, 24, 3, 1)
H.truthy(line.text:find("Tab", 1, true), "formatted line should include right-side key hint")
H.truthy(line.text:find("›", 1, true), "formatted line should include submenu arrow")

print("ok - tests/unit/config_layout.lua")

