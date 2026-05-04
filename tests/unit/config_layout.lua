local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local function color_luma(color)
  if type(color) ~= "number" then
    return nil
  end

  local red = bit.rshift(color, 16)
  local green = bit.band(bit.rshift(color, 8), 0xFF)
  local blue = bit.band(color, 0xFF)
  return (red * 0.299) + (green * 0.587) + (blue * 0.114)
end

local config = require("orca_menu.config")
local layout = require("orca_menu.layout")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

local ok, err = pcall(config.normalize, {
  menus = {
    { items = {} },
  },
})
H.falsy(ok, "normalize should reject top-level menus without labels")
H.truthy(tostring(err):find("menus%[1%]%.label", 1) ~= nil, "normalize error should mention the missing top-level label")

ok, err = pcall(config.normalize, {
  menus = {
    {
      label = "&Broken",
      items = {
        {},
      },
    },
  },
})
H.falsy(ok, "normalize should reject child items without labels")
H.truthy(tostring(err):find("menus%[1%]%.items%[1%]%.label", 1) ~= nil, "normalize error should mention the missing child label")

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

state.config = config.normalize({
  menus = {
    {
      label = "&View",
      items = {
        {
          label = "Toggle &Line Numbers",
          key = "n",
          checked = function()
            return vim.wo.number
          end,
        },
      },
    },
  },
})

vim.wo.number = true
local checked_line = layout.format_item_line(state.config.menus[1].items[1], 30, 1, 0)
H.truthy(checked_line.text:find("", 1, true), "checked items should render a checkmark")
H.truthy(checked_line.text:find("n", 1, true), "checked items should keep their right-side key hint")
local hint_text = checked_line.text:sub((checked_line.hint_start or 0) + 1, checked_line.hint_end or 0)
H.eq(hint_text, "n", "hint highlight span should still point exactly at the key hint")

vim.wo.number = false
local unchecked_line = layout.format_item_line(state.config.menus[1].items[1], 30, 1, 0)
H.falsy(unchecked_line.text:find("", 1, true), "unchecked items should not render a checkmark")

local enabled_calls = 0
local executable_calls = 0
state.config = config.normalize({
  menus = {
    {
      label = "&View",
      items = {
        {
          label = "&Blocked",
          enabled = function()
            enabled_calls = enabled_calls + 1
            return false
          end,
        },
        {
          label = "&Ready",
          executable = function()
            executable_calls = executable_calls + 1
            return true
          end,
        },
      },
    },
  },
})

H.falsy(layout.item_enabled(state.config.menus[1].items[1]), "enabled callback should be able to disable an item")
H.truthy(layout.item_enabled(state.config.menus[1].items[2]), "executable alias should also enable an item")
H.eq(enabled_calls, 1, "enabled callback should be evaluated dynamically")
H.eq(executable_calls, 1, "executable alias should be evaluated dynamically")

state.config = config.normalize({
  highlights = {
    checked = "WarningMsg",
  },
  menus = {
    {
      label = "&View",
      items = {
        {
          label = "Toggle &Explorer",
          key = "oo",
          checked = true,
        },
      },
    },
  },
})

popup.open_top(1)
local checked_popup_buf = state.menu_stack[1].buf
local checked_popup_line = vim.api.nvim_buf_get_lines(checked_popup_buf, 0, 1, false)[1]
local popup_marks = vim.api.nvim_buf_get_extmarks(checked_popup_buf, state.namespace, 0, -1, { details = true })
local hint_mark
local check_mark

for _, mark in ipairs(popup_marks) do
  local details = mark[4] or {}
  if details.hl_group == "OrcaMenuHint" then
    hint_mark = mark
  elseif details.hl_group == "WarningMsg" then
    check_mark = mark
  end
end

H.truthy(hint_mark, "popup should add a dedicated highlight for key hints")
H.truthy(check_mark, "popup should add a dedicated highlight for checked state")
H.eq(checked_popup_line:sub(hint_mark[3] + 1, (hint_mark[4] or {}).end_col), "oo", "multi-key hint highlight should cover the full rendered hint")
H.eq(checked_popup_line:sub(check_mark[3] + 1, (check_mark[4] or {}).end_col), "", "checked highlight should cover only the checkmark")
popup.close_all()

state.config = config.normalize({
  highlights = {
    disabled = "Comment",
  },
  menus = {
    {
      label = "&View",
      items = {
        {
          label = "&Blocked",
          key = "b",
          enabled = false,
        },
        {
          label = "&Ready",
          key = "r",
        },
      },
    },
  },
})

