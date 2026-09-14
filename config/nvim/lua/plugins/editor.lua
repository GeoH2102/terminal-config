-- ~/.config/nvim/lua/plugins/editor.lua

return {
  -- Colourscheme -----------------------------------------------------------
  {
    "neanias/everforest-nvim",
    version = false,
    lazy = false,
    priority = 1000,
    config = function()
      require("everforest").setup({
        -- "hard" is the darkest variant. At 0.3 opacity you're looking at
        -- your wallpaper through the text, so start from the darkest base
        -- you can and let the blur lift it.
        background = "hard",

        -- Level 2 also makes the statusline and sidebars transparent.
        -- Level 1 leaves an opaque bar across the bottom, which looks
        -- broken against the glass effect.
        transparent_background_level = 2,

        italics = true,

        -- The one that actually matters at 0.3. On "low", line numbers and
        -- indent guides all but vanish against a busy desktop.
        ui_contrast = "high",
      })

      vim.cmd.colorscheme("everforest")

      -- Counter-intuitive but important: floats should stay OPAQUE. A
      -- transparent hover popup renders on top of your code and you end up
      -- reading both at once. This covers LSP hover, which-key and fzf-lua.
      local function opaque_floats()
        local bg = "#272e33"
        vim.api.nvim_set_hl(0, "NormalFloat", { bg = bg })
        vim.api.nvim_set_hl(0, "FloatBorder", { bg = bg, fg = "#7a8478" })
        vim.api.nvim_set_hl(0, "Pmenu", { bg = bg })
        vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#3d484d" })
      end
      opaque_floats()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = opaque_floats })
    end,
  },

  -- Language server definitions --------------------------------------------
  -- This plugin no longer configures anything. It ships lsp/<name>.lua files
  -- that Neovim picks up. See lua/lsp.lua for the actual configuration.
  { "neovim/nvim-lspconfig" },

  -- Treesitter -------------------------------------------------------------
  -- IMPORTANT: this is the `main` branch. The old `master` branch was
  -- archived in April 2026 and the rewrite is not backwards compatible.
  -- On `main` the plugin only installs parsers; highlighting is switched on
  -- with Neovim's own vim.treesitter.start(). Almost every tutorial you'll
  -- find online is still written for `master` and will silently do nothing.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })
      require("nvim-treesitter").install({
        "python",
        "go",
        "gomod",
        "gosum",
        "c",
        "cpp",
        "typescript",
        "tsx",
        "javascript",
        "json",
        "jsonc",
        "yaml",
        "toml",
        "html",
        "css",
        "bash",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "gitcommit",
        "diff",
        "regex",
        "query",
      })

      -- Start treesitter for any buffer that has a parser available.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Fuzzy finder -----------------------------------------------------------
  -- This replaces Cmd+P and Cmd+Shift+F, and it's the thing you'll actually
  -- navigate with once the file tree habit wears off.
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "FzfLua",
    keys = {
      { "<leader><leader>", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Grep in project" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "Grep word under cursor" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Open buffers" },
      { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Help tags" },
      { "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace diagnostics" },
      { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document symbols" },
      { "<leader>fS", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", desc = "Workspace symbols" },
      { "<leader>fr", "<cmd>FzfLua resume<cr>", desc = "Resume last picker" },
      { "<leader>fo", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
    },
    opts = {
      winopts = { height = 0.85, width = 0.85, preview = { layout = "vertical" } },
    },
  },

  -- File tree --------------------------------------------------------------
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>n", "<cmd>Neotree toggle reveal left<cr>", desc = "File tree" },
      { "<leader>N", "<cmd>Neotree toggle git_status left<cr>", desc = "Git status tree" },
    },
    opts = {
      close_if_last_window = true,
      window = { width = 32 },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name = { ".git", ".venv", "__pycache__", "node_modules", ".ruff_cache" },
        },
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          -- You have EDITOR=nvim, so git spawns Neovim for commit messages
          -- and interactive rebases. A file tree there is pure noise.
          local ft = vim.bo.filetype
          if ft == "gitcommit" or ft == "gitrebase" then
            return
          end
          if vim.fn.expand("%:t"):match("^COMMIT_EDITMSG$") then
            return
          end

          -- Skip diff mode (nvim -d) and piped input (cmd | nvim -).
          if vim.o.diff or vim.bo.buftype ~= "" then
            return
          end

          -- `nvim .` is already handled by neo-tree's netrw hijack.
          if vim.fn.argc() > 0 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
            return
          end

          if vim.fn.argc() == 0 then
            vim.cmd("Neotree focus") -- nothing open, so start in the tree
          else
            vim.cmd("Neotree show") -- opened a file, leave the cursor in it
          end
        end,
      })
    end,
  },

  -- Formatting -------------------------------------------------------------
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true })
        end,
        mode = { "n", "v" },
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        -- ruff_fix applies autofixable lint rules, ruff_format is the
        -- formatter, ruff_organize_imports replaces isort.
        python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        c = { "clang_format" },
        cpp = { "clang_format" },
        lua = { "stylua" },
        -- Go: gopls formats via LSP, handled by lsp_format below.
      },
      -- C formatting is governed by ~/.clang-format, which sets ColumnLimit: 0
      -- so clang-format keeps the line breaks you wrote instead of reflowing
      -- argument lists onto one line. A .clang-format in a project root
      -- overrides it for that project.
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    },
  },

  -- Surrounding pairs -------------------------------------------------------
  -- Add, change and delete the brackets or quotes around something.
  --
  --   S)     in visual mode, wrap the selection in parentheses
  --   ysiw)  wrap the word under the cursor
  --   yss)   wrap the whole line
  --   cs"'   change surrounding double quotes to single
  --   ds(    delete the surrounding parentheses
  --
  -- ys is "you surround" and takes a motion, so it composes with text objects
  -- the same way d and c do: ysi(" quotes what is inside the parens.
  --
  -- The visual-mode S mapping shadows the built-in S, which is "delete the
  -- line and start inserting". cc does the same thing, so nothing is lost.
  {
    "kylechui/nvim-surround",
    version = "*", -- pin to release tags rather than main
    event = "VeryLazy",
    opts = {},
  },

  -- Learning aids -----------------------------------------------------------
  -- Both of these exist to be removed once the habits stick. Delete the specs
  -- when they stop telling you anything you didn't know.

  -- Shows faint gutter and inline hints for where each motion would take you
  -- from the current cursor position. Teaches by offering, not by scolding.
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    opts = {
      startVisible = true,
    },
    keys = {
      { "<leader>tp", "<cmd>Precognition toggle<cr>", desc = "Toggle precognition hints" },
      { "<leader>tP", "<cmd>Precognition peek<cr>", desc = "Peek precognition hints" },
    },
  },

  -- Notices when you repeat a key (jjjjj, hhhh, x x x x) and tells you the
  -- motion you should have reached for. Irritating on purpose: the
  -- interruption is what builds the habit.
  --
  -- The defaults also disable the arrow keys outright, in every mode. That is
  -- the forcing function. To get them back in insert mode only, set
  --   disabled_keys = { ["<Up>"] = { "n", "x" }, ["<Down>"] = { "n", "x" },
  --                     ["<Left>"] = { "n", "x" }, ["<Right>"] = { "n", "x" } }
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    event = "VeryLazy",
    opts = {},
    keys = {
      { "<leader>tH", "<cmd>Hardtime toggle<cr>", desc = "Toggle hardtime" },
    },
  },

  -- Seamless movement between Neovim splits and tmux panes ------------------
  -- Ctrl-h/j/k/l does the right thing regardless of which side of the
  -- boundary you're on. Needs the matching block in ~/.tmux.conf.
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left pane" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower pane" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper pane" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right pane" },
    },
  },

  -- Keybinding discovery ---------------------------------------------------
  -- Press <leader> and wait. This is your command palette while learning.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>c", group = "code" },
        { "<leader>h", group = "hunk (git)" },
        { "<leader>a", group = "ai (claude)" },
        { "<leader>d", group = "debug" },
        { "<leader>t", group = "toggle" },
      },
    },
  },

  -- Statusline -------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "everforest",
        globalstatus = true,
        section_separators = "",
        component_separators = "|",
      },
      sections = {
        lualine_c = { { "filename", path = 1 } },
      },
    },
  },
  -- Tabs -------------------------------------------------------------------
  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    keys = {
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
    },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        offsets = {
          { filetype = "neo-tree", text = "Files", separator = true },
        },

        -- bufferline normally registers its groups with `default = true`, so
        -- a colourscheme that defines the same name wins. everforest defines
        -- BufferLineIndicatorSelected (highlights.lua:1817, linked to
        -- GreenSign, which has no background), which is why the indicator
        -- kept punching a transparent notch in the selected tab while every
        -- other override below took effect. false makes bufferline's own
        -- definitions authoritative, which is what you want once you are
        -- setting them by hand.
        themable = false,
      },

      -- bufferline derives buffer_selected's background from Normal's, and
      -- transparent_background_level = 2 leaves Normal.bg unset so the
      -- desktop shows through. The current buffer ended up marked only by a
      -- foreground colour, which is hard to spot. Painting it explicitly
      -- gives the tab bar its selection block back.
      --
      -- #3d484d is the same shade opaque_floats() uses for PmenuSel, so the
      -- tab bar and the completion menu agree on what "selected" looks like.
      --
      -- Every *_selected group needs the same bg. Miss one and that piece of
      -- the tab (its icon, its diagnostic count, its separator) punches a
      -- transparent hole through the block.
      highlights = {
        buffer_selected = { bg = "#3d484d", fg = "#d3c6aa", bold = true, italic = false },
        buffer_visible = { bg = "NONE", fg = "#859289" },
        indicator_selected = { bg = "#3d484d", fg = "#a7c080" },
        separator_selected = { bg = "#3d484d", fg = "#272e33" },
        modified_selected = { bg = "#3d484d", fg = "#a7c080" },
        numbers_selected = { bg = "#3d484d", fg = "#d3c6aa" },
        duplicate_selected = { bg = "#3d484d", fg = "#859289", italic = false },
        close_button_selected = { bg = "#3d484d", fg = "#d3c6aa" },
        diagnostic_selected = { bg = "#3d484d" },
        info_selected = { bg = "#3d484d", fg = "#7fbbb3" },
        hint_selected = { bg = "#3d484d", fg = "#a7c080" },
        warning_selected = { bg = "#3d484d", fg = "#dbbc7f" },
        error_selected = { bg = "#3d484d", fg = "#e67e80" },
      },
    },
  },
}
