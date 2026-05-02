local H = dofile(vim.fn.getcwd() .. "/tests/helpers.lua")

package.loaded.hydra = nil
package.preload.hydra = function()
  return function(spec)
    local hydra = { spec = spec }

    function hydra:exit()
      if self.spec.config and self.spec.config.on_exit then
        self.spec.config.on_exit()
      end
    end

    hydra.layer = {
      exit = function()
        hydra:exit()
      end,
    }

    function hydra:enter()
      if self.spec.config and self.spec.config.on_enter then
        self.spec.config.on_enter()
      end
    end

    function hydra:press(key)
      for _, head in ipairs(self.spec.heads or {}) do
        if head[1] == key then
          head[2]()
          if head[3] and head[3].exit then
            self:exit()
          end
          return true
        end
      end
      return false
    end

    return hydra
  end
end

vim.g.orca_hydra_action = 0

require("orca_menu").setup({
  enable_mouse = true,
  keys = {
    open = "<F13>",
    mode_backend = "hydra",
  },
  menus = {
    {
      label = "&File",
      key = "f",
      items = {
        {
          label = "&Tools",
          key = "t",
          items = {
            {
              label = "&Nested",
              key = "n",
              action = function()
                vim.g.orca_hydra_action = vim.g.orca_hydra_action + 1
              end,
            },
          },
        },
        {
          label = "&Open",
          key = "o",
          action = function()
            vim.g.orca_hydra_action = vim.g.orca_hydra_action + 10
          end,
        },
      },
    },
  },
})

local state = require("orca_menu.state")
local popup = require("orca_menu.popup")
local hydra_mode = require("orca_menu.hydra_mode")

H.render_statusline()

local hydra = hydra_mode.setup()
hydra:enter()
H.truthy(hydra_mode.is_active(), "hydra should become active on enter")
H.truthy(state.menu_mode, "hydra enter should enable menu mode")
H.eq(#state.menu_stack, 0, "hydra enter should not open a popup immediately")

popup.activate_top_key("f")
H.truthy(popup.is_open(), "top key should open popup while hydra is active")

popup.activate_item_key("t")
H.eq(#state.menu_stack, 2, "submenu activation should push a child level under hydra")

hydra:press("<Esc>")
H.truthy(hydra_mode.is_active(), "escaping a child submenu should keep hydra active")
H.eq(#state.menu_stack, 1, "escaping a child submenu should only pop one level")

popup.activate_item_key("o")
H.eq(state.pending_action and state.pending_action.label, "Open", "hydra action should defer execution until exit")
H.flush()

H.eq(vim.g.orca_hydra_action, 10, "pending hydra action should execute after hydra exits")
H.falsy(hydra_mode.is_active(), "hydra should be inactive after deferred action exits")
H.eq(state.pending_action, nil, "pending action should be cleared after execution")
H.falsy(state.menu_mode, "deferred action execution should leave menu mode")
H.falsy(popup.is_open(), "deferred action execution should close popups")

hydra:enter()
popup.activate_top_key("f")
hydra:press("q")
H.falsy(hydra_mode.is_active(), "q should exit hydra mode")
H.falsy(state.menu_mode, "q should clear menu mode")

H.finish()
print("ok - tests/integration/hydra_flow.lua")
