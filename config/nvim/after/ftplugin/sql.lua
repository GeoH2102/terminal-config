-- ~/.config/nvim/after/ftplugin/sql.lua
--
--   <leader>s   send to the sql pane: the selection in visual mode, the
--               paragraph under the cursor in normal mode
--
-- The sql pane is the psql that `dev sql` opens in Rex (bin/rex-dev-layout).

-- Completion comes from the Postgres language server (lua/lsp.lua), and
-- automatic completion reads it through 'omnifunc'. The SQL ftplugin that ships
-- with Neovim sets its own, which needs the dbext plugin, and Neovim's LSP only
-- fills in an empty one.
vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"

local function send(lines)
  local session = vim.env.REX_SESSION
  if not session then
    vim.notify("No sql pane: run `dev sql` inside Rex", vim.log.levels.WARN)
    return
  end

  local text = vim.trim(table.concat(lines, "\n"))
  if text == "" then
    return
  end
  -- psql waits for more input until it sees a semicolon. Backslash commands
  -- such as \dt need none, and take a trailing one as an argument.
  if not text:match(";$") and not text:match("[^\n]*$"):match("^%s*\\") then
    text = text .. ";"
  end

  -- A bracketed paste keeps the indentation and makes the statement one entry
  -- in psql's history.
  local paste = "\27[200~" .. text .. "\27[201~"
  local result = vim.system({ "rex", "send", "-s", session, "-b", "sql", paste }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("No sql pane in this session: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN)
    return
  end
  vim.system({ "rex", "send-key", "-s", session, "-b", "sql", "enter" })
end

vim.keymap.set("x", "<leader>s", function()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  send(lines)
end, { buffer = true, desc = "Send selection to the sql pane" })

vim.keymap.set("n", "<leader>s", function()
  local first = vim.fn.search([[^\s*$]], "bnW") + 1
  local last = vim.fn.search([[^\s*$]], "nW")
  last = last == 0 and vim.fn.line("$") or last - 1
  send(vim.api.nvim_buf_get_lines(0, first - 1, last, false))
end, { buffer = true, desc = "Send paragraph to the sql pane" })
