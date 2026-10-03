-- ~/.config/nvim/lua/keymaps.lua
--
-- Deliberately short. Neovim 0.11+ already ships most of what you'd
-- otherwise map by hand:
--
--   grn  rename symbol          gra  code action
--   grr  find references        gri  go to implementation
--   grt  go to type definition  gO   document symbols
--   K    hover documentation    <C-s> signature help (insert mode)
--   ]d [d  next/prev diagnostic ]q [q  quickfix list
--   ]b [b  next/prev buffer     v_an v_in  expand/shrink treesitter selection
--
-- Run :help lsp-defaults and :help default-mappings before adding your own.

local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Buffers
--
-- Close the current buffer and keep the window. Plain :bdelete cannot do this:
-- from :help :bdelete, "Any windows for this buffer are closed", and it only
-- spares the window when there is no other listed buffer to switch to. With
-- neo-tree open that is fatal rather than merely annoying: :bd shuts the file
-- window, neo-tree becomes the last one, close_if_last_window closes it too,
-- and Neovim exits with no windows left.
--
-- The built-in workaround is `:bp | bd #`, which works but errors with E516 on
-- the last remaining buffer. This does the same thing and handles that case by
-- opening an empty buffer, and it uses win_findbuf so a file open in two
-- splits moves both rather than leaving one behind.
local function close_buffer(force)
  local target = vim.api.nvim_get_current_buf()

  local others = {}
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= target then
      others[#others + 1] = info.bufnr
    end
  end

  -- Point the windows elsewhere FIRST, so the delete finds none to close.
  for _, win in ipairs(vim.fn.win_findbuf(target)) do
    vim.api.nvim_win_call(win, function()
      if #others > 0 then
        vim.cmd("buffer " .. others[#others]) -- most recent, like :bprevious
      else
        vim.cmd("enew")
      end
    end)
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, target, { force = force or false })
  if not ok then
    -- Unsaved changes, most likely. Put the buffer back so the window is not
    -- left showing something else while the edit is still open.
    vim.api.nvim_set_current_buf(target)
    vim.notify(tostring(err), vim.log.levels.WARN)
  end
end

map("n", "<leader>bd", function()
  close_buffer(false)
end, { desc = "Close buffer, keep window" })

map("n", "<leader>bD", function()
  close_buffer(true)
end, { desc = "Close buffer, discard changes" })

map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write buffer" })

-- Diagnostics
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

-- Keep the cursor centred when jumping around
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Move selected lines up and down
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Paste over a selection without clobbering the unnamed register
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- Escape out of a terminal buffer
map("t", "<C-x>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- macOS deletion shortcuts, in insert mode ----------------------------------
--
-- Two of these have Neovim built-ins already, and the built-ins are worth
-- knowing because they work in zsh and anything else using readline too:
--
--   <C-w>  delete the word before the cursor   (Option + Backspace)
--   <C-u>  delete to the start of the line     (Command + Backspace)
--
-- There is no built-in for either forward direction, hence the two mappings
-- built on i_CTRL-\_CTRL-O below. Plain i_CTRL-O would be the obvious choice,
-- but it has a documented side effect: with the cursor past the end of a line
-- it moves back onto the last character first, so <C-o>D at the end of a line
-- deletes that character instead of doing nothing. CTRL-\ CTRL-O leaves the
-- cursor where it is.
--
-- The F-key numbers come from ~/.config/ghostty/config, which sends CSI 25~
-- and CSI 26~ for the two Command shortcuts. Which F-key those decode to
-- depends on the active terminfo: F13/F14 under xterm-ghostty, F15/F16 under
-- tmux-256color. Both pairs are mapped so the keys work in or out of tmux.
map("i", "<M-BS>", "<C-w>", { desc = "Delete word before cursor" })
map("i", "<M-Del>", "<C-\\><C-o>dw", { desc = "Delete word after cursor" })

for _, key in ipairs({ "<F13>", "<F15>" }) do
  map("i", key, "<C-u>", { desc = "Delete to start of line" })
end
for _, key in ipairs({ "<F14>", "<F16>" }) do
  map("i", key, "<C-\\><C-o>D", { desc = "Delete to end of line" })
end

-- Word movement in insert mode. <Home> and <End> are deliberately absent:
-- Neovim already handles them in insert mode, and ~/.config/ghostty/config
-- sends the Home and End sequences for Command+Left and Command+Right, so
-- those work without a mapping here (and in zsh too).
--
-- <C-\><C-o> rather than <C-o> for the same reason as the deletion mappings:
-- <C-o> pulls the cursor back onto the last character when it sits past the
-- end of a line, so Option+Right at a line end would jump a word too few.
map("i", "<M-Left>", "<C-\\><C-o>b", { desc = "Back a word" })
map("i", "<M-Right>", "<C-\\><C-o>w", { desc = "Forward a word" })
