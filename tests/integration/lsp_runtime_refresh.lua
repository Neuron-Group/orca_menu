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
          key = "l",
          items = {
            { label = "&Goals", key = "g", action = function() end },
          },
        },
      },
    },
  },
})

local orca = require("orca_menu")
local popup = require("orca_menu.popup")
local state = require("orca_menu.state")

H.eq(#state.config.menus, 1, "setup without attached LSP clients should keep base menus")
H.eq(state.config.menus[1].label, "File", "setup should normalize the base menu")

orca.register_menu("tools", {
  label = "&Tools",
  key = "t",
  items = {
    { label = "&Build", key = "b", action = function() end },
  },
})

H.eq(#state.config.menus, 2, "runtime registration should append to the base config")
H.eq(state.config.menus[2].label, "Tools", "runtime menu should be available before LSP attach")

active_clients = {
  { name = "leanls" },
}
vim.api.nvim_exec_autocmds("LspAttach", { group = "OrcaMenu", buffer = 0, data = { client_id = 1 } })

H.eq(#state.config.menus, 2, "LSP attach should replace base menus while preserving runtime menus")
H.eq(state.config.menus[1].label, "Lean", "LSP override should replace the base menu list")
H.eq(state.config.menus[2].label, "Tools", "runtime menus should still append after an LSP override refresh")
H.truthy(popup.activate_top_key("l"), "LSP override menu key should activate after attach")
H.eq(state.active_top, 1, "LSP override menu should become the active top menu")
popup.close_all()
H.truthy(popup.activate_top_key("t"), "runtime menu key should still activate after LSP attach")
H.eq(state.active_top, 2, "runtime menu should stay addressable after the LSP override refresh")
popup.close_all()

H.truthy(orca.unregister_menu("tools"), "runtime menus should remain removable after an LSP override refresh")
H.eq(#state.config.menus, 1, "unregistering under an LSP override should keep the override menu intact")
H.eq(state.config.menus[1].label, "Lean", "unregister should not disturb the active LSP override menu")

active_clients = {}
vim.api.nvim_exec_autocmds("LspDetach", { group = "OrcaMenu", buffer = 0, data = { client_id = 1 } })
H.flush()

H.eq(#state.config.menus, 1, "LSP detach should restore the base menu list once overrides disappear")
H.eq(state.config.menus[1].label, "File", "LSP detach should return to the base menu config")
H.falsy(popup.activate_top_key("l"), "override menu key should stop working after detach")
H.truthy(popup.activate_top_key("f"), "base menu key should work again after detach")

vim.lsp.get_clients = original_get_clients
H.finish()
print("ok - tests/integration/lsp_runtime_refresh.lua")
