-- ~/.config/nvim/init.lua
--
-- Targets Neovim 0.12+. Check with :version
--
-- Load order matters: leader keys must be set before lazy.nvim loads any
-- plugin, because plugin keymaps are resolved against whatever <leader> is
-- at the moment they're registered.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("options")
require("keymaps")
require("autopairs")

-- Bootstrap lazy.nvim on first launch.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Every file in lua/plugins/ returns a list of plugin specs.
-- Delete a file to remove that whole feature area.
require("lazy").setup({
  spec = { { import = "plugins" } },
  change_detection = { notify = false },
  install = { colorscheme = { "tokyonight", "habamax" } },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "zipPlugin", "tohtml", "tutor" },
    },
  },
  rocks = { enabled = false },
})

-- LSP config must run after lazy.nvim, because it depends on the server
-- definitions that nvim-lspconfig drops into the runtime path.
require("lsp")
