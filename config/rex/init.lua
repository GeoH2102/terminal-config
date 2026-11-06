-- Migrated from ~/.tmux.conf. The prefix is ctrl+b.

-- Pressing the prefix twice sends it to the program in the pane.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

rex.bind("ctrl+b>r", "client.config.reload")
rex.bind("ctrl+b>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+b>-", "pane.split", { direction = "down" })
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>shift+s", "session.switch")

rex.bind("ctrl+b>shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+b>shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+b>shift+k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+b>shift+l", "pane.resize", { amount = 5, direction = "right" })

-- tmux's bind -r: ctrl+b then ctrl+r enters; enter or escape leaves.
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+b>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

rex.bind("repeat/shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("repeat/shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/shift+k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("repeat/shift+l", "pane.resize", { amount = 5, direction = "right" })

-- Ctrl-h/j/k/l moves between panes, unless the pane is running Neovim or fzf,
-- which gets the key instead, like the vim-tmux-navigator block in ~/.tmux.conf.
-- At its edge, Neovim moves to the next pane itself: see lua/plugins/editor.lua
-- in the Neovim config.
local terminal = "com.superlogical.terminal"
local key_programs = {
  vi = true, vim = true, nvim = true, view = true,
  vimdiff = true, nvimdiff = true, fzf = true,
}
local control_char = { left = "\8", down = "\10", up = "\11", right = "\12" }

local function wants_keys(process)
  -- A running child with no foreground process means the process group's
  -- leader has exited, as in `printf x | fzf`.
  if not process.foreground then
    return process.child ~= nil
  end
  -- Ask ps because foreground.name is only the group's leader, which is zsh
  -- for `x=$(printf x | fzf)`.
  local ps = rex.exec({ "ps", "-o", "comm=", "-g", tostring(process.foreground.pid) })
  for path in (ps and ps.stdout or ""):gmatch("[^\n]+") do
    if key_programs[path:match("[^/]+$")] then
      return true
    end
  end
  return false
end

rex.action{
  name = "navigate",
  title = "Navigate Panes",
  args = { direction = "string" },
  repeats = true,
  run = function(ctx, args)
    if wants_keys(rex.block.call(terminal, "process", {}) or {}) then
      rex.block.call(terminal, "write", { data = control_char[args.direction] })
    else
      rex.session.focus_direction{ direction = args.direction, wrap = true }
    end
  end,
}

rex.bind("ctrl+h", "navigate", { direction = "left" })
rex.bind("ctrl+j", "navigate", { direction = "down" })
rex.bind("ctrl+k", "navigate", { direction = "up" })
rex.bind("ctrl+l", "navigate", { direction = "right" })
