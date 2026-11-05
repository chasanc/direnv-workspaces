# How-to: workspaces

**personal** uses every tool's default location (`~/.claude`, `~/.claude.json`, `~/.config/gh`, `~/.aws`, `~/.docker`, `~/.kube`).
Every other workspace is isolated under `~/.config/workspaces/<name>/` and applies only inside its folder `$WS_WORK/<name>` (default `~/work/<name>`).
`<name>` is letters and digits only (e.g. `acme`).

## Quick reference
| I want to… | Command / section |
|---|---|
| see which workspace I'm in | `ws` (A) |
| see all workspaces and their folders | `ws list` |
| add a new workspace | `ws new acme you@acme.com` (B) |
| put another folder into a workspace | `ws add acme ~/clients/acme` (C) |
| give a workspace its own Claude account | D |
| isolate one more CLI tool | E |
| remove a workspace | F |
| fix something that looks wrong | G |

Files involved:
```
~/.local/bin/ws                         # helper (source: bin/ws)
~/.config/workspaces/isolated.sh        # shared env for every non-personal workspace
~/.config/workspaces/shell-hook.sh      # sourced from your shell rc by install.sh
~/.config/workspaces/<name>/envrc       # the workspace's env
~/.config/workspaces/<name>/gitconfig   # git email + SSH key
~/.config/workspaces/<name>/secrets/    # one file per env var (chmod 600)
~/.config/workspaces/<name>/folders     # folders linked to the workspace (written by ws add)
<folder>/.envrc                         # one line that links a folder to its workspace
~/.gitconfig                            # includeIf lines (folder → gitconfig), written by ws add
```

---

## A. Which workspace am I in?
- The prompt shows `[acme]` (bash) or a yellow tag on the right (zsh).
- `ws` prints the workspace, where each tool points, and the git email.
- In Claude: `/status` shows the account.

## B. Add a new workspace
```bash
ws new acme you@acme.com      # email optional; a placeholder is used if omitted
```
This creates `~/work/acme` and `~/.config/workspaces/acme/` with a gitconfig and empty config dirs.
Claude in that folder gets personal's skills, hooks, settings, MCPs and plugins (copied from `~/.claude`, with `~/.claude/` paths rewritten), with its **own** memory and no credentials.

**Deny rules.** `ws new` and `ws add` add `permissions.deny` entries (`Read(...)`/`Edit(...)`) to the Claude settings so that:
- acme's Claude can't read personal's default locations (`~/.claude`, `~/.claude.json`, `~/.config/gh`, `~/.aws`, `~/.docker`, `~/.kube`) or any other workspace's folders and config dir;
- every other workspace's Claude (and personal's) can't read acme's folders or config dir.

Then do what it prints, in a terminal inside `~/work/acme`:
1. `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_acme` and add the `.pub` key to the git host
2. `claude`: log in (with your personal account until you have a separate one; see D)
3. `gh auth login`, `aws configure` (or `aws configure sso`)
4. Optional env tokens, one file per variable, `chmod 600`: `~/.config/workspaces/acme/secrets/NPM_TOKEN`
   (e.g. `install -m 600 /dev/stdin ~/.config/workspaces/acme/secrets/NPM_TOKEN`, paste, Ctrl-D)
5. Skip any tool you don't use there. With no login there, it has no credentials, which is safer than silently using personal.
6. In your editor, open the folder (or a repo inside it) in its own window. VS Code-based editors need a direnv extension (e.g. `mkhl.direnv`).
7. Claude Desktop (if you use it on Linux): app menu → "Claude (acme)". Never use the plain "Claude" icon for acme work; that one is personal.
8. Check: `ws` in a new terminal inside the folder.

## C. Put another folder into an existing workspace
```bash
ws add acme ~/clients/acme
```
This writes the `.envrc`, allows it, adds the git `includeIf` and blocks the folder in every other workspace's Claude.
- Subfolders inherit it. A repo inside with its **own** `.envrc` must start with `source_up` to keep the workspace.
- `ws` refuses a folder that already has another workspace's `.envrc`. Change that by hand on purpose.

## D. Give a workspace its own Claude account
In a terminal inside one of its folders: `claude` → `/logout` → `/login` with the other account. Nothing else is needed, because the folder already has its own config dir.
Do the same in "Claude (acme)" (Desktop) if you use it.

