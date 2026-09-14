-- ~/.config/nvim/lua/plugins/git.lua

return {
  -- Gutter signs, inline blame, hunk staging -------------------------------
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = true,
      current_line_blame_opts = { delay = 400, virt_text_pos = "eol" },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Note: nav_hunk() rather than the older next_hunk()/prev_hunk(),
        -- which were removed in gitsigns 1.0.
        map("n", "]h", function()
          gs.nav_hunk("next")
        end, "Next hunk")
        map("n", "[h", function()
          gs.nav_hunk("prev")
        end, "Previous hunk")

        map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        map("v", "<leader>hs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selected lines")
        map("v", "<leader>hr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selected lines")
        map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hd", gs.diffthis, "Diff against index")
        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end, "Blame line")
      end,
    },
  },

  -- The VSCode-style side-by-side diff and merge conflict resolver ----------
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff working tree" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
    opts = {},
  },

  -- Everything else. Requires `brew install lazygit`.
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitCurrentFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },
}
