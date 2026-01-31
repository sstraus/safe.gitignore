#!/usr/bin/env bash
# common.sh - Shared functions for safe-gitignore
# shellcheck disable=SC2034

set -euo pipefail

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Configuration
CONFIG_FILE=".safe-gitignore.conf"
SAFE_TAG="#safe"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    log_error "$@"
    exit 1
}

# Check if we're in a git repository
require_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        die "Not a git repository. Run 'git init' first."
    fi
}

# Get the root directory of the git repository
get_git_root() {
    git rev-parse --show-toplevel
}

# Check if config file exists
has_config() {
    local git_root
    git_root=$(get_git_root)
    [[ -f "${git_root}/${CONFIG_FILE}" ]]
}

# Read a config value
read_config() {
    local key="$1"
    local default="${2:-}"
    local git_root
    git_root=$(get_git_root)
    local config_path="${git_root}/${CONFIG_FILE}"

    if [[ -f "$config_path" ]]; then
        # Source the config file and echo the value
        # Use set +u to allow unset variables in config (like $DATE template)
        # shellcheck disable=SC1090
        (set +u; source "$config_path" && eval "echo \${${key}:-${default}}")
    else
        echo "$default"
    fi
}

# Parse .gitignore and extract patterns tagged with #safe
# Output: one pattern per line (without the #safe tag)
parse_safe_patterns() {
    local gitignore_path="$1"

    if [[ ! -f "$gitignore_path" ]]; then
        return 0
    fi

    # Extract lines ending with #safe, remove the tag and trailing whitespace
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comment-only lines
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && ! [[ "$line" =~ \#safe[[:space:]]*$ ]] && continue

        # Check if line ends with #safe
        if [[ "$line" =~ ^(.+)[[:space:]]*\#safe[[:space:]]*$ ]]; then
            local pattern="${BASH_REMATCH[1]}"
            # Trim trailing whitespace from pattern
            pattern="${pattern%"${pattern##*[![:space:]]}"}"
            echo "$pattern"
        fi
    done < "$gitignore_path"
}

# Find files matching a gitignore-style pattern
# Uses find with pattern translation for simple cases
find_matching_files() {
    local pattern="$1"
    local base_dir="$2"

    # Handle different pattern types
    if [[ "$pattern" == *"**"* ]]; then
        # Recursive glob pattern - convert to find
        local find_pattern="${pattern//\*\*/}"
        find_pattern="${find_pattern//\*/}"
        find "$base_dir" -type f -name "*${find_pattern}*" 2>/dev/null || true
    elif [[ "$pattern" == *"/"* ]]; then
        # Path-based pattern
        # Check if it's a file that exists
        local full_path="${base_dir}/${pattern}"
        if [[ -f "$full_path" ]]; then
            echo "$full_path"
        elif [[ -d "$full_path" ]]; then
            # Directory - list all files within
            find "$full_path" -type f 2>/dev/null || true
        else
            # Try glob expansion
            # shellcheck disable=SC2086
            local expanded
            expanded=$(cd "$base_dir" && ls -d $pattern 2>/dev/null || true)
            for f in $expanded; do
                [[ -f "${base_dir}/${f}" ]] && echo "${base_dir}/${f}"
            done
        fi
    elif [[ "$pattern" == *"*"* ]]; then
        # Simple glob pattern
        # shellcheck disable=SC2086
        local expanded
        expanded=$(cd "$base_dir" && ls -d $pattern 2>/dev/null || true)
        for f in $expanded; do
            [[ -f "${base_dir}/${f}" ]] && echo "${base_dir}/${f}"
        done
    else
        # Literal filename
        local full_path="${base_dir}/${pattern}"
        [[ -f "$full_path" ]] && echo "$full_path"
    fi
}

# Get list of all files to backup based on .gitignore #safe tags
get_safe_files() {
    local git_root
    git_root=$(get_git_root)
    local gitignore_path="${git_root}/.gitignore"

    local patterns
    patterns=$(parse_safe_patterns "$gitignore_path")

    if [[ -z "$patterns" ]]; then
        return 0
    fi

    # Collect unique files
    local files=()
    while IFS= read -r pattern; do
        while IFS= read -r file; do
            [[ -n "$file" ]] && files+=("$file")
        done < <(find_matching_files "$pattern" "$git_root")
    done <<< "$patterns"

    # Output unique files (relative to git root)
    printf '%s\n' "${files[@]}" | sort -u | while read -r f; do
        # Convert to relative path
        echo "${f#"${git_root}/"}"
    done
}

# Validate remote repository URL
validate_remote_url() {
    local url="$1"

    # Basic validation - must be SSH or HTTPS git URL
    if [[ "$url" =~ ^git@.*:.*\.git$ ]] || [[ "$url" =~ ^https://.*\.git$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get project name (for subdirectory in backup repo)
get_project_name() {
    local configured_name
    configured_name=$(read_config "SAFE_PROJECT_NAME" "")

    if [[ -n "$configured_name" ]]; then
        echo "$configured_name"
    else
        # Use directory name
        basename "$(get_git_root)"
    fi
}

# Get the backup working directory
get_backup_workdir() {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/safe-gitignore"
    local remote
    remote=$(read_config "SAFE_REMOTE" "")

    if [[ -z "$remote" ]]; then
        die "SAFE_REMOTE not configured. Run 'safe-gitignore init' first."
    fi

    # Create a safe directory name from the remote URL
    local safe_name
    safe_name=$(echo "$remote" | sed 's/[^a-zA-Z0-9]/_/g')

    echo "${cache_dir}/${safe_name}"
}
