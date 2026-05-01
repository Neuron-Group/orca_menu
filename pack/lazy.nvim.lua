return {
  {
    "orca_menu",
    dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"),
    dependencies = {
      "anuvyklack/hydra.nvim",
      "nvim-lualine/lualine.nvim",
    },
    config = function()
      require("orca_menu").setup({})
    end,
  },
}
