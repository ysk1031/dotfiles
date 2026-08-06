# dotfiles

## Setup

### Git Configuration

This repository uses `.gitconfig.local` to keep personal information (name, email) out of version control.

To set up the symlink:

```bash
ln -sf /path/to/dotfiles/.gitconfig ~/.gitconfig
```

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

Portable zsh settings (aliases, functions, keybindings) are managed in `my.zsh`. To set up the symlink:

```bash
ln -s /path/to/dotfiles/my.zsh ~/.my.zsh
```

Then add the following line to the end of `~/.zshrc`:

```zsh
# Load portable zsh settings from dotfiles
source ~/.my.zsh
```

Included settings:
- **Aliases**: `g`, `gst`, `gd`, `gb`, `gf` (git), `ls`, `ll` (eza), `grep` (rg), `lzd` (lazydocker), `claude` (safety wrapper)
- **Functions**: `peco_select_history`, `peco-src`, `lg`
- **Keybindings**: `Ctrl+r` (history search), `Ctrl+]` (ghq selector), `Ctrl+g` (lazygit)

### Ghostty Terminal

Ghostty's configuration is managed in this repository. To set up the symlink:

```bash
# Backup existing config (if not already done)
mv ~/Library/Application\ Support/com.mitchellh.ghostty/config \
   ~/Library/Application\ Support/com.mitchellh.ghostty/config.backup

# Create symlink
ln -s /path/to/dotfiles/ghostty/config \
      ~/Library/Application\ Support/com.mitchellh.ghostty/config
```

After creating the symlink, restart Ghostty to apply the configuration.

### Zed Editor

Zed's settings are managed in `zed/`. To set up the symlink:

```bash
# Create config directory if it doesn't exist
mkdir -p ~/.config/zed

# Create symlink
ln -sf /path/to/dotfiles/zed/settings.json ~/.config/zed/settings.json
```

After creating the symlink, restart Zed to apply the configuration.

### Claude Code

Claude Code's global configuration files are managed in `claude/`. The following files/directories are included:

- `CLAUDE.md` - Global instructions shared across machines
- `CLAUDE.local.md.example` - Template for machine-specific instructions
- `statusline-command.sh` - Custom status line script
- `agents/` - Custom subagent definitions
- `skills/` - Skill definitions, one directory each. A `.sync-ignore` marker means the skill is retired and deliberately not linked into `~/.claude/skills/`
- `docs/` - Reference documentation for skills

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
adding a new skill or agent here.

After creating the symlinks, restart Claude Code to apply the configuration.
