-- ~/.config/nvim/lua/options.lua

local o = vim.o

-- Appearance
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 8
o.wrap = false
o.termguicolors = true
o.laststatus = 3 -- one global statusline, not one per split

-- Indentation. Overridden per filetype below.
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.smartindent = true

-- Searching
o.ignorecase = true
o.smartcase = true
o.inccommand = "split" -- live preview of :s/foo/bar

-- Files and history
o.undofile = true -- persistent undo across sessions
o.swapfile = false
o.updatetime = 250
o.timeoutlen = 400
o.confirm = true -- prompt instead of failing on unsaved changes

-- Insert-mode deletion. The default is "indent,eol,start", and the "start" in
-- there is why Option+Backspace and Command+Backspace feel unreliable: from
-- :help 'backspace', "CTRL-W and CTRL-U stop once at the start of insert".
--
-- So the same keypress does two different things depending on history. Enter
-- insert and press Command+Backspace and the line clears; type three
-- characters first and it removes only those three, because that is where
-- insert began. Pressing again continues past the boundary.
--
-- "nostop" is documented as "like start, except CTRL-W and CTRL-U do not stop
-- at the start of insert", which is the macOS behaviour those keys are mapped
-- to imitate.
o.backspace = "indent,eol,nostop"

-- Splits open where you'd expect
o.splitright = true
o.splitbelow = true

o.mouse = "a"
o.clipboard = "unnamedplus" -- share yanks with the macOS clipboard

-- Native insert-mode completion (Neovim 0.12). This replaces nvim-cmp for
-- most purposes. If you later want snippets and multiple sources ranked
-- together, add blink.cmp and set o.autocomplete = false.
o.completeopt = "menu,menuone,noselect,popup,fuzzy"
o.autocomplete = true

-- Which sources automatic completion scans. The default is ".,w,b,u,t":
-- words in the current buffer, other windows, loaded and unloaded buffers,
-- and tags. All of those are text you have already typed somewhere, which is
-- why library symbols never appeared: RAYWHITE isn't in any open buffer.
--
-- "o" adds the 'omnifunc' source, which on an LSP buffer is
-- v:lua.vim.lsp.omnifunc. That is the same thing <C-x><C-o> calls; without
-- this flag automatic completion never consults it.
--
-- No per-source limits here on purpose. Appending "^N" to a flag caps that
-- source at N matches, which makes the list tidier, but it also hides
-- candidates while you are still typing a name you don't know yet. Noise is
-- the better trade while learning a library.
o.complete = ".,o,w,b,u,t"

-- Two-space languages
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
    "yaml",
    "html",
    "css",
    "lua",
  },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
  end,
})

-- C indentation is handled by cindent, whose defaults disagree with
-- ~/.clang-format about broken argument lists. Without this, typing indents
-- arguments by 4 and then clang-format moves them to 2 when you save.
--
--   (1s  indent continuation lines inside unclosed parens by one shiftwidth,
--        rather than cindent's default of two
--   m1   line a closing paren that starts a line up with the line holding
--        the matching open paren
-- Also drop the comment-continuation flags. Neovim's default formatoptions is
-- "tcqj", but $VIMRUNTIME/ftplugin/c.vim line 24 does `setlocal fo-=t fo+=croql`
-- for C and C++, and it is the r and o in there that keep extending a comment:
--
--   r  carry the comment leader on to the next line when you press Enter
--   o  carry it when you open a line with o or O
--
-- Because the ftplugin sets this per buffer, a global `set formatoptions-=ro`
-- gets overwritten the moment a .c file loads. It has to be a FileType autocmd,
-- and it has to run after the ftplugin, which it does: Neovim registers the
-- ftplugin autocmd during startup, before init.lua is read.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.bo.cinoptions = "(1s,m1"
    vim.bo.formatoptions = vim.bo.formatoptions:gsub("[ro]", "")
  end,
})

-- Go uses real tabs
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

-- Briefly highlight yanked text, so you can see what you grabbed
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Reload buffers changed on disk. Needed so files that Claude Code edits
-- from its own pane update under you instead of triggering a conflict.
o.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave", "CursorHold" }, {
  callback = function()
    if vim.bo.buftype == "" and vim.fn.mode() ~= "c" then
      vim.cmd.checktime()
    end
  end,
})

-- Remote plugin providers. Nothing in this config uses them.
-- If you later add molten-nvim for inline plots, delete the python3 line
-- and install pynvim into a dedicated venv.
vim.g.python3_host_prog = vim.fn.expand("~/.venvs/neovim/bin/python")
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
