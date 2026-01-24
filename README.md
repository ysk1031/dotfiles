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
