local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

local original_get_clients = vim.lsp.get_clients
local active_clients = {}

vim.lsp.get_clients = function(opts)
  if opts and opts.bufnr and opts.bufnr ~= vim.api.nvim_get_current_buf() then
    return {}
  end
  return vim.deepcopy(active_clients)
end

require("orca_menu").setup({
  enable_mouse = false,
  keys = {
    open = "<F13>",
    next = { "l" },
    prev = { "h" },
    down = { "j" },
    up = { "k" },
    select = { "<CR>" },
    back = { "<Esc>" },
    close = { "q" },
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
  lsp_overrides = {
    leanls = {
      menus = {
        {
          label = "&Lean",
          key = "y",
          items = {
            { label = "&Goals", key = "g", action = function() end },
          },
        },
      },
    },
  },
})

local hydra_mode = require("orca_menu.hydra_mode")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

local hydra = hydra_mode.setup()
H.truthy(hydra:press("f"), "base hydra key should exist before LSP attach")
H.truthy(popup.is_open(), "base hydra key should open the base menu")
popup.close_all()

active_clients = {
  { name = "leanls" },
}
vim.api.nvim_exec_autocmds("LspAttach", { group = "OrcaMenu", buffer = 0, data = { client_id = 1 } })

H.eq(state.config.menus[1].key, "y", "LSP attach should activate the Lean override menu")

hydra = hydra_mode.setup()
H.truthy(hydra:press("y"), "hydra should rebuild to include Lean override top key")
H.truthy(popup.is_open(), "Lean override hydra key should open its popup")
H.eq(state.active_top, 1, "Lean override hydra key should target the active override menu")

vim.lsp.get_clients = original_get_clients
H.finish()
print("ok - tests/integration/hydra_lsp_override_refresh.lua")
