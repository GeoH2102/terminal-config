-- ~/.config/nvim/lua/plugins/ai.lua
--
-- Anthropic officially supports two IDE families for Claude Code: VS Code
-- (plus forks) and JetBrains. Neovim isn't one of them. This plugin
-- implements the same WebSocket protocol the official extensions use, so
-- the CLI auto-detects your running Neovim instance and gains the same
-- capabilities: opening files, native diffs, selection context, diagnostics.
--
-- It works by writing a lock file to ~/.claude/ide/<port>.lock that the CLI
-- discovers. Which means: start Neovim first, then start Claude in the other
-- pane. If you get them the wrong way round, run /ide inside Claude to
-- reconnect.

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode",
      "ClaudeCodeSend",
      "ClaudeCodeAdd",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus",
      "ClaudeCodeDiffAccept",
      "ClaudeCodeDiffDeny",
    },
    keys = {
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>af", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current file to context" },
      { "<leader>at", "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add tree selection to context" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept proposed diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Reject proposed diff" },
      { "<leader>a?", "<cmd>ClaudeCodeStatus<cr>", desc = "Connection status" },
    },
    opts = {
      -- Claude runs in its own tmux pane, not in a Neovim terminal buffer.
      -- The plugin still handles diffs, context and diagnostics; it just
      -- doesn't try to own the terminal.
      --
      -- If you'd rather have Claude in a Neovim split, delete this table and
      -- add { "<leader>ac", "<cmd>ClaudeCode<cr>" } to the keys above.
      terminal = { provider = "none" },
    },
  },

  -- Dependency of claudecode.nvim. Loaded on demand only.
  { "folke/snacks.nvim", lazy = true, opts = {} },
}
