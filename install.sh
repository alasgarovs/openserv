#!/bin/bash

set -e

echo "[*] Installing openserv..."

INSTALL_DIR="$HOME/.openserv"
BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/openserv"
SOURCE_SCRIPT="$INSTALL_DIR/bin/openserv.sh"

# Detect shell config file
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

# Create install directory and copy files
mkdir -p "$INSTALL_DIR"
cp -r src/. "$INSTALL_DIR/"

# Ensure main script is executable
chmod +x "$SOURCE_SCRIPT"

# Ensure local bin exists
mkdir -p "$BIN_DIR"

# Create or update symlink
ln -sfn "$SOURCE_SCRIPT" "$TARGET"

# Add ~/.local/bin to PATH if missing
if ! grep -q '\.local/bin' "$SHELL_RC"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo "[*] Added ~/.local/bin to PATH in $SHELL_RC"
fi

echo "[✓] Installation complete!"
echo ""
echo "Run with:"
echo "  openserv"
echo ""

# Check if command is immediately available
if command -v openserv >/dev/null 2>&1; then
    echo "[✓] openserv is ready to use!"
else
    echo "[!] It may not be available yet."
    echo "Run:"
    echo "  source $SHELL_RC"
    echo "or restart your terminal."
fi