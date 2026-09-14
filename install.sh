#!/usr/bin/env bash
#
# Link every config in this repo into $HOME, and optionally install the tools
# they depend on.
#
#   ./install.sh              create or refresh the symlinks
#   ./install.sh --packages   also install packages for this OS, then the
#                             handful of tools that no package manager covers
#
# Symlinks rather than copies, so editing ~/.zshrc edits the repo and
# `git status` shows what changed. Safe to re-run: an existing correct link is
# left alone, and a real file in the way is moved aside with a timestamped
# .bak suffix rather than deleted, so repeated runs never overwrite a backup.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# link <path in repo> <path in $HOME>
link() {
  local src="$DOTFILES/$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  ok      %s\n' "$dst"
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local bak="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$dst" "$bak"
    printf '  moved   %s -> %s\n' "$dst" "$bak"
  fi
  ln -sfn "$src" "$dst"
  printf '  linked  %s\n' "$dst"
}

echo "Linking configs"
link zsh/.zshrc            "$HOME/.zshrc"
link zsh/.zshenv           "$HOME/.zshenv"
link git/.gitconfig        "$HOME/.gitconfig"
link tmux/.tmux.conf       "$HOME/.tmux.conf"
link clang/.clang-format   "$HOME/.clang-format"
link config/starship.toml  "$HOME/.config/starship.toml"
link config/ghostty/config "$HOME/.config/ghostty/config"
link config/nvim           "$HOME/.config/nvim"
link bin/tmux-dev-layout   "$HOME/.local/bin/tmux-dev-layout"
link bin/tmux-pane-tab     "$HOME/.local/bin/tmux-pane-tab"
link bin/tmux-sesh-picker  "$HOME/.local/bin/tmux-sesh-picker"
chmod +x "$DOTFILES"/bin/*

[ "${1:-}" = "--packages" ] || exit 0

echo "Installing packages"
case "$(uname -s)" in
  Darwin)
    brew bundle --file="$DOTFILES/packages/Brewfile"
    ;;
  Linux)
    if command -v pacman >/dev/null; then
      # Comments and blank lines stripped; --needed skips what's installed.
      grep -vE '^\s*(#|$)' "$DOTFILES/packages/arch.txt" | sudo pacman -S --needed -
    else
      echo "  no supported package manager found; install packages/arch.txt by hand" >&2
    fi
    ;;
esac

# Tools that live outside the package managers. Each is a no-op if present.
echo "Installing unpackaged tools"
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[ -d "$ZINIT_HOME" ] || git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
[ -d "$HOME/.tmux/plugins/tpm" ] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
if command -v uv >/dev/null; then
  uv tool install ruff >/dev/null 2>&1 || true
  uv tool install ty >/dev/null 2>&1 || true
fi

cat <<'EOF'

Done. Still manual:
  - Node (for vtsls and prettierd): install nvm, then `npm install -g @vtsls/language-server @fsouza/prettierd`
  - tmux plugins: start tmux and press prefix + I
  - Neovim plugins: start nvim; lazy.nvim installs everything from lazy-lock.json
EOF
