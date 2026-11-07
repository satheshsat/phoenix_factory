#!/bin/bash
set -e

APP_ID="satcs.phoenix.factory"
APP_NAME="Phoenix Factory"

echo "============================================"
echo " Removing ${APP_NAME} Desktop Integration"
echo "============================================"

# Remove desktop entry
rm -f "$HOME/.local/share/applications/${APP_ID}.desktop"

# Remove icons
for size in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
    rm -f "$HOME/.local/share/icons/hicolor/${size}/apps/${APP_ID}.png"
done

# Remove binary symlink
rm -f "$HOME/.local/bin/phoenix_factory"

# Refresh desktop database and icon cache
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "${APP_NAME} desktop integration successfully removed."

