# dotfiles

## Setup

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

### Claude Code

Claude Code's configuration files are managed in this repository. The following files/directories are included:

- `settings.json` - Main settings (language, permissions, hooks, plugins)
- `statusline-command.sh` - Custom status line script
- `commands/` - Custom command definitions
- `skills/` - Skill definitions (commit, pr, weekly-report)

To set up the symlinks:

```bash
# Create symlinks for files
ln -sf /path/to/dotfiles/.claude/settings.json ~/.claude/settings.json
ln -sf /path/to/dotfiles/.claude/statusline-command.sh ~/.claude/statusline-command.sh

# Create symlinks for directories
ln -sf /path/to/dotfiles/.claude/commands ~/.claude/commands
ln -sf /path/to/dotfiles/.claude/skills ~/.claude/skills
```

After creating the symlinks, restart Claude Code to apply the configuration.
