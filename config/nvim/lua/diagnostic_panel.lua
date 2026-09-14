-- ~/.config/nvim/lua/diagnostic_panel.lua
--
-- Diagnostics for the current line, shown in one window pinned to the bottom
-- of the editor instead of a popup next to the cursor.
--
-- The popup this replaces (vim.diagnostic.open_float on CursorHold) opens
-- wherever the cursor happens to be, so it lands on top of whatever you were
-- reading. This window is always in the same place, which means you learn to
-- stop looking at it.
--
-- ONE HONEST LIMITATION. This is a float, so it draws over the bottom rows of
-- the edit window rather than shrinking it. You have scrolloff = 8 and the
-- panel is at most 6 rows including its rule, so it never covers the line the
-- cursor is on; it does cover a few lines of context below it. If that turns
-- out to matter more than the rows it saves, the alternative is a real split
-- (`:botright 5split`), which never overlaps anything but does rearrange your
-- windows every time a diagnostic appears.

local M = {}

-- Rows of text, before the rule on top is counted.
local MAX_HEIGHT = 5

local SEVERITY = {
  [vim.diagnostic.severity.ERROR] = { label = "E", hl = "DiagnosticError" },
  [vim.diagnostic.severity.WARN] = { label = "W", hl = "DiagnosticWarn" },
  [vim.diagnostic.severity.INFO] = { label = "I", hl = "DiagnosticInfo" },
  [vim.diagnostic.severity.HINT] = { label = "H", hl = "DiagnosticHint" },
}

local ns = vim.api.nvim_create_namespace("diagnostic_panel")

local buf, win
local last_key -- what is currently drawn, so an unchanged line is a no-op
local enabled = true

-- ---------------------------------------------------------------------------
-- Text layout
-- ---------------------------------------------------------------------------

-- Greedy word wrap. Neovim's own 'wrap' happens at draw time, which is no use
-- here: the height has to be decided before the window is opened.
local function wrap(text, width)
  local out = {}
  local current = ""

  local function flush()
    if current ~= "" then
      out[#out + 1] = current
      current = ""
    end
  end

  for word in text:gmatch("%S+") do
    -- A single word longer than the window (a long import path, a type
    -- signature with no spaces) gets cut rather than allowed to overflow.
    while #word > width do
      flush()
      out[#out + 1] = word:sub(1, width)
      word = word:sub(width + 1)
    end
    if current == "" then
      current = word
    elseif #current + 1 + #word <= width then
      current = current .. " " .. word
    else
      flush()
      current = word
    end
  end
  flush()

  return out
end

-- Turn one diagnostic into its display lines, plus the highlight for its
-- severity marker. Continuation lines are indented to sit under the message
-- rather than under the marker.
local function format(diagnostic, width)
  local sev = SEVERITY[diagnostic.severity] or SEVERITY[vim.diagnostic.severity.ERROR]

  -- ty and clangd both emit multi-line messages. Collapse them: the panel
  -- wraps to its own width, and the server's line breaks fight that.
  local message = diagnostic.message:gsub("%s+", " ")

  local origin = diagnostic.source or "lsp"
  if diagnostic.code then
    origin = origin .. " " .. tostring(diagnostic.code)
  end
  local tail = ("  ·  %s  ·  %d:%d"):format(origin, diagnostic.lnum + 1, diagnostic.col + 1)

  local lines = {}
  for i, line in ipairs(wrap(message .. tail, width - 5)) do
    lines[i] = (i == 1) and (" " .. sev.label .. "  " .. line) or ("    " .. line)
  end
  return lines, sev.hl
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

local function ensure_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "diagnosticpanel"
  return buf
end

-- Every option assignment fires OptionSet, and an OptionSet listener that
-- redraws the panel is one edit away from a render loop. Set an option only
-- when it is actually changing, so a redraw of identical content is silent.
local function set_option(scope, id, name, value)
  if scope[id][name] ~= value then
    scope[id][name] = value
  end
end

-- Neovim refuses to open, close or resize a window, or change text, while a
-- textlock is held, and raises E565. vim.schedule callbacks are NOT exempt:
-- vim.lsp.buf_request_sync calls vim.wait, which pumps the event loop, so a
-- queued panel update can run in the middle of C omni-completion
-- (ccomplete#Complete -> _tagfunc -> buf_request_sync -> vim.wait) and be
-- refused. That is intermittent by nature: it needs a scheduled update and a
-- synchronous LSP request to collide.
--
-- state() reports what Neovim is busy doing, and its help describes this exact
-- pattern: do the work when it is safe, otherwise queue it and retry on
-- SafeState.
--
--   m  halfway a mapping, :normal, or feedkeys()
--   o  operator pending
--   a  Insert mode autocomplete active   <- the one that raised E565 here
--
-- "x" (executing an autocommand) is deliberately NOT in this list. SafeState is
-- itself an autocommand, so state() reports "xS" inside the retry; including
-- "x" would make every retry bail and re-queue itself, forever.
local BUSY = "moa"
local retry_queued = false

local function retry_when_safe()
  if retry_queued then
    return
  end
  retry_queued = true
  vim.api.nvim_create_autocmd("SafeState", {
    once = true,
    callback = function()
      retry_queued = false
      M.update()
    end,
  })
end

function M.close()
  if win and vim.api.nvim_win_is_valid(win) then
    -- If the close is refused, keep `win` set so the retry closes it rather
    -- than leaking a window nothing has a handle to any more.
    if not pcall(vim.api.nvim_win_close, win, true) then
      return retry_when_safe()
    end
  end
  win = nil
  last_key = nil
end

local function window_config(height)
  return {
    relative = "editor",
    width = vim.o.columns,
    height = height,
    -- Rows the UI already owns along the bottom: the command line, and the
    -- single global statusline that laststatus = 3 draws.
    --
    -- `row` positions the content, and nvim_open_win draws the border outside
    -- that. So the rule lands on the row above without being subtracted for
    -- here; budgeting for it too leaves an empty row above the statusline.
    row = vim.o.lines - vim.o.cmdheight - 1 - height,
    col = 0,
    style = "minimal",
    -- Border segments run topleft, top, topright, right, botright, bottom,
    -- botleft, left. Only the top is set, so the panel gets a rule separating
    -- it from the code rather than a box around it.
    border = { "", "─", "", "", "", "", "", "" },
    focusable = false,
    zindex = 40, -- below hover floats (50) and the completion menu (100)
  }
end

-- Both halves of this touch window and buffer state, so both can be refused
-- under a textlock. On refusal nothing is left half-drawn: last_key is cleared
-- so the retry rebuilds from scratch rather than deciding the content is
-- already current and skipping the redraw.
local function show(lines, marks)
  local height = math.min(#lines, MAX_HEIGHT)

  if win and vim.api.nvim_win_is_valid(win) then
    if not pcall(vim.api.nvim_win_set_config, win, window_config(height)) then
      last_key = nil
      return retry_when_safe()
    end
  else
    local ok, handle = pcall(vim.api.nvim_open_win, ensure_buf(), false, window_config(height))
    if not ok then
      last_key = nil
      return retry_when_safe()
    end
    win = handle
    -- Opaque, matching opaque_floats() in lua/plugins/editor.lua. A
    -- transparent panel over a transparent terminal is unreadable.
    vim.wo[win].winhighlight = "NormalFloat:DiagnosticPanel,FloatBorder:DiagnosticPanelBorder"
    vim.wo[win].wrap = false
  end

  -- The buffer is a scratch buffer nothing can focus, so it stays modifiable
  -- rather than being toggled around each write. Toggling it fired two
  -- OptionSet events per render, which is what fed the loop.
  set_option(vim.bo, buf, "modifiable", true)

  local drawn = pcall(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, mark in ipairs(marks) do
      vim.api.nvim_buf_set_extmark(buf, ns, mark.row, 1, {
        end_col = 2,
        hl_group = mark.hl,
      })
    end
  end)
  if not drawn then
    last_key = nil
    retry_when_safe()
  end
end

-- ---------------------------------------------------------------------------
-- Driving it
-- ---------------------------------------------------------------------------

function M.update()
  if not enabled then
    return
  end

  -- Ask before acting, rather than relying on the pcalls below to catch the
  -- refusal. Insert-mode completion is the common case: 'complete' includes
  -- "o", so every few keystrokes runs the omnifunc, and the C one issues a
  -- synchronous LSP request that pumps the event loop under a textlock.
  if vim.fn.state(BUSY) ~= "" then
    return retry_when_safe()
  end

  -- Only track real file windows. Floats, the file tree, terminals and the
  -- panel itself all have something other than an empty buftype or a
  -- non-empty relative.
  local ok, config = pcall(vim.api.nvim_win_get_config, 0)
  if not ok or config.relative ~= "" or vim.bo.buftype ~= "" then
    return M.close()
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diagnostics = vim.diagnostic.get(0, { lnum = lnum })
  if #diagnostics == 0 then
    return M.close()
  end

  table.sort(diagnostics, function(a, b)
    if a.severity ~= b.severity then
      return a.severity < b.severity -- ERROR = 1, so most severe first
    end
    return a.col < b.col
  end)

  local lines, marks = {}, {}
  local shown = 0
  for _, diagnostic in ipairs(diagnostics) do
    if #lines >= MAX_HEIGHT then
      break
    end
    local entry, hl = format(diagnostic, vim.o.columns)
    marks[#marks + 1] = { row = #lines, hl = hl }
    vim.list_extend(lines, entry)
    shown = shown + 1
  end
  while #lines > MAX_HEIGHT do
    table.remove(lines)
  end

  -- A line can carry more diagnostics than the panel has room for. Dropping
  -- them silently is the one way this is worse than the popup it replaces, so
  -- say how many are missing and where to read them.
  local hidden = #diagnostics - shown
  if hidden > 0 then
    lines[#lines] = ("    … %d more, <leader>e for all"):format(hidden)
  end

  -- CursorMoved fires on every keystroke of a motion. Redrawing identical
  -- content each time makes the panel flicker, so bail when nothing changed.
  local key = table.concat(lines, "\n") .. "|" .. vim.o.columns
  if key == last_key and win and vim.api.nvim_win_is_valid(win) then
    return
  end
  last_key = key

  show(lines, marks)
end

function M.toggle()
  enabled = not enabled
  if enabled then
    M.update()
  else
    M.close()
  end
  vim.notify("Diagnostic panel " .. (enabled and "on" or "off"))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("diagnostic-panel", { clear = true })

  vim.api.nvim_create_autocmd({
    "CursorMoved",
    "CursorMovedI",
    "DiagnosticChanged",
    "BufEnter",
    "WinEnter",
    "WinScrolled",
  }, {
    group = group,
    callback = function()
      -- Deferred so the panel is positioned against the layout as it will be
      -- after the event, not as it was during it.
      vim.schedule(M.update)
    end,
  })

  -- The panel is sized against vim.o.columns, vim.o.lines and vim.o.cmdheight,
  -- so a change to any of those leaves it the wrong width in the wrong place.
  --
  -- These two used to be one autocmd on { "VimResized", "OptionSet" } with
  -- pattern { "*", "cmdheight" }, which fired on EVERY option set, including
  -- the modifiable = true/false pair that show() performs. Since the callback
  -- clears last_key, each render defeated the dedup guard and triggered
  -- another: measured at 377,892 renders in six seconds, with Neovim at 4.6 GB
  -- and 93% CPU. For OptionSet the pattern is the option name, so it has to
  -- name the geometry options and nothing else.
  local function reposition()
    last_key = nil
    vim.schedule(M.update)
  end

  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = reposition })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "columns", "lines", "cmdheight" },
    callback = reposition,
  })

  vim.api.nvim_create_autocmd({ "VimLeavePre", "TabLeave" }, {
    group = group,
    callback = M.close,
  })

  vim.keymap.set("n", "<leader>td", M.toggle, { desc = "Toggle diagnostic panel" })
end

return M
