#!/bin/bash

set -e

echo "[*] Installing openserv..."

# Create directory
mkdir -p "$HOME/.openserv"

# Copy files
cp -r src/. "$HOME/.openserv/"

# Ensure main script is executable
chmod +x "$HOME/.openserv/openserv.sh"

# Ensure local bin exists
mkdir -p "$HOME/.local/bin"

# Create symlink (global command)
ln -sf "$HOME/.openserv/openserv.sh" "$HOME/.local/bin/openserv"

# Add ~/.local/bin to PATH if not already present
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "[*] Added ~/.local/bin to PATH in ~/.bashrc"
fi

echo "[✓] Installation complete!"

echo ""
echo "Run the command with:"
echo "  openserv"
echo ""

echo "If it doesn't work immediately, run:"
echo "  source ~/.bashrc"
echo "or restart your terminal."