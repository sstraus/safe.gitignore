#!/usr/bin/env bash
# Global installation script for safe-gitignore
# Usage: curl -fsSL https://raw.githubusercontent.com/stefano/safe.gitignore/main/install.sh | bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die() { log_error "$@"; exit 1; }

# Default installation directory
INSTALL_DIR="${SAFE_GITIGNORE_INSTALL_DIR:-$HOME/.local/share/safe-gitignore}"
BIN_DIR="${SAFE_GITIGNORE_BIN_DIR:-$HOME/.local/bin}"

# Repository URL
REPO_URL="https://github.com/stefano/safe.gitignore.git"

print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     safe-gitignore installer          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     Backup sensitive files safely     ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""
}

check_requirements() {
    log_info "Checking requirements..."

    # Check for git
    if ! command -v git &> /dev/null; then
        die "git is required but not installed"
    fi

    # Check for bash version (need 4+ for associative arrays)
    local bash_version="${BASH_VERSION%%.*}"
    if [[ "$bash_version" -lt 4 ]]; then
        log_warn "Bash version $BASH_VERSION detected. Version 4+ recommended."
    fi

    log_success "Requirements satisfied"
}

install_from_git() {
    log_info "Installing safe-gitignore..."

    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"

    # Clone or update
    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        log_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull --quiet origin main
        cd - > /dev/null
    else
        log_info "Cloning repository..."
        rm -rf "$INSTALL_DIR"
        git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    fi

    # Create symlink in bin directory
    ln -sf "${INSTALL_DIR}/bin/safe-gitignore" "${BIN_DIR}/safe-gitignore"

    # Make executable
    chmod +x "${INSTALL_DIR}/bin/safe-gitignore"
    chmod +x "${INSTALL_DIR}/lib/common.sh"

    log_success "Installed to ${INSTALL_DIR}"
}

install_local() {
    log_info "Installing from local directory..."

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Create bin directory
    mkdir -p "$BIN_DIR"

    # Copy files
    mkdir -p "$INSTALL_DIR"
    cp -r "${script_dir}/bin" "$INSTALL_DIR/"
    cp -r "${script_dir}/lib" "$INSTALL_DIR/"

    # Create symlink
    ln -sf "${INSTALL_DIR}/bin/safe-gitignore" "${BIN_DIR}/safe-gitignore"

    # Make executable
    chmod +x "${INSTALL_DIR}/bin/safe-gitignore"
    chmod +x "${INSTALL_DIR}/lib/common.sh"

    log_success "Installed to ${INSTALL_DIR}"
}

check_path() {
    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        log_warn "${BIN_DIR} is not in your PATH"
        echo ""
        echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo ""
        echo -e "  ${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo ""
        echo "Then restart your shell or run:"
        echo ""
        echo -e "  ${GREEN}source ~/.bashrc${NC}  # or ~/.zshrc"
        echo ""
    fi
}

verify_installation() {
    log_info "Verifying installation..."

    if [[ -x "${BIN_DIR}/safe-gitignore" ]]; then
        log_success "safe-gitignore installed successfully!"
        echo ""
        echo "Usage:"
        echo "  cd your-project"
        echo "  safe-gitignore init     # Create config file"
        echo "  safe-gitignore install  # Install post-commit hook"
        echo "  safe-gitignore status   # Show files to backup"
        echo ""
        echo "For more information: safe-gitignore help"
    else
        die "Installation verification failed"
    fi
}

uninstall() {
    log_info "Uninstalling safe-gitignore..."

    rm -f "${BIN_DIR}/safe-gitignore"
    rm -rf "$INSTALL_DIR"

    log_success "Uninstalled safe-gitignore"
    echo ""
    echo "Note: This does not remove:"
    echo "  - Config files (.safe-gitignore.conf) in your projects"
    echo "  - Git hooks installed in your projects"
    echo "  - Backup cache (~/.cache/safe-gitignore)"
    echo ""
    echo "To fully clean up, run these commands manually if needed:"
    echo "  rm -rf ~/.cache/safe-gitignore"
}

show_help() {
    cat << 'EOF'
safe-gitignore installer

USAGE:
    ./install.sh [options]

OPTIONS:
    --local         Install from local directory instead of cloning
    --uninstall     Remove safe-gitignore
    --help          Show this help message

ENVIRONMENT VARIABLES:
    SAFE_GITIGNORE_INSTALL_DIR  Installation directory
                                (default: ~/.local/share/safe-gitignore)
    SAFE_GITIGNORE_BIN_DIR      Binary directory
                                (default: ~/.local/bin)

EXAMPLES:
    # Install from GitHub
    ./install.sh

    # Install from local copy
    ./install.sh --local

    # Install to custom location
    SAFE_GITIGNORE_BIN_DIR=/usr/local/bin ./install.sh --local

    # Uninstall
    ./install.sh --uninstall
EOF
}

main() {
    local mode="git"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                mode="local"
                shift
                ;;
            --uninstall)
                mode="uninstall"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    print_banner

    case "$mode" in
        git)
            check_requirements
            install_from_git
            check_path
            verify_installation
            ;;
        local)
            check_requirements
            install_local
            check_path
            verify_installation
            ;;
        uninstall)
            uninstall
            ;;
    esac
}

main "$@"