## E. Isolate one more CLI tool
1. Find the tool's env var for its config dir or token (`<tool> --help`, its docs).
2. Config dir → add an `export X="$W/<tool>"` line to **`~/.config/workspaces/isolated.sh`** (all non-personal workspaces).
   Single token → just drop a file named like the variable into `<ws>/secrets/`. No code change.
3. Add the variable to the `unset` line in **`~/.config/workspaces/personal/envrc`**, so personal keeps using the tool's default location.
4. Move any existing login for that tool out of its default location into `<ws>/<tool>` (quit the tool first), so personal starts clean.
5. Run `direnv reload` in open terminals. direnv doesn't watch `isolated.sh`.
6. Optional: add the variable to the `for v in …` list in `ws` (`cmd_status`) so `ws` shows it.

Known variables: `CLOUDSDK_CONFIG` (gcloud), `AZURE_CONFIG_DIR` (az), `GOOGLE_APPLICATION_CREDENTIALS`, `OPENAI_API_KEY` (single tokens → `secrets/`).
Never put secrets in `.bashrc`, `.envrc` or a repo.

**Tools with no env var for their logins** (they hardcode `$HOME/.something`) can be wrapped: put a script named like the tool in a directory that comes first on `PATH`, and have it run the real binary with `HOME=<ws>/home-for-tool`. Use sparingly; most tools have an env var.

## F. Remove a workspace (manual on purpose)
```bash
N=acme
# 1. log out first so tokens are revoked: inside an acme folder run `claude` → /logout, then gh auth logout
# 2. unlink its folders
while read -r d; do rm "$d/.envrc"; git config --global --unset "includeIf.gitdir:$d/.path"; done < ~/.config/workspaces/$N/folders
rm -f ~/.local/share/applications/claude-$N.desktop   # Desktop launcher (log out in the app first)
# 3. archive (don't just delete) the config
tar czf ~/workspace-$N-$(date +%F).tgz -C ~/.config/workspaces $N
rm -r ~/.config/workspaces/$N ~/.cache/workspaces/$N
```
The deny rules for its folders stay in the other workspaces' settings. They're harmless, or you can delete them from `permissions.deny`.

## G. Troubleshooting
| Symptom | Cause / fix |
|---|---|
| `direnv: error .envrc is blocked` | `direnv allow` in that folder (needed again after you edit the `.envrc`) |
| `ws new` says "personal workspace missing" | Run `./install.sh` first |
| `ws: command not found` | Add `~/.local/bin` to your `PATH` |
| An editor terminal or the Claude extension shows the wrong account | Reload the direnv extension ("direnv: Reset and reload"). Open the workspace folder itself, not `~` or a multi-root window that mixes workspaces |
| An editor with no folder open acts as personal | Expected: it reads your shell setup at start. Open a workspace folder for that work |
| `git push` uses the wrong key or email | `git config --show-origin user.email` in the repo. The `includeIf` path must end with `/`, and the repo must be under that folder (symlinks: use the real path) |
| `gh` returns 403 inside a workspace | A token env var leaked in: `GITHUB_TOKEN= gh auth status` in the folder, then `gh auth login` again |
| A change in `isolated.sh` isn't applied | `direnv reload` or open a new terminal |
| `ws new` reports a plugin or marketplace failure | Run it later inside the folder: `claude plugin install <plugin>@<marketplace>` |
| You edited `ws` | Run `test/selftest.sh` (uses a throwaway HOME; touches nothing real) |
| Claude Desktop "Code" sessions show the wrong memory or plugins | The app was started some other way. Quit it and use the menu entry, or `ws desktop <name>` |
| A `claude://` link opened personal | Expected: links always open the normal (personal) app |
| npm ignores the workspace's npmrc | A `.npmrc` in `~` or a parent folder counts as "project" config and wins over the user config: `npm config list` shows which file is used. Keep `~/.npmrc` absent |
| A personal repo inside a workspace folder pushes with that workspace's key | Pin it in the repo: `git config core.sshCommand "ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes"` |
| A workspace's Claude is denied its own files, or runs personal's hooks | It was started with cwd `~`: Claude then loads `~/.claude/settings.json` (personal's) as *project* settings on top. Start Claude **inside** the workspace folder; `direnv exec <folder> claude` from `~` is not enough |
| git over https in another workspace authenticates as the wrong GitHub user | gh's keyring fallback: with no login in a config dir, `gh auth git-credential` hands out the token stored in the OS keyring. Fix: log in with `gh auth login --insecure-storage` in each workspace, then clear the keyring entry (`secret-tool clear service gh:github.com`) |
