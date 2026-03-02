#!/bin/bash

set -x  # Enable debug output

# Set up temporary directory
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Download and set up the repository key
curl -fsSL "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" -o "$TEMP_DIR/windsurf.gpg"

# Add the key to apt's trusted keys
cat "$TEMP_DIR/windsurf.gpg" | gpg --batch --yes --dearmor -o "/usr/share/keyrings/windsurf-archive-keyring.gpg"

# Create sources list
echo "deb [signed-by=/usr/share/keyrings/windsurf-archive-keyring.gpg arch=amd64] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | tee /etc/apt/sources.list.d/windsurf.list > /dev/null

# Update package lists for the repository
apt-get update > /dev/null 2>&1

# Get package version
# Try different package names if needed
PACKAGE_NAME="windsurf"
VERSION=$(apt-cache madison "$PACKAGE_NAME" | head -n1 | awk '{ print $3 }' | cut -d'-' -f1)

# If version is empty, try alternative names
if [ -z "$VERSION" ]; then
    # Could try other package names here if needed
    echo "Failed to get version for $PACKAGE_NAME" >&2
    exit 1
fi

if [ -n "$VERSION" ]; then
    # Construct DEB URL dynamically
    DEB_URL="https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt/pool/main/w/windsurf/Windsurf-linux-x64-${VERSION}.deb"
    
    # Verify that the deb file exists
    if curl --output /dev/null --silent --head --fail "$DEB_URL"; then
        # Download the DEB file to calculate SHA256 sum
        DEB_FILE="$TEMP_DIR/Windsurf-linux-x64-${VERSION}.deb"
        if curl --silent --output "$DEB_FILE" "$DEB_URL"; then
            # Calculate SHA256 sum
            SHA256SUM=$(sha256sum "$DEB_FILE" | awk '{print $1}')
            # Output version, SHA256 sum, and URL
            printf "%s %s %s" "$VERSION" "$SHA256SUM" "$DEB_URL"
            exit 0
        else
            echo "Failed to download DEB package from $DEB_URL" >&2
            exit 1
        fi
    else
        echo "Deb package not found at $DEB_URL" >&2
        exit 1
    fi
else
    echo "Failed to get version. Package not found?" >&2
    apt-cache search windsurf >&2
    exit 1
fi
