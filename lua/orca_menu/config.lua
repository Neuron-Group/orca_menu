local M = {}

local defaults = {
  enable_mouse = true,
  mode = "lualine",
  lualine = {
    spacing = " ",
    section = "y",
  },
  topbar = {
    hint_format = "{label}({hint})",
  },
  keys = {
    open = "<M-m>",
    next = { "l", "<Right>" },
    prev = { "h", "<Left>" },
    down = { "j", "<Down>" },
    up = { "k", "<Up>" },
    select = { "<CR>" },
    back = { "<BS>", "<Esc>" },
    close = { "q" },
  },
  submenu = {
    border = "rounded",
    min_width = 18,
    scroll_indicator_up = "↑",
    scroll_indicator_down = "↓",
  },
  highlights = {
    menu = "NormalFloat",
    menu_sel = "OrcaMenuSelected",
    accelerator = "OrcaMenuHint",
    checked = "OrcaMenuChecked",
    disabled = "OrcaMenuDisabled",
  },
  menus = {
    { label = "&File", items = {} },
  },
}

local reserved_custom_keys = {
  h = true,
  j = true,
  k = true,
  l = true,
  ["<Left>"] = true,
  ["<Right>"] = true,
  ["<Up>"] = true,
  ["<Down>"] = true,
  ["<CR>"] = true,
  ["<Esc>"] = true,
}

local function deep_extend(...)
  return vim.tbl_deep_extend("force", ...)
end

local function merge_with_menu_replace(base, override)
  local merged = deep_extend({}, base or {})
  for key, value in pairs(override or {}) do
    if key == "menus" then
      merged.menus = vim.deepcopy(value)
    elseif type(value) == "table" and type(merged[key]) == "table" then
      merged[key] = merge_with_menu_replace(merged[key], value)
    else
      merged[key] = vim.deepcopy(value)
    end
  end
  return merged
end

local function parse_label(text)
  local accelerator_index
  local clean = {}
  local out_index = 0
  local i = 1
  while i <= #text do
    local char = text:sub(i, i)
    if char == "&" and i < #text then
      i = i + 1
      char = text:sub(i, i)
      if not accelerator_index then
        accelerator_index = out_index + 1
      end
    end
    table.insert(clean, char)
    out_index = out_index + 1
    i = i + 1
  end
  return table.concat(clean), accelerator_index
end

local function normalize_item(item)
  if item.label == "-" then
    return { kind = "separator", label = string.rep("─", 12), raw_label = "-" }
  end

  local label, accel = parse_label(item.label)
  local normalized = vim.deepcopy(item)
  normalized.kind = item.items and "submenu" or "action"
  normalized.raw_label = item.label
  normalized.label = label
  normalized.accelerator_index = accel
  normalized.accelerator = accel and label:sub(accel, accel):lower() or nil
  normalized.key = type(item.key) == "string" and not reserved_custom_keys[item.key] and item.key or nil
  normalized.items = item.items and vim.tbl_map(normalize_item, item.items) or nil
  return normalized
end

function M.normalize(user_config)
  local merged = deep_extend({}, defaults, user_config or {})
  merged.menus = vim.tbl_map(function(menu)
    local normalized = normalize_item(menu)
    normalized.kind = "top"
    normalized.key = type(menu.key) == "string" and not reserved_custom_keys[menu.key] and menu.key or nil
    return normalized
  end, merged.menus or {})
  return merged
end

function M.resolve(user_config, client_names)
  local base = vim.deepcopy(user_config or {})
  local overrides = base.lsp_overrides or {}
  base.lsp_overrides = nil

  local merged = vim.deepcopy(base)
  for _, client_name in ipairs(client_names or {}) do
    if type(overrides[client_name]) == "table" then
      merged = merge_with_menu_replace(merged, overrides[client_name])
    end
  end

  return M.normalize(merged)
end

return M
