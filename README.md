# dotfiles

## Setup

### Packages, Tools and Symlinks

`mise/config.toml` is the machine-wide mise config. It declares CLI tools under
`[tools]`, the handful of packages Homebrew still has to provide under
`[bootstrap.packages]`, and the symlinks for `.gitconfig`, Zsh, Zed and Ghostty
under `[dotfiles]`.

mise itself is not managed by anything here. Install it on a fresh machine with
the [documented one-liner](https://mise.jdx.dev/getting-started.html), which
drops the binary in `~/.local/bin/mise`:

```bash
curl https://mise.run | sh
```

Homebrew is a separate prerequisite — nothing to do with installing mise, but
`[bootstrap.packages]` and `brew bundle` both shell out to it.

The config has to be symlinked to the global path, since a repo-local
`mise.toml` would only apply inside this directory:

```bash
ln -s /path/to/dotfiles/mise/config.toml ~/.config/mise/config.toml
```

Then set the machine up:

```bash
mise bootstrap    # [tools] + [bootstrap.packages] + [dotfiles]
brew bundle       # casks; mise cannot install those
```

Most tools resolve through mise's aqua backend, which reads the GitHub API.
This runs fine unauthenticated. If it ever starts failing on rate limits, log
in and re-run with a token — pass it explicitly, because mise reads the token
out of `~/.config/gh/hosts.yml` and finds nothing there when gh keeps it in the
macOS keyring:

```bash
gh auth login
GITHUB_TOKEN=$(gh auth token) mise bootstrap
```

Claude Code's symlinks are not covered by `[dotfiles]` and still need
`claude/sync-links.sh`; see below. The steps in the sections that follow are
the ones `mise bootstrap` cannot do for you.

### Git Configuration

This repository uses `.gitconfig.local` to keep personal information (name, email) out of version control.

After cloning, create `~/.gitconfig.local` based on the example:

```bash
cp .gitconfig.local.example ~/.gitconfig.local
# Then edit ~/.gitconfig.local with your actual name and email
```

Or create `~/.gitconfig.local` manually:

```gitconfig
[user]
    name = Your Name
    email = your.email@example.com
```

Verify the configuration:

```bash
git config --list | grep user
```

### Zsh

`zsh/zprofile` holds what a login shell needs — Homebrew and mise activation,
PATH entries and a few exports — and `mise bootstrap` links it to `~/.zprofile`.
`~/.zshrc` stays outside this repository: it is where machine-specific and
centrally managed blocks land.

Portable zsh settings (aliases, functions, keybindings) are managed in
`zsh/my.zsh`, which `mise bootstrap` links to `~/.my.zsh`. Add the following
line to the end of `~/.zshrc`:

```zsh
# Load portable zsh settings from dotfiles
source ~/.my.zsh
```

Included settings:
- **Aliases**: `g`, `gst`, `gd`, `gb`, `gf` (git), `ls`, `ll` (eza), `grep` (rg), `lzd` (lazydocker), `claude` (safety wrapper)
- **Functions**: `fzf_select_history`, `fzf-src`, `lg`
- **Keybindings**: `Ctrl+r` (history search), `Ctrl+]` (ghq selector), `Ctrl+g` (lazygit)

### Ghostty Terminal

Ghostty's configuration is managed in `ghostty/`, and `mise bootstrap` links it
into `~/Library/Application Support/com.mitchellh.ghostty/`. Back up any config
already sitting there first, then restart Ghostty to apply the configuration.

### Zed Editor

Zed's settings are managed in `zed/`, and `mise bootstrap` links them to
`~/.config/zed/settings.json`. Restart Zed to apply the configuration.

### Claude Code

Claude Code is not managed by mise either. It ships its own updater
(`claude update`) and keeps versioned builds under
`~/.local/share/claude/versions/`, so a version pinned here would be fighting
it. Install it on a fresh machine with the
[documented one-liner](https://code.claude.com/docs/en/setup), which leaves a
symlink at `~/.local/bin/claude`:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Claude Code's global configuration files are managed in `claude/`. The following files/directories are included:

- `CLAUDE.md` - Global instructions shared across machines
- `CLAUDE.local.md.example` - Template for machine-specific instructions
- `statusline-command.sh` - Custom status line script
- `agents/` - Custom subagent definitions
- `skills/` - Skill definitions, one directory each. A `.sync-ignore` marker means the skill is retired and deliberately not linked into `~/.claude/skills/`

Skills and subagents that are only worth having while working on this repository
live in `.claude/skills/` and `.claude/agents/` at the repository root instead.
Claude Code picks those up as project-scoped definitions when it runs here, and
`sync-links.sh` never sees them, so they stay out of every other project's skill
list. `skill-scout` and `daily-report` (with its `activity-reporter` subagent)
are there for that reason.

To set up the symlinks:

```bash
# Create symlinks for files
ln -sf /path/to/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf /path/to/dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh

# Create per-item symlinks for skills/agents
/path/to/dotfiles/claude/sync-links.sh
```

`CLAUDE.md` imports `~/.claude/CLAUDE.local.md` (via the `@path` syntax) for
machine-specific instructions that should stay out of version control, such as
constraints tied to one machine's environment. Create it from the example even
if you have nothing to put in it yet, so the import target always exists:

```bash
cp /path/to/dotfiles/claude/CLAUDE.local.md.example ~/.claude/CLAUDE.local.md
# Then edit ~/.claude/CLAUDE.local.md with machine-specific rules (or leave it empty)
```

`sync-links.sh` symlinks each skill/agent individually instead of linking
`~/.claude/skills`/`~/.claude/agents` as whole directories. This keeps them as
real directories on disk, so tools like `pnpm dlx skills add` can add their
own entries there without writing into this repo. Re-run the script after
adding a new skill or agent here — and after deleting one, since the script
also removes links that point at entries this repo no longer has. Links
pointing elsewhere (other repos, or entries added by external tools) are left
alone.

After creating the symlinks, restart Claude Code to apply the configuration.
