local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local bootstrap = require("orca_menu.bootstrap")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

local toggles = 0
local opened_index
local opened_mouse

bootstrap.install_user_commands({
  toggle = function()
    toggles = toggles + 1
  end,
  open_menu = function(index, use_mouse)
    opened_index = index
    opened_mouse = use_mouse
  end,
})

H.truthy(vim.fn.exists(":OrcaMenu") == 2, "OrcaMenu command should be installed")
H.truthy(vim.fn.exists(":OrcaMenuMouseTrace") == 2, "OrcaMenuMouseTrace command should be installed")

vim.cmd("OrcaMenu")
H.eq(toggles, 1, "OrcaMenu without args should call toggle")

vim.cmd("OrcaMenu 7")
H.eq(opened_index, 7, "OrcaMenu with args should open the requested menu")
H.eq(opened_mouse, false, "OrcaMenu should open without mouse mode")

local original_notify = vim.notify
local notifications = {}
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
end

state.mouse_trace_path = nil
vim.cmd("OrcaMenuMouseTrace off")
H.eq(state.mouse_trace_path, nil, "mouse trace off should clear the path")

local trace_path = vim.fn.getcwd() .. "/.tmp-orca-bootstrap-trace.log"
vim.cmd("OrcaMenuMouseTrace " .. vim.fn.fnameescape(trace_path))
H.eq(state.mouse_trace_path, trace_path, "mouse trace command should store the selected path")
H.truthy(vim.fn.filereadable(trace_path) == 1, "mouse trace command should create the trace file")

vim.notify = original_notify

local refreshes = 0
local augroup = vim.api.nvim_create_augroup("OrcaMenuBootstrapTest", { clear = true })
bootstrap.install_autocmds(augroup, function()
  refreshes = refreshes + 1
end)

vim.api.nvim_exec_autocmds("BufEnter", { group = augroup, buffer = 0 })
H.eq(refreshes, 1, "BufEnter should trigger refresh")

vim.api.nvim_exec_autocmds("LspAttach", { group = augroup, buffer = 0, data = { client_id = 1 } })
H.eq(refreshes, 2, "LspAttach should trigger refresh")

vim.api.nvim_exec_autocmds("LspDetach", { group = augroup, buffer = 0, data = { client_id = 1 } })
H.flush()
H.eq(refreshes, 3, "LspDetach should trigger scheduled refresh")

local original_is_open = popup.is_open
local original_close_all = popup.close_all
local closed = 0

popup.is_open = function()
  return false
end

popup.close_all = function()
  closed = closed + 1
end

state.menu_mode = false
state.menu_stack = {}
vim.api.nvim_exec_autocmds("VimResized", { group = augroup })
H.eq(closed, 0, "VimResized should not close when menu UI is inactive")

state.menu_mode = true
vim.api.nvim_exec_autocmds("VimResized", { group = augroup })
H.eq(closed, 1, "VimResized should close when menu mode is active")

popup.is_open = original_is_open
popup.close_all = original_close_all
state.menu_mode = false
state.menu_stack = {}

print("ok - tests/unit/runtime_bootstrap.lua")
