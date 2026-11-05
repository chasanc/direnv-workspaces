#!/usr/bin/env bash
# Self-test: installs into a throwaway HOME and exercises ws; touches nothing real. Usage: test/selftest.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" WS_WORK="$T/work" WS_SKIP_PLUGINS=1 GIT_CONFIG_NOSYSTEM=1
R="$HOME/.config/workspaces"
fail() { echo "FAIL: $*" >&2; exit 1; }

# a fake claude-desktop that records the env it got
mkdir -p "$T/bin" "$HOME"
printf '#!/bin/sh\necho "$WORKSPACE ${CLAUDE_USER_DATA_DIR:-default} $*" > "%s/desktop.out"\n' "$T" > "$T/bin/claude-desktop"
chmod +x "$T/bin/claude-desktop"
export PATH="$T/bin:$HOME/.local/bin:$PATH"

# fake personal setup in the default locations
mkdir -p "$HOME/.claude/skills/demo" "$HOME/.agents/skills/linked" "$HOME/.docker/contexts"
ln -s ../../.agents/skills/linked "$HOME/.claude/skills/linked"
printf '{"permissions":{"additionalDirectories":["~/.claude/plugins"]},"hooks":{"Stop":[{"command":"%s/.claude/hooks/x.sh"}]}}\n' "$HOME" > "$HOME/.claude/settings.json"
echo '{"mcpServers":{"example":{"command":"uvx"}},"oauthAccount":{"secret":1}}' > "$HOME/.claude.json"
echo '{"auths":{"x":{}},"currentContext":"desktop"}' > "$HOME/.docker/config.json"
touch "$HOME/.claude/.credentials.json" "$HOME/.bashrc"

# a fresh install must work, and be repeatable
"$HERE/install.sh" > /dev/null
"$HERE/install.sh" > /dev/null
[ "$(grep -c direnv-workspaces "$HOME/.bashrc")" = 1 ] || fail "shell hook added once"
[ -x "$HOME/.local/bin/ws" ] || fail "ws installed"
WS_BIN="$HOME/.local/bin/ws"
echo 'export EXTRA=1' >> "$R/personal/envrc"
"$HERE/install.sh" --no-shell > /dev/null
grep -q EXTRA "$R/personal/envrc" || fail "install must not overwrite personal/envrc"

"$WS_BIN" add personal "$WS_WORK/mine" > /dev/null
"$WS_BIN" new acme > /dev/null
"$WS_BIN" new globex you@globex.example > /dev/null

A="$R/acme"
[ "$(cat "$A/envrc")" = 'WS=acme; . "$HOME/.config/workspaces/isolated.sh"' ] || fail "envrc"
grep -q 'you@globex.example' "$R/globex/gitconfig" || fail "email"
[ "$(cat "$WS_WORK/acme/.envrc")" = 'source_env "$HOME/.config/workspaces/acme/envrc"' ] || fail ".envrc"
[ -d "$A/claude/skills/demo" ] || fail "skills copied"
[ -e "$A/claude/skills/linked" ] || fail "relative skill link must still resolve in the copy"
[ ! -e "$A/claude/.credentials.json" ] || fail "credentials must not be copied"
jq -e '.mcpServers.example and (.oauthAccount | not)' "$A/claude/.claude.json" > /dev/null || fail "mcp only"
jq -e '.auths | not' "$A/docker/config.json" > /dev/null || fail "docker logins stripped"
S="$A/claude/settings.json"
jq -e '.autoMemoryDirectory == "~/.config/workspaces/acme/memory"' "$S" > /dev/null || fail "memory dir"
jq -e '.permissions.additionalDirectories == ["~/.config/workspaces/acme/claude/plugins"]' "$S" > /dev/null || fail "personal paths rewritten (~)"
jq -e --arg c "$R/acme/claude/hooks/x.sh" '.hooks.Stop[0].command == $c' "$S" > /dev/null || fail "personal paths rewritten (abs)"
# paths are absolute, so "/$path" gives Claude's "//abs" form
for p in "Read(/$WS_WORK/mine/**)" "Read(/$WS_WORK/globex/**)" "Read(/$R/personal/**)" "Read(/$R/globex/**)" \
         "Read(/$HOME/.claude/**)" "Edit(/$HOME/.aws/**)" "Read(/$HOME/.config/gh/**)" "Read(/$HOME/.claude.json)"; do
  jq -e --arg p "$p" '.permissions.deny | index($p)' "$S" > /dev/null || fail "acme deny $p"
done
# globex was created after acme: its folder must be denied in acme and in personal
for f in "$S" "$HOME/.claude/settings.json"; do
  jq -e --arg p "Read(/$WS_WORK/globex/**)" '.permissions.deny | index($p)' "$f" > /dev/null || fail "deny globex in $f"
done
jq -e --arg p "Read(/$WS_WORK/mine/**)" '.permissions.deny | index($p) | not' "$HOME/.claude/settings.json" > /dev/null \
  || fail "personal must not deny its own folder"
[ "$(git config --global "includeIf.gitdir:$WS_WORK/acme/.path")" = "$A/gitconfig" ] || fail "includeIf"
git config --global "includeIf.gitdir:$WS_WORK/mine/.path" > /dev/null && fail "personal needs no includeIf"
"$WS_BIN" add acme "$WS_WORK/acme" > /dev/null || fail "re-add must be idempotent"
[ "$(grep -c "/acme$" "$A/folders")" = 1 ] || fail "folders deduped"
"$WS_BIN" add globex "$WS_WORK/acme" 2> /dev/null && fail "must refuse to steal a folder"
"$WS_BIN" new acme 2> /dev/null && fail "must refuse duplicate workspace"
"$WS_BIN" new personal 2> /dev/null && fail "personal is reserved"
grep -q '^globex$' <<< "$("$WS_BIN" list)" || fail "list"

# secrets/ files become env vars; personal gets nothing
printf 'tok123' > "$A/secrets/MY_TOKEN"
[ "$(WORKSPACE= bash -c '. "$HOME/.config/workspaces/acme/envrc"; echo "$WORKSPACE $MY_TOKEN $CLAUDE_CONFIG_DIR"')" = "acme tok123 $A/claude" ] || fail "isolated env"
[ -z "$(CLAUDE_CONFIG_DIR=/x bash -c '. "$HOME/.config/workspaces/personal/envrc"; echo "${CLAUDE_CONFIG_DIR:-}"')" ] || fail "personal unsets overrides"

# Claude Desktop: personal = default profile; every other workspace has its own launcher + profile
L="$HOME/.local/share/applications"
grep -q "^Exec=$WS_BIN desktop acme %U$" "$L/claude-acme.desktop" || fail "acme launcher"
grep -q MimeType "$L/claude-acme.desktop" && fail "launchers must not take claude:// links"
"$WS_BIN" launcher personal 2> /dev/null && fail "personal needs no launcher"
"$WS_BIN" desktop acme claude://x
[ "$(cat "$T/desktop.out")" = "acme $A/claude-desktop claude://x" ] || fail "desktop acme env"
CLAUDE_USER_DATA_DIR=/leak "$WS_BIN" desktop personal
[ "$(cat "$T/desktop.out")" = "personal default " ] || fail "desktop personal must use the default profile"
echo "selftest: OK"
