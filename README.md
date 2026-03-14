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

- `settings.json` - Main settings (language, permissions, hooks, plugins)
- `statusline-command.sh` - Custom status line script
- `agents/` - Custom subagent definitions
- `skills/` - Skill definitions (commit, pr, weekly-report)
- `docs/` - Reference documentation for skills

To set up the symlinks:

```bash
# Create symlinks for files
ln -sf /path/to/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf /path/to/dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh

# Create symlinks for directories (use -n to replace existing dirs)
ln -sfn /path/to/dotfiles/claude/skills ~/.claude/skills
ln -sfn /path/to/dotfiles/claude/agents ~/.claude/agents
```

After creating the symlinks, restart Claude Code to apply the configuration.
