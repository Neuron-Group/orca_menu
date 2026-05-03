local outfile = vim.env.ORCA_TERMINAL_RESULT
local open_key = vim.env.ORCA_TERMINAL_OPEN_KEY or "<F12>"
local start_mode = vim.env.ORCA_TERMINAL_START_MODE or "insert"
local timeout_ms = tonumber(vim.env.ORCA_TERMINAL_TIMEOUT_MS or "2000")

if not outfile or outfile == "" then
  error("ORCA_TERMINAL_RESULT is required")
end

vim.g.mapleader = " "

require("orca_menu").setup({
  enable_mouse = false,
  keys = {
    open = open_key,
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

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
vim.cmd("normal! gg0")

if start_mode == "insert" then
  vim.cmd("startinsert")
elseif start_mode == "visual" then
  vim.cmd("normal! gg0v$")
else
  error("unsupported ORCA_TERMINAL_START_MODE: " .. start_mode)
end

local finished = false
local start = vim.loop.hrtime()

local function write_result(status)
  if finished then
    return
  end

  finished = true
  local result = {
    status = status,
    start_mode = start_mode,
    open_key = open_key,
    mode = vim.fn.mode(),
    menu_mode = state.menu_mode and true or false,
    popup_open = popup.is_open() and true or false,
  }

  vim.fn.writefile({ vim.json.encode(result) }, outfile)
  vim.cmd("qa!")
end

local timer = vim.loop.new_timer()
timer:start(20, 20, vim.schedule_wrap(function()
  if finished then
    return
  end

  if vim.fn.mode() == "n" and state.menu_mode and not popup.is_open() then
    timer:stop()
    timer:close()
    write_result("ok")
    return
  end

  local elapsed_ms = (vim.loop.hrtime() - start) / 1000000
  if elapsed_ms >= timeout_ms then
    timer:stop()
    timer:close()
    write_result("timeout")
  end
end))
