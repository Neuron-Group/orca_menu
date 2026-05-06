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

orca.register_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    { label = "Run &One", key = "1", action = function() end },
  },
})

orca.register_menu("view", {
  label = "&View",
  key = "v",
  items = {
    { label = "&Zoom", key = "z", action = function() end },
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
    stack_depth = #state.menu_stack,
    second_label = state.config.menus[2] and state.config.menus[2].label or nil,
    third_label = state.config.menus[3] and state.config.menus[3].label or nil,
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

  if phase == "wait_labels" then
    if state.label_positions[3] then
      popup.open_top(3)
      phase = "verify_open"
      return
    end
  elseif phase == "verify_open" then
    if not popup.is_open() or state.active_top ~= 3 then
      local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
      if elapsed_ms >= timeout_ms then
        timer:stop()
        timer:close()
        fail("timed out opening View runtime menu before unregister")
      end
      return
    end

    if not orca.unregister_menu("view") then
      timer:stop()
      timer:close()
      fail("expected unregister_menu(view) to succeed")
      return
    end
    phase = "verify_unregister"
    return
  elseif phase == "verify_unregister" then
    if #(state.config.menus or {}) ~= 2 then
      timer:stop()
      timer:close()
      fail("expected one runtime menu removed after unregister")
      return
    end
    if state.config.menus[2].label ~= "Tools" then
      timer:stop()
      timer:close()
      fail("expected Tools to remain as the only runtime menu")
      return
    end
    if state.label_positions[3] then
      timer:stop()
      timer:close()
      fail("expected stale third topbar label position to be cleared")
      return
    end
    if popup.is_open() then
      timer:stop()
      timer:close()
      fail("expected popup to close when the open runtime menu is unregistered")
      return
    end
    if #state.menu_stack ~= 0 then
      timer:stop()
      timer:close()
      fail("expected menu stack to clear when the open runtime menu is unregistered")
      return
    end
    if state.active_top ~= 2 then
      timer:stop()
      timer:close()
      fail("expected active_top to clamp to remaining runtime menu after unregister")
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
    fail("timed out waiting for unregister-open scenario")
  end
end))
