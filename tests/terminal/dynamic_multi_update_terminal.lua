local outfile = vim.env.ORCA_TERMINAL_RESULT
local timeout_ms = tonumber(vim.env.ORCA_TERMINAL_TIMEOUT_MS or "3000")

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
    { label = "Step &One", key = "1", action = function() end },
  },
})

local phase = "wait_labels"
local finished = false
local start = vim.loop.hrtime()

local function write_result(status, extra)
  if finished then
    return
  end
  finished = true
  local result = vim.tbl_extend("force", {
    status = status,
    phase = phase,
    menu_count = #(state.config.menus or {}),
    active_top = state.active_top,
    popup_open = popup.is_open() and true or false,
    stack_label = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
      and state.menu_stack[1].items[1].label or nil,
    second_label = state.config.menus[2] and state.config.menus[2].label or nil,
    second_label_col = state.label_positions[2],
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

  if phase == "wait_labels" then
    if state.label_positions[2] then
      popup.open_top(2)
      phase = "update_one"
      return
    end
  elseif phase == "update_one" then
    if not popup.is_open() then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out opening runtime menu before multiple updates")
      end
      return
    end
    orca.update_menu("tools", {
      label = "&Tools",
      key = "t",
      items = {
        { label = "Step &Two", key = "2", action = function() end },
      },
    })
    phase = "update_two"
    return
  elseif phase == "update_two" then
    local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
    if not popup.is_open() or state.active_top ~= 2 or not first_item or first_item.label ~= "Step Two" then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out waiting for first runtime update to settle")
      end
      return
    end
    orca.update_menu("tools", {
      label = "&Tools",
      key = "t",
      items = {
        { label = "Step &Three", key = "3", action = function() end },
      },
    })
    phase = "verify_final"
    return
  elseif phase == "verify_final" then
    local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
    if not popup.is_open() then
      timer:stop()
      timer:close()
      fail("expected popup to remain open after multiple runtime updates")
      return
    end
    if state.active_top ~= 2 then
      timer:stop()
      timer:close()
      fail("expected active_top to remain on runtime menu after multiple updates")
      return
    end
    if not first_item or first_item.label ~= "Step Three" then
      timer:stop()
      timer:close()
      fail("expected latest runtime update to win after multiple updates")
      return
    end

    timer:stop()
    timer:close()
    write_result("ok")
    return
  end

  local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
  if elapsed_ms >= timeout_ms then
    timer:stop()
    timer:close()
    fail("timed out waiting for multi-update scenario")
  end
end))
