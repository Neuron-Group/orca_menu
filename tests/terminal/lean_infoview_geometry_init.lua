vim.opt.loadplugins = true
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:prepend(vim.env.ORCA_LEAN_NVIM)
vim.opt.runtimepath:append(vim.env.ORCA_LEAN_NVIM .. "/packpath/*")
vim.opt.runtimepath:append(vim.env.ORCA_LUALINE)
