-- ~/.config/nvim/lua/autopairs.lua
--
-- Hand-rolled bracket pairing. Small enough to read in one sitting, which is
-- the point: nvim-autopairs and mini.pairs both have conditional skip rules
-- that you'd end up fighting. The rule here is deliberately blunt.
--
-- 1. Typing an opening bracket inserts both halves and puts you in between.
-- 2. Typing a closing bracket when that same character is directly to the
--    right moves over it. ALWAYS. There is no "did the plugin insert this"
--    bookkeeping, so the behaviour never depends on history.
-- 3. Backspace between an empty pair deletes both halves.

-- Opening character -> its closing character.
local PAIRS = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

-- Quotes are their own closing character, so they need separate handling.
local QUOTES = { '"', "'", "`" }

-- The character immediately to the right of the cursor, or "" at end of line.
-- nvim_win_get_cursor returns a 0-indexed byte column, and in insert mode that
-- equals the number of bytes before the cursor. So the byte at col + 1 (Lua
-- strings are 1-indexed) is the one you're sitting in front of.
local function char_after()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return line:sub(col + 1, col + 1)
end

local function char_before()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return line:sub(col, col)
end

-- expr mappings return a string of keys for Neovim to press. With expr = true,
-- replace_keycodes defaults to true, so "<Left>" is understood as the key
-- rather than five literal characters.
local function map(lhs, fn)
  vim.keymap.set("i", lhs, fn, { expr = true, silent = true, desc = "autopairs " .. lhs })
end

for open, close in pairs(PAIRS) do
  -- Open: always insert both halves. Unconditional, so the result never
  -- depends on what is to the right. If you later want to stop it pairing
  -- when you're typing directly in front of a word, add:
  --   if char_after():match("[%w_]") then return open end
  map(open, function()
    return open .. close .. "<Left>"
  end)

  -- Close: write over the existing character if it matches, otherwise type it.
  map(close, function()
    if char_after() == close then
      return "<Right>"
    end
    return close
  end)
end

for _, q in ipairs(QUOTES) do
  map(q, function()
    -- Same write-over rule as brackets.
    if char_after() == q then
      return "<Right>"
    end
    -- Don't pair after a word character, so apostrophes in prose and in
    -- comments ("don't", "it's") stay single. Also stops C char literals
    -- turning into a mess when you type x'.
    if char_before():match("[%w_]") then
      return q
    end
    return q .. q .. "<Left>"
  end)
end

-- Backspace: delete both halves of an empty pair in one press.
vim.keymap.set("i", "<BS>", function()
  local before, after = char_before(), char_after()
  if PAIRS[before] == after and after ~= "" then
    return "<BS><Del>"
  end
  for _, q in ipairs(QUOTES) do
    if before == q and after == q then
      return "<BS><Del>"
    end
  end
  return "<BS>"
end, { expr = true, silent = true, desc = "autopairs backspace" })

-- Enter between an empty pair opens an indented blank line and pushes the
-- closing bracket down:
--
--   void f(void) {|}      ->   void f(void) {
--                                |
--                              }
--
-- <CR><Esc>O is the whole trick. <CR> splits the line, leaving the closing
-- bracket at the start of the new one. O then opens a line ABOVE that and
-- enters insert mode, and because O is a normal-mode command it runs the
-- filetype's indent logic. C uses cindent, Lua uses GetLuaIndent(); neither
-- needs anything from this file.
vim.keymap.set("i", "<CR>", function()
  -- Let the completion menu have the key. Mapping <CR> is the usual way to
  -- break completion, so this guard comes first.
  if vim.fn.pumvisible() == 1 then
    return "<CR>"
  end
  local before, after = char_before(), char_after()
  if PAIRS[before] == after and after ~= "" then
    return "<CR><Esc>O"
  end
  return "<CR>"
end, { expr = true, silent = true, desc = "autopairs newline inside pair" })
