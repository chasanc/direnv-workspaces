#!/usr/bin/env bash
# Install ws and the shared config. Safe to re-run. Usage: ./install.sh [--no-shell]
#   --no-shell  don't touch ~/.bashrc / ~/.zshrc (add `. ~/.config/workspaces/shell-hook.sh` yourself)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$HOME/.config/workspaces"

for t in bash git jq direnv; do
  command -v "$t" >/dev/null || { echo "install: missing '$t'. Install it first (e.g. sudo apt install $t)." >&2; exit 1; }
done

mkdir -p "$HOME/.local/bin" "$R/personal"
chmod 700 "$R"
install -m 755 "$here/bin/ws" "$HOME/.local/bin/ws"
install -m 644 "$here/config/isolated.sh" "$R/isolated.sh"
install -m 644 "$here/config/shell-hook.sh" "$R/shell-hook.sh"
# personal's envrc is yours to edit afterwards: don't overwrite
[ -f "$R/personal/envrc" ] || install -m 644 "$here/config/personal.envrc" "$R/personal/envrc"

if [ "${1:-}" != "--no-shell" ]; then
  line='. "$HOME/.config/workspaces/shell-hook.sh" # direnv-workspaces'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    grep -qxF "$line" "$rc" || printf '\n%s\n' "$line" >> "$rc"
  done
fi

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "install: add \$HOME/.local/bin to your PATH" >&2 ;; esac
echo "installed. Open a new terminal, then: ws new <name> you@example.com"
