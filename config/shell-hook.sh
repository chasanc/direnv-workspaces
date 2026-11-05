# Sourced from ~/.bashrc / ~/.zshrc by install.sh.
# 1. start in the personal workspace; direnv switches it per folder
# 2. hook direnv into the shell
# 3. show the workspace in the prompt
[ -n "${WORKSPACE:-}" ] || . "$HOME/.config/workspaces/personal/envrc"
if command -v direnv >/dev/null; then
  if [ -n "${ZSH_VERSION:-}" ]; then eval "$(direnv hook zsh)"; else eval "$(direnv hook bash)"; fi
fi
if [ -n "${ZSH_VERSION:-}" ]; then
  RPROMPT='%F{yellow}[${WORKSPACE:-?}]%f'
else
  PS1='[${WORKSPACE:-?}] '"${PS1#\[\$\{WORKSPACE:-?\}\] }"
fi
