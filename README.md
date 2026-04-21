# safe-gitignore

Automatically backup sensitive gitignored files to a private repository.

## The Problem

Your `.gitignore` excludes sensitive files like `.env`, API keys, and config files from version control—but what happens if your disk fails or you need to set up a new machine?

## The Solution

**safe-gitignore** adds a post-commit hook that automatically syncs sensitive files to a private backup repository. Mark which files to backup using either method:

### Option 1: `# safe` comments in `.gitignore`

Add a `# safe` comment on the line above the pattern:

```gitignore
# .gitignore
# safe
.env
# safe
config/secrets.yml
# safe
*.key
node_modules/
```

### Option 2: `.safeignore` file

Create a `.safeignore` file listing the patterns to backup (same syntax as `.gitignore`):

```
# .safeignore
.env
config/secrets.yml
*.key
```

Both methods can be used together — patterns are merged and deduplicated.

Every time you commit, marked files are silently backed up.

## Installation

```bash
# Clone and install
git clone https://github.com/sstraus/safe.gitignore.git
cd safe.gitignore
./install.sh --local

# Or one-liner from GitHub
# curl -fsSL https://raw.githubusercontent.com/sstraus/safe.gitignore/main/install.sh | bash
```

Make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Quick Start

### One-time setup (global config)

1. **Create a private backup repository** on GitHub/GitLab/etc.

2. **Initialize global config:**
   ```bash
   safe-gitignore config --init
   ```

3. **Edit the global config:**
   ```bash
   safe-gitignore config --edit
   # Set SAFE_REMOTE to your backup repo URL
   ```

### Per-project setup

1. **Mark files for backup** using either method:

   In `.gitignore`:
   ```gitignore
   # safe
   .env
   # safe
   config/database.yml
   ```

   Or in `.safeignore`:
   ```
   .env
   config/database.yml
   credentials.json
   ```

2. **Install the hook:**
   ```bash
   cd your-project
   safe-gitignore install
   ```

3. **Done!** Files are backed up automatically on every commit.

## Commands

| Command | Description |
|---------|-------------|
| `safe-gitignore config --init` | Create global config file |
| `safe-gitignore config --edit` | Edit global config |
| `safe-gitignore config` | Show global config status |
| `safe-gitignore init` | Create local config (optional, overrides global) |
| `safe-gitignore install` | Install post-commit hook |
| `safe-gitignore uninstall` | Remove post-commit hook |
| `safe-gitignore status` | Show files that would be backed up |
| `safe-gitignore backup` | Manually trigger a backup |
| `safe-gitignore encrypt-setup` | Set up git-crypt encryption in backup repo |
| `safe-gitignore help` | Show help |

## Configuration

### Global Config (recommended)

Set once, use in all projects:

```bash
safe-gitignore config --init
safe-gitignore config --edit
```

Location: `~/.config/safe-gitignore/config`

```ini
# Required: URL of your private backup repository
SAFE_REMOTE=git@github.com:username/secrets-backup.git

# Optional: Custom commit message
SAFE_COMMIT_MSG="Backup $PROJECT: $DATE"
```

### Local Config (optional)

Override global settings for a specific project by creating `.safe-gitignore.conf` in the project root:

```ini
# Override remote for this project only
SAFE_REMOTE=git@github.com:username/different-backup.git

# Project name in backup repo (default: directory name)
SAFE_PROJECT_NAME=my-project
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

## Encryption (Optional)

For additional security, encrypt your backup repository with git-crypt:

```bash
# Set up encryption (one-time)
safe-gitignore encrypt-setup

# Add yourself as a trusted GPG user
cd ~/.cache/safe-gitignore/<your-backup-repo>
git-crypt add-gpg-user YOUR_GPG_KEY_ID
```

All files (except README.md) will be encrypted. To access backups on another machine:

```bash
# With GPG key
git clone <backup-repo> && cd <backup-repo>
git-crypt unlock

# Or with symmetric key
git-crypt unlock /path/to/exported.key
```

## Security Notes

- **Use SSH keys** for authentication (don't store passwords)
- **Keep your backup repo private**
- **Enable encryption** with `safe-gitignore encrypt-setup` for sensitive data
- The hook runs silently; check `safe-gitignore status` to verify what's being backed up

## How It Works

1. You commit code in your project
2. Git's post-commit hook triggers
3. safe-gitignore parses `.gitignore` for `# safe` markers and reads `.safeignore`
4. Matched files are copied to a local cache
5. Changes are committed and pushed to your backup repo

The backup happens silently in the background. Network failures don't block your workflow—changes queue up for the next commit.

## Migration from v1.x

If you used the old inline `#safe` syntax (e.g., `.env #safe`), you need to update your `.gitignore` files. The old syntax was not valid git — git treated `.env #safe` as a literal pattern, meaning your files were **not actually being ignored**.

**Before (broken):**
```gitignore
.env #safe
```

**After (option A — comment above):**
```gitignore
# safe
.env
```

**After (option B — separate file):**
```
# .safeignore
.env
```

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

**Check config:**
```bash
safe-gitignore config  # Show global config
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
