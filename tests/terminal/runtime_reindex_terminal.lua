local outfile = vim.env.ORCA_TERMINAL_RESULT
local timeout_ms = tonumber(vim.env.ORCA_TERMINAL_TIMEOUT_MS or "2000")

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.g.mapleader = " "

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F12>",
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

local orca = require("orca_menu")
local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local layout = require("orca_menu.layout")

orca.register_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    { label = "&Build", key = "b", action = function() end },
  },
})

orca.register_menu("view", {
  label = "&View",
  key = "v",
  items = {
    { label = "&Zoom", key = "z", action = function() end },
  },
})

orca.unregister_menu("tools")

local finished = false
local start = vim.loop.hrtime()

local function write_result(status, extra)
  if finished then
    return
  end

  finished = true
  local result = vim.tbl_extend("force", {
    status = status,
    menu_count = #(state.config.menus or {}),
    active_top = state.active_top,
    popup_open = popup.is_open() and true or false,
    second_label = state.config.menus[2] and state.config.menus[2].label or nil,
    second_item = state.config.menus[2] and state.config.menus[2].items and state.config.menus[2].items[1]
      and state.config.menus[2].items[1].label or nil,
    label_col = state.label_positions[2],
  }, extra or {})

  vim.fn.writefile({ vim.json.encode(result) }, outfile)
  vim.cmd("qa!")
end

local function fail(message)
  write_result("error", { message = message })
end

local timer = vim.loop.new_timer()
timer:start(80, 80, vim.schedule_wrap(function()
  if finished then
    return
  end

  layout.refresh_label_positions()

  if #(state.config.menus or {}) ~= 2 then
    timer:stop()
    timer:close()
    fail("expected two menus after runtime unregister")
    return
  end

  if not state.config.menus[2] or state.config.menus[2].label ~= "View" then
    timer:stop()
    timer:close()
    fail("expected reindexed runtime menu label")
    return
  end

  if not state.label_positions[2] then
    local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
    if elapsed_ms >= timeout_ms then
      timer:stop()
      timer:close()
      fail("timed out waiting for top label positions")
    end
    return
  end

  popup.open_top(2)

  if not popup.is_open() then
    timer:stop()
    timer:close()
    fail("expected shifted runtime menu to open by index")
    return
  end

  if state.active_top ~= 2 then
    timer:stop()
    timer:close()
    fail("expected shifted runtime menu to become active")
    return
  end

  local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
  if not first_item or first_item.label ~= "Zoom" then
    timer:stop()
    timer:close()
    fail("expected shifted runtime popup to show View items")
    return
  end

  timer:stop()
  timer:close()
  write_result("ok")
end))
