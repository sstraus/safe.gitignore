# safe-gitignore

Automatically backup sensitive gitignored files to a private repository.

## The Problem

Your `.gitignore` excludes sensitive files like `.env`, API keys, and config files from version control—but what happens if your disk fails or you need to set up a new machine?

## The Solution

**safe-gitignore** adds a post-commit hook that automatically syncs files tagged with `#safe` in your `.gitignore` to a private backup repository.

```gitignore
# .gitignore
.env #safe
config/secrets.yml #safe
*.key #safe
node_modules/
```

Every time you commit, files tagged with `#safe` are silently backed up.

## Installation

```bash
# Clone and install
git clone https://github.com/stefano/safe.gitignore.git
cd safe.gitignore
./install.sh --local

# Or one-liner from GitHub (once published)
# curl -fsSL https://raw.githubusercontent.com/stefano/safe.gitignore/main/install.sh | bash
```

Make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Quick Start

1. **Create a private backup repository** on GitHub/GitLab/etc.

2. **Initialize safe-gitignore in your project:**
   ```bash
   cd your-project
   safe-gitignore init
   ```

3. **Edit `.safe-gitignore.conf`:**
   ```ini
   SAFE_REMOTE=git@github.com:yourusername/secrets-backup.git
   ```

4. **Tag files in your `.gitignore`:**
   ```gitignore
   .env #safe
   config/database.yml #safe
   credentials.json #safe
   ```

5. **Install the hook:**
   ```bash
   safe-gitignore install
   ```

6. **Done!** Files are backed up automatically on every commit.

## Commands

| Command | Description |
|---------|-------------|
| `safe-gitignore init` | Create config file in current project |
| `safe-gitignore install` | Install post-commit hook |
| `safe-gitignore uninstall` | Remove post-commit hook |
| `safe-gitignore status` | Show files that would be backed up |
| `safe-gitignore backup` | Manually trigger a backup |
| `safe-gitignore help` | Show help |

## Configuration

Create `.safe-gitignore.conf` in your project root:

```ini
# Required: URL of your private backup repository
SAFE_REMOTE=git@github.com:username/secrets-backup.git

# Optional: Project name in backup repo (default: directory name)
SAFE_PROJECT_NAME=my-project

# Optional: Custom commit message
# Variables: $PROJECT, $DATE, $FILES
SAFE_COMMIT_MSG="Backup $PROJECT: $DATE"
```

## Backup Repository Structure

Your backup repository will have this structure:

```
secrets-backup/
├── README.md
├── project-one/
│   ├── .env
│   └── config/
│       └── secrets.yml
├── project-two/
│   ├── .env
│   └── credentials.json
└── project-three/
    └── .env
```

Each project gets its own subdirectory, preserving the original file structure.

## Security Notes

- **Use SSH keys** for authentication (don't store passwords)
- **Keep your backup repo private**
- Files are stored as-is (not encrypted). For encryption, use a tool like `git-crypt` on the backup repo
- The hook runs silently; check `safe-gitignore status` to verify what's being backed up

## How It Works

1. You commit code in your project
2. Git's post-commit hook triggers
3. safe-gitignore parses `.gitignore` for `#safe` tags
4. Tagged files are copied to a local cache
5. Changes are committed and pushed to your backup repo

The backup happens silently in the background. Network failures don't block your workflow—changes queue up for the next commit.

## Troubleshooting

**Files not backing up?**
```bash
safe-gitignore status  # Check what files are tagged
```

**Hook not running?**
```bash
ls -la .git/hooks/post-commit  # Check hook exists
safe-gitignore install          # Reinstall if needed
```

**Push failing?**
```bash
# Check SSH key
ssh -T git@github.com

# Manual backup with verbose output
safe-gitignore backup
```

## Uninstall

```bash
# Remove from a project
safe-gitignore uninstall

# Remove globally
~/.local/share/safe-gitignore/install.sh --uninstall

# Clean up cache
rm -rf ~/.cache/safe-gitignore
```

## License

MIT
