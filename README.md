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