popup.open_top(1)
H.eq(state.menu_stack[1].selected, 2, "initial selection should skip disabled rows")
local disabled_popup_buf = state.menu_stack[1].buf
local disabled_marks = vim.api.nvim_buf_get_extmarks(disabled_popup_buf, state.namespace, 0, -1, { details = true })
local disabled_row_mark
local ready_row_mark

for _, mark in ipairs(disabled_marks) do
  local details = mark[4] or {}
  if details.hl_group == "Comment" and mark[2] == 0 then
    disabled_row_mark = mark
  elseif details.hl_group == "OrcaMenuSelected" and mark[2] == 1 then
    ready_row_mark = mark
  end
end

H.truthy(disabled_row_mark, "disabled rows should use the configured disabled highlight")
H.truthy(ready_row_mark, "first enabled row should still be selected")
popup.close_all()

state.config = config.normalize({
  submenu = {
    border = "rounded",
  },
  menus = {
    { label = "&File", items = { { label = "&Open" }, { label = "&Save" } } },
  },
})
H.render_statusline()
local rounded_anchor = layout.resolve_anchor(1, state.config.menus[1].items)

state.config = config.normalize({
  submenu = {
    border = "none",
  },
  menus = {
    {
      label = "&File",
      items = {
        { label = "&Open Recent", items = { { label = "&Project" }, { label = "&Session" } } },
        { label = "&Save" },
      },
    },
  },
})
H.render_statusline()
local none_anchor = layout.resolve_anchor(1, state.config.menus[1].items)

H.eq(none_anchor.row, rounded_anchor.row, 'border = "none" should keep the same popup geometry as bordered popups')

popup.open_top(1)
popup.activate_selected()

H.eq(#state.menu_stack, 2, 'activating a submenu should open a child popup for border = "none"')

local parent_winhl = vim.api.nvim_get_option_value("winhl", { win = state.menu_stack[1].win })
local child_winhl = vim.api.nvim_get_option_value("winhl", { win = state.menu_stack[2].win })
H.truthy(parent_winhl:find("OrcaMenuLevel1", 1, true), 'parent popup should use a level-specific highlight when border = "none"')
H.truthy(child_winhl:find("OrcaMenuLevel2", 1, true), 'child popup should use a different level-specific highlight when border = "none"')
H.truthy(child_winhl:find("FloatBorder:OrcaMenuLevel2", 1, true), 'borderless popup frame should reuse the same tinted highlight as the child menu body')

local parent_hl = vim.api.nvim_get_hl(0, { name = "OrcaMenuLevel1", link = false })
local child_hl = vim.api.nvim_get_hl(0, { name = "OrcaMenuLevel2", link = false })
local parent_sel_hl = vim.api.nvim_get_hl(0, { name = "OrcaMenuSelectedLevel1", link = false })
local child_sel_hl = vim.api.nvim_get_hl(0, { name = "OrcaMenuSelectedLevel2", link = false })
local child_hint_hl = vim.api.nvim_get_hl(0, { name = "OrcaMenuHintLevel2", link = false })
H.truthy(parent_hl.bg ~= nil, "parent popup highlight should define a background")
H.truthy(child_hl.bg ~= nil, "child popup highlight should define a background")
H.truthy(parent_sel_hl.bg ~= nil, "parent selected highlight should define a background")
H.truthy(child_sel_hl.bg ~= nil, "child selected highlight should define a background")
H.truthy(parent_hl.bg ~= child_hl.bg, "child popup background should differ slightly from its parent")
H.truthy(parent_hl.bg ~= parent_sel_hl.bg, "selected parent row should have a deeper background under borderless theme")
H.truthy(child_hl.bg ~= child_sel_hl.bg, "selected child row should have a deeper background under borderless theme")
H.eq(child_hint_hl.bg, nil, "hint highlight should not paint its own background")
if color_luma(parent_hl.bg) >= 128 then
  H.truthy(color_luma(child_hl.bg) < color_luma(parent_hl.bg), "light palettes should darken child popups slightly")
  H.truthy(color_luma(child_sel_hl.bg) < color_luma(child_hl.bg), "light palettes should darken the selected row")
else
  H.truthy(color_luma(child_hl.bg) > color_luma(parent_hl.bg), "dark palettes should lighten child popups slightly")
  H.truthy(color_luma(child_sel_hl.bg) > color_luma(child_hl.bg), "dark palettes should lighten the selected row")
end

popup.close_all()

print("ok - tests/unit/config_layout.lua")
