
# Modern Zsh Configuration
# ----- Environment -----
export PATH="$HOME/.local/bin:$HOME/.atuin/bin:$PATH"
export EDITOR="nano"
export VISUAL="$EDITOR"
export XDG_CONFIG_HOME="$HOME/.config"

# ----- Zinit Plugin Manager -----
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"

    # Essential plugins with turbo mode (deferred loading)
    zinit wait lucid for \
        atinit"zicompinit; zicdreplay" \
            zdharma-continuum/fast-syntax-highlighting \
        atload"_zsh_autosuggest_start" \
            zsh-users/zsh-autosuggestions \
        blockf atpull'zinit creinstall -q .' \
            zsh-users/zsh-completions

    # Additional useful plugins
    zinit wait lucid for \
        OMZP::git \
        OMZP::sudo \
        OMZP::extract
fi

# ----- History -----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY       # Write timestamp to history
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicates first
setopt HIST_IGNORE_DUPS       # Ignore duplicates
setopt HIST_IGNORE_SPACE      # Ignore commands starting with space
setopt HIST_VERIFY            # Show command before executing from history
setopt SHARE_HISTORY          # Share history between sessions

# ----- Options -----
setopt AUTO_CD                # cd by typing directory name
setopt AUTO_PUSHD             # Push directories onto stack
setopt PUSHD_IGNORE_DUPS      # Don't push duplicates
setopt INTERACTIVE_COMMENTS   # Allow comments in interactive shell

# ----- Key Bindings -----
bindkey -e                    # Emacs key bindings
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ----- Completion -----
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case insensitive

# ----- Modern Tool Integrations -----

# Zoxide (smart cd, replaces cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# FZF (fuzzy finder)
if command -v fzf &> /dev/null; then
    source <(fzf --zsh 2>/dev/null) || true
fi

# ----- Aliases -----

# Modern replacements (only if installed)
if command -v eza &> /dev/null; then
    alias ls='eza'
    alias ll='eza -l --git'
    alias la='eza -la --git'
    alias lt='eza --tree --level=2'
else
    alias ll='ls -l'
    alias la='ls -la'
fi

if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    alias catp='bat'  # With paging
fi

if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# Common shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias g='git'
alias gst='git status'
alias gd='git diff'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'

# ----- Starship Prompt -----
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# ----- Atuin (load last to ensure Ctrl+R binding) -----
if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi


# ----- Node -----
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# ----- NeoVim -----
# Homebrew keeps LLVM keg-only, so clangd isn't on PATH by default.
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

# uv installs tools (ty, ruff) here.
export PATH="$HOME/.local/bin:$PATH"

# Go binaries.
export PATH="$HOME/go/bin:$PATH"

export EDITOR="nvim"
export VISUAL="nvim"

alias v="nvim"
alias vi="nvim"

# ---------------------------------------------------------------------------
# dev: build the working layout for the current project.
#
#   ┌──────────────────┬─────────────┐
#   │                  │             │
#   │      nvim        │  <profile>  │
#   │                  │             │
#   ├──────────────────┴─────────────┤
#   │            claude              │
#   └────────────────────────────────┘
#
# The main pane is always Neovim and the bottom pane is always Claude. The
# profile decides what runs in the right-hand pane:
#
#   python   ipython (.venv if present, else uv)
#   c        a second claude
#   rust     a second claude
#   go       a second claude
#   node     a shell
#   generic  a shell
#
# The profile comes from project markers in the current directory, searching
# upward to the git root. Pass one explicitly to override it.
#
# Order matters: Neovim starts first so its lock file exists in
# ~/.claude/ide/ before the Claude CLI goes looking for it. Without that,
# Claude won't auto-detect the editor and you'll have to run /ide manually.
#
# Usage:  dev                  (detect the profile, session named after $PWD)
#         dev c                (force a profile)
#         dev -s myproject     (explicit session name)
#         dev c -s myproject   (both)
# ---------------------------------------------------------------------------
dev() {
  local profile="" session=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -s)
        session="$2"
        shift 2
        ;;
      -h|--help)
        echo "usage: dev [profile] [-s session]"
        echo "profiles: $(tmux-dev-layout --list-profiles | tr '\n' ' ')"
        return 0
        ;;
      *)
        profile="$1"
        shift
        ;;
    esac
  done

  # Validate before creating anything, so a typo does not leave a half-built
  # session behind. tmux-dev-layout owns the list of valid names.
  if [ -n "$profile" ] && ! tmux-dev-layout --list-profiles | grep -qx "$profile"; then
    echo "dev: unknown profile '$profile'" >&2
    echo "profiles: $(tmux-dev-layout --list-profiles | tr '\n' ' ')" >&2
    return 1
  fi

  session="${session:-$(basename "$PWD" | tr . _)}"

  if tmux has-session -t "$session" 2>/dev/null; then
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$session"
    else
      tmux attach -t "$session"
    fi
    return
  fi

  tmux new-session -d -s "$session" -c "$PWD" -x "$(tput cols)" -y "$(tput lines)"

  # The layout lives in ~/.local/bin/tmux-dev-layout so that sesh can build the
  # same panes when it creates a session.
  if [ -n "$profile" ]; then
    tmux-dev-layout -p "$profile" "$session"
  else
    tmux-dev-layout "$session"
  fi

  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$session"
  else
    tmux attach -t "$session"
  fi
}

# Jump between existing sessions with a fuzzy picker.
ts() {
  local session
  session=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | fzf --height 40%) || return
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$session"
  else
    tmux attach -t "$session"
  fi
}
