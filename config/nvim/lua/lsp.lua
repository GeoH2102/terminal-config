-- ~/.config/nvim/lua/lsp.lua
--
-- On Neovim 0.11+ nvim-lspconfig no longer "sets up" servers. It just drops
-- a lsp/<name>.lua definition into the runtime path. You override bits of it
-- with vim.lsp.config() and switch it on with vim.lsp.enable(). That's all.

-- ---------------------------------------------------------------------------
-- Python: ty for types, navigation, hover, completion.
--         ruff for linting and formatting.
-- ---------------------------------------------------------------------------

vim.lsp.config("ty", {
  settings = {
    ty = {
      -- ty discovers the project's .venv automatically. If you keep your
      -- environment somewhere else, pin it:
      -- environment = { python = "./path/to/venv" },
      --
      -- Downgrade a rule you don't want failing your buffer:
      -- configuration = { rules = { ["unresolved-reference"] = "warn" } },
    },
  },
})

vim.lsp.config("ruff", {
  init_options = {
    settings = {
      -- Anything here is overridden by the project's pyproject.toml or
      -- ruff.toml, which is where your real config should live.
      lineLength = 88,
    },
  },
})

-- ---------------------------------------------------------------------------
-- clangd. Homebrew keeps LLVM keg-only, so the binary isn't on PATH.
-- ---------------------------------------------------------------------------

local brew_clangd = "/opt/homebrew/opt/llvm/bin/clangd"
if vim.uv.fs_stat(brew_clangd) then
  vim.lsp.config("clangd", {
    cmd = {
      brew_clangd,
      "--background-index",
      "--clang-tidy",
      "--header-insertion=iwyu",
      "--completion-style=detailed",
    },
  })
end

-- ---------------------------------------------------------------------------
-- Go
-- ---------------------------------------------------------------------------

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = { unusedparams = true, shadow = true },
      staticcheck = true,
      gofumpt = true,
      hints = {
        assignVariableTypes = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})

-- ---------------------------------------------------------------------------
-- Lua, so editing this config is pleasant
-- ---------------------------------------------------------------------------

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
      diagnostics = { globals = { "vim" } },
    },
  },
})

-- ---------------------------------------------------------------------------
-- Switch them on
-- ---------------------------------------------------------------------------

vim.lsp.enable({
  "ty", -- Python types + navigation
  "ruff", -- Python lint + format
  "vtsls", -- TypeScript / JavaScript
  "clangd", -- C
  "gopls", -- Go
  "lua_ls", -- Lua
})

-- ---------------------------------------------------------------------------
-- Per-buffer behaviour once a server attaches
-- ---------------------------------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- ty and ruff both attach to Python buffers. Without this you get two
    -- competing hover popups, and ruff's is much the less useful of the two.
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    -- gd isn't a default LSP mapping: plain gd means "go to local
    -- declaration". This shadows it with the LSP version.
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
      buffer = args.buf,
      desc = "LSP: go to definition",
    })

    -- Inlay hints, where the server supports them. Toggle with <leader>th.
    if client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      vim.keymap.set("n", "<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
      end, { buffer = args.buf, desc = "Toggle inlay hints" })
    end

    -- Signature help on demand is <C-s> in insert mode, which Neovim maps for
    -- you. This adds the automatic version. Servers publish a list of trigger
    -- characters but nothing in Neovim acts on that list, so typing "(" shows
    -- nothing by default. clangd's list is { "(", ")", "{", "}", "<", ">", "," };
    -- only the character that opens an argument list and the one that
    -- separates arguments are worth firing on.
    if client:supports_method("textDocument/signatureHelp") then
      local triggers = { ["("] = true, [","] = true }
      vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = args.buf,
        desc = "Auto signature help",
        callback = function()
          -- The completion menu and the signature float compete for the same
          -- screen space. Completion wins.
          if vim.fn.pumvisible() == 1 then
            return
          end
          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]
          if triggers[line:sub(col, col)] then
            -- focus = false keeps the cursor in the buffer. Without it, a
            -- second trigger jumps you into the float.
            vim.lsp.buf.signature_help({ focus = false, silent = true })
          end
        end,
      })
    end

    -- Highlight other references to the symbol under the cursor.
    if client:supports_method("textDocument/documentHighlight") then
      local group = vim.api.nvim_create_augroup("lsp-highlight-" .. args.buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = group,
        buffer = args.buf,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        buffer = args.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})

-- ---------------------------------------------------------------------------
-- Sweep orphaned signature help floats
-- ---------------------------------------------------------------------------
--
-- A signature help popup can end up on screen with nothing able to close it,
-- surviving scrolling, mode changes and edits until you quit.
--
-- $VIMRUNTIME/lua/vim/lsp/util.lua registers a float's close autocmds
-- (CursorMoved, CursorMovedI, InsertCharPre) at line 1769, which is inside the
-- `else` branch: the path that CREATES a window. vim.lsp.buf.signature_help
-- re-shows an existing popup by setting config._update_win, and that takes the
-- other branch, reusing the window without registering anything. Since
-- close_preview_window deletes the augroup by name when it fires, a float that
-- has been closed once and then re-shown through the update path has no close
-- autocmds left at all.
--
-- Triggering signature help from TextChangedI on every "(" and "," above means
-- that path gets taken constantly, which is why this config runs into it and a
-- stock one does not.
--
-- open_floating_preview tags each float with a window variable named after the
-- LSP method that opened it, so matching on that closes signature help popups
-- and nothing else. Hover, which-key, fzf-lua and the diagnostic panel all
-- stay put.
--
-- InsertLeave is the sweep point because a signature help popup has no reason
-- to outlive insert mode. `:fclose!` remains the manual escape hatch, and
-- closes every float rather than just these.
vim.api.nvim_create_autocmd("InsertLeave", {
  desc = "Close orphaned signature help floats",
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        if pcall(vim.api.nvim_win_get_var, win, "textDocument/signatureHelp") then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end
  end,
})

-- ---------------------------------------------------------------------------
-- Diagnostics presentation
-- ---------------------------------------------------------------------------

vim.diagnostic.config({
  -- Only show inline text for the line you're on. Showing it for every line
  -- turns a file with real type errors into unreadable soup.
  virtual_text = false,
  underline = true,
  severity_sort = true,
  update_in_insert = false,
  float = {
    border = "rounded",
    source = true,
    focusable = false,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
})

-- The current line's diagnostics go to a window pinned along the bottom of
-- the editor. This replaces an autocmd that called vim.diagnostic.open_float
-- on CursorHold, which put the popup next to the cursor and so on top of the
-- code being read.
--
-- <leader>e still opens the float on demand, and <leader>td toggles the panel.
require("diagnostic_panel").setup()

-- The panel is opaque for the same reason the other floats are: a transparent
-- one over a transparent terminal shows the desktop through the text.
local function panel_highlights()
  vim.api.nvim_set_hl(0, "DiagnosticPanel", { bg = "#272e33" })
  vim.api.nvim_set_hl(0, "DiagnosticPanelBorder", { bg = "#272e33", fg = "#3d484d" })
end
panel_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = panel_highlights })
