#!/bin/bash
set -eo pipefail

# --- Configuration ---
: "${GIT_REPO_URL:=https://github.com/BOTOOM/windsurf-bin-arch.git}"
: "${CLONED_REPO_DIR_NAME:=windsurf-bin-arch}"
: "${PKGBUILD_SUBDIR:=package}"
: "${WINDSURF_PKG_NAME:=windsurf-bin}"

# --- Helper Functions ---
log() {
    echo "[INFO] $(date +'%T') - $1"
}

error_exit() {
    echo "[ERROR] $(date +'%T') - $1" >&2
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "Required command '$1' not found. Please install it."
}

get_installed_version() {
    local pkg_name="$1"
    if pacman -Q "$pkg_name" &>/dev/null; then
        pacman -Q "$pkg_name" | awk '{print $2}'
    else
        echo "" # Not installed
    fi
}

get_pkgbuild_version() {
    local pkgbuild_file="$1"
    if [ ! -f "$pkgbuild_file" ]; then
        error_exit "PKGBUILD file not found at $pkgbuild_file"
    fi
    (
        # shellcheck source=/dev/null
        source "$pkgbuild_file"
        if [ -z "${pkgver:-}" ] || [ -z "${pkgrel:-}" ]; then
            error_exit "pkgver or pkgrel not defined in $pkgbuild_file"
        fi
        echo "${pkgver}-${pkgrel}"
    )
}

# --- Main Script Logic ---
main() {
    log "Starting Windsurf Local Installer..."
    check_command "git"
    check_command "makepkg"
    check_command "pacman"

    # Navigate to package directory
    BUILD_DIR="$PWD/$PKGBUILD_SUBDIR"
    if [ ! -d "$BUILD_DIR" ]; then
        error_exit "Build directory not found: $BUILD_DIR"
    fi

    cd "$BUILD_DIR"

    # Check Versions
    PKGBUILD_VERSION=$(get_pkgbuild_version "PKGBUILD")
    INSTALLED_VERSION=$(get_installed_version "$WINDSURF_PKG_NAME")
    
    log "Version available in repo: $PKGBUILD_VERSION"

    PROCEED_WITH_BUILD=false

    if [ -n "$INSTALLED_VERSION" ]; then
        log "Currently installed version: $INSTALLED_VERSION"
        
        if [ "$INSTALLED_VERSION" == "$PKGBUILD_VERSION" ]; then
            printf "%s version %s is already installed and up-to-date. Reinstall anyway? (y/N): " "$WINDSURF_PKG_NAME" "$PKGBUILD_VERSION" >&2
            read -r reinstall_choice </dev/tty
            if [[ "$reinstall_choice" =~ ^[Yy]$ ]]; then
                PROCEED_WITH_BUILD=true
            else
                log "Exiting without reinstallation."
            fi
        else
            # Version differs (upgrade or downgrade)
            printf "Do you want to build and install version %s? (Y/n): " "$PKGBUILD_VERSION" >&2
            read -r upgrade_choice </dev/tty
            if [[ ! "$upgrade_choice" =~ ^[Nn]$ ]]; then # Default to Yes
                PROCEED_WITH_BUILD=true
            else
                log "Exiting without building new version."
            fi
        fi
    else
        log "$WINDSURF_PKG_NAME is not currently installed."
        printf "Install %s version %s? (Y/n): " "$WINDSURF_PKG_NAME" "$PKGBUILD_VERSION" >&2
        read -r install_new_choice </dev/tty
        if [[ ! "$install_new_choice" =~ ^[Nn]$ ]]; then # Default to Yes
            PROCEED_WITH_BUILD=true
        else
            log "Exiting without installation."
        fi
    fi

    if [ "$PROCEED_WITH_BUILD" = false ]; then
        exit 0
    fi
    
    log "Building and installing package..."
    # Using --noconfirm for automated build phases, but pacman might still ask for sudo password via tty
    if ! makepkg -si --noconfirm --needed </dev/tty; then
        error_exit "Installation failed."
    fi

    log "Installation successful!"
}

main
