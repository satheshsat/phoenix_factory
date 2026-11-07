#!/bin/bash
set -e

# Get absolute path to the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BIN="${SCRIPT_DIR}/phoenix_factory"
APP_ID="satcs.phoenix.factory"
APP_NAME="Phoenix Factory"

echo "=========================================="
echo " Installing ${APP_NAME} Desktop Integration"
echo "=========================================="

if [ ! -f "$APP_BIN" ]; then
    echo "Error: Application binary not found at: ${APP_BIN}"
    exit 1
fi

chmod +x "$APP_BIN"

# Create standard user application and icon directories
APPLICATIONS_DIR="${HOME}/.local/share/applications"
ICONS_BASE_DIR="${HOME}/.local/share/icons/hicolor"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$APPLICATIONS_DIR"
mkdir -p "$ICONS_BASE_DIR"

# Copy icons if available in bundle
if [ -d "${SCRIPT_DIR}/share/icons/hicolor" ]; then
    echo "-> Installing application icons..."
    cp -r "${SCRIPT_DIR}/share/icons/hicolor/"* "${ICONS_BASE_DIR}/"
elif [ -f "${SCRIPT_DIR}/data/flutter_assets/assets/icon/app_icon.png" ]; then
    echo "-> Installing fallback icon from flutter assets..."
    mkdir -p "${ICONS_BASE_DIR}/512x512/apps"
    cp "${SCRIPT_DIR}/data/flutter_assets/assets/icon/app_icon.png" "${ICONS_BASE_DIR}/512x512/apps/${APP_ID}.png"
fi

# Create desktop entry pointing to the extracted binary
DESKTOP_FILE="${APPLICATIONS_DIR}/${APP_ID}.desktop"
echo "-> Creating desktop launcher at ${DESKTOP_FILE}..."

# Determine the best icon reference (prefer direct file path so it loads immediately without cache delay)
PRIMARY_ICON="${ICONS_BASE_DIR}/256x256/apps/${APP_ID}.png"
if [ ! -f "$PRIMARY_ICON" ]; then
    PRIMARY_ICON="${ICONS_BASE_DIR}/512x512/apps/${APP_ID}.png"
fi
if [ ! -f "$PRIMARY_ICON" ]; then
    PRIMARY_ICON="${APP_ID}"
fi

cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
GenericName=Media Converter
Comment=Universal Media Converter Suite
Exec="${APP_BIN}" %U
Path=${SCRIPT_DIR}
Icon=${PRIMARY_ICON}
Terminal=false
Categories=AudioVideo;AudioVideoEditing;Audio;Video;Graphics;Utility;
Keywords=Converter;Video;Audio;Picture;Format;Factory;FFmpeg;Transcoder;
StartupNotify=true
StartupWMClass=${APP_ID}
EOF

chmod +x "$DESKTOP_FILE"

# Optional: Link binary to ~/.local/bin if directory exists or in PATH
mkdir -p "$BIN_DIR"
ln -sf "$APP_BIN" "${BIN_DIR}/phoenix_factory"

# Refresh desktop database and icon cache
if command -v update-desktop-database >/dev/null 2>&1; then
    echo "-> Updating desktop database..."
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    echo "-> Updating icon cache..."
    gtk-update-icon-cache -f -t "$ICONS_BASE_DIR" >/dev/null 2>&1 || true
fi

echo ""
echo "Installation complete!"
echo "The app icon will now show in your Application Menu, Ubuntu Dock, and Alt+Tab switcher."
echo "You can launch it from your desktop menu or by running: phoenix_factory"

