# Shared env for every non-personal workspace. personal keeps the tools' defaults.
# usage from a workspace envrc: WS=<name>; . ~/.config/workspaces/isolated.sh
# Add a line here for any other tool that has a config-dir env var (see docs/howto.md, section E).
W="$HOME/.config/workspaces/$WS"
export WORKSPACE="$WS"
export CLAUDE_CONFIG_DIR="$W/claude"
export GH_CONFIG_DIR="$W/gh"
export AWS_CONFIG_FILE="$W/aws/config" AWS_SHARED_CREDENTIALS_FILE="$W/aws/credentials"
export NPM_CONFIG_USERCONFIG="$W/npmrc"
export DOCKER_CONFIG="$W/docker"
export KUBECONFIG="$W/kube/config"
unset GH_TOKEN GITHUB_TOKEN AWS_PROFILE
# Every file in <ws>/secrets/ becomes an env var named like the file, e.g. secrets/NPM_TOKEN -> $NPM_TOKEN
for f in "$W"/secrets/*; do
  if [ -f "$f" ]; then export "${f##*/}=$(cat "$f")"; fi
done
unset W WS f
