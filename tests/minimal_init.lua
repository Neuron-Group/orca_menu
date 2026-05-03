vim.opt.loadplugins = false
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
if vim.env.ORCA_TEST_EXTRA_RTP and vim.env.ORCA_TEST_EXTRA_RTP ~= "" then
  vim.opt.runtimepath:prepend(vim.env.ORCA_TEST_EXTRA_RTP)
end
vim.opt.runtimepath:prepend(vim.fn.getcwd())

package.preload.hydra = package.preload.hydra or function()
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
      activate = function()
        hydra:activate()
      end,
    }

    function hydra:enter()
      if self.spec.config and self.spec.config.on_enter then
        self.spec.config.on_enter()
      end
    end

    function hydra:activate()
      self:enter()
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
