local outfile = vim.env.ORCA_TERMINAL_RESULT
local timeout_ms = tonumber(vim.env.ORCA_TERMINAL_TIMEOUT_MS or "2500")

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

local phase = "register"
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
    second_label = state.config.menus[2] and state.config.menus[2].label or nil,
    third_label = state.config.menus[3] and state.config.menus[3].label or nil,
    stack_label = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
      and state.menu_stack[1].items[1].label or nil,
    second_label_col = state.label_positions[2],
    third_label_col = state.label_positions[3],
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

  if phase == "register" then
    orca.register_menu("tools", {
      label = "&Tools",
      key = "t",
      items = {
        { label = "Run &One", key = "1", action = function() end },
      },
    })
    phase = "wait_tools"
    return
  elseif phase == "wait_tools" then
    if state.label_positions[2] and state.config.menus[2] and state.config.menus[2].label == "Tools" then
      popup.open_top(2)
      phase = "verify_tools"
      return
    end
  elseif phase == "verify_tools" then
    local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
    if not popup.is_open() or state.active_top ~= 2 then
      timer:stop()
      timer:close()
      fail("expected first runtime menu to open after dynamic registration")
      return
    end
    if not first_item or first_item.label ~= "Run One" then
      timer:stop()
      timer:close()
      fail("expected first runtime popup contents after dynamic registration")
      return
    end

    popup.close_all()
    orca.register_menu("view", {
      label = "&View",
      key = "v",
      items = {
        { label = "&Zoom", key = "z", action = function() end },
      },
    })
    phase = "wait_view"
    return
  elseif phase == "wait_view" then
    if state.label_positions[3] and state.config.menus[3] and state.config.menus[3].label == "View" then
      popup.open_top(3)
      phase = "verify_view"
      return
    end
  elseif phase == "verify_view" then
    local first_item = state.menu_stack[1] and state.menu_stack[1].items and state.menu_stack[1].items[1]
    if not popup.is_open() or state.active_top ~= 3 then
      timer:stop()
      timer:close()
      fail("expected second runtime menu to open after second dynamic registration")
      return
    end
    if not first_item or first_item.label ~= "Zoom" then
      timer:stop()
      timer:close()
      fail("expected second runtime popup contents after dynamic registration")
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
    fail("timed out waiting for dynamic registration scenario")
  end
end))
