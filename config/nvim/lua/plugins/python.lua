-- ~/.config/nvim/lua/plugins/python.lua

return {
  -- Send code to the IPython pane ------------------------------------------
  -- This is the piece that makes the tmux layout worth having: select code,
  -- press <leader>r, and it lands in the IPython session running in the
  -- pane to the right. State persists there across nvim restarts.
  {
    "jpalardy/vim-slime",
    ft = { "python" },
    init = function()
      vim.g.slime_target = "tmux"

      -- Without bracketed paste, IPython re-indents multi-line blocks as it
      -- receives them and everything falls apart.
      vim.g.slime_bracketed_paste = 1

      -- {right-of} resolves at send time, so you don't have to hardcode a
      -- pane id that changes every session.
      vim.g.slime_default_config = {
        socket_name = "default",
        target_pane = "{right-of}",
      }
      vim.g.slime_dont_ask_default = 1
      vim.g.slime_no_mappings = 1
    end,
    keys = {
      { "<leader>r", "<Plug>SlimeParagraphSend", ft = "python", desc = "Send paragraph to REPL" },
      { "<leader>r", "<Plug>SlimeRegionSend", mode = "v", ft = "python", desc = "Send selection to REPL" },
      { "<leader>R", "<Plug>SlimeLineSend", ft = "python", desc = "Send line to REPL" },
    },
  },

  -- `# %%` cell markers, so you get the interactive-script workflow --------
  -- <leader>x runs the cell under the cursor, <leader>X runs it and moves on.
  {
    "hanschen/vim-ipython-cell",
    dependencies = { "jpalardy/vim-slime" },
    ft = { "python" },
    init = function()
      vim.g.ipython_cell_delimit_cells_by = "tags"
      vim.g.ipython_cell_tag = { "# %%", "#%%", "# <codecell>" }
    end,
    keys = {
      { "<leader>x", "<cmd>IPythonCellExecuteCell<cr>", ft = "python", desc = "Run cell" },
      { "<leader>X", "<cmd>IPythonCellExecuteCellJump<cr>", ft = "python", desc = "Run cell and advance" },
      { "]x", "<cmd>IPythonCellNextCell<cr>", ft = "python", desc = "Next cell" },
      { "[x", "<cmd>IPythonCellPrevCell<cr>", ft = "python", desc = "Previous cell" },
    },
  },

  -- Debugging --------------------------------------------------------------
  -- This is the roughest part of leaving VSCode. If you don't reach for a
  -- step debugger often, delete this block on day one and add it back in
  -- week three when you actually miss it.
  --
  -- Python needs debugpy in the project venv:  uv add --dev debugpy
  -- Go needs delve:                            brew install delve
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
      "leoluz/nvim-dap-go",
    },
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue / start",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step out",
      },
      {
        "<leader>dt",
        function()
          require("dap").terminate()
        end,
        desc = "Terminate",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle debug UI",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      -- Relative path: assumes you launch nvim from the project root, which
      -- the `dev` shell function does.
      require("dap-python").setup(".venv/bin/python")
      require("dap-go").setup()

      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
  },
}
