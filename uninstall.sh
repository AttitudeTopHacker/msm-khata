#!/usr/bin/env bash
#
# Copyright (c) 2022 msm.movin. All rights reserved.
# Proprietary software of msm.movin organization.
#
# MsmKhata Clean Uninstaller
#

set -e

PURGE_DATA=true # By default, clean uninstall purges local session/data so app doesn't unexpectedly remain signed in

for arg in "$@"; do
    case "$arg" in
        --keep-data)
            PURGE_DATA=false
            ;;
        --purge|-p)
            PURGE_DATA=true
            ;;
    esac
done

echo "════════════════════════════════════════════════════════════"
echo "  🛑 MsmKhata Clean Uninstaller (msm.movin)"
echo "════════════════════════════════════════════════════════════"

pkill -x "msmkhata_app" 2>/dev/null || true
pkill -f "^/opt/msmkhata/msmkhata_app" 2>/dev/null || true

echo "🧹 2/4. Removing Debian package (if installed via dpkg/apt)..."
if dpkg -l 2>/dev/null | grep -q "^ii[[:space:]]*msmkhata"; then
    sudo dpkg -P msmkhata 2>/dev/null || sudo apt remove --purge -y msmkhata 2>/dev/null || true
fi

echo "🗑️ 3/4. Removing binaries, desktop entries & app icons..."
sudo rm -rf /opt/msmkhata
sudo rm -f /usr/bin/msmkhata
sudo rm -f /usr/local/bin/msmkhata
sudo rm -f /usr/share/applications/msmkhata.desktop
sudo rm -f /usr/share/pixmaps/msmkhata.png
sudo rm -f /usr/share/pixmaps/com.msmmovin.msmkhata_app.png
sudo rm -f /usr/share/icons/hicolor/*/apps/msmkhata.*
sudo rm -f /usr/share/icons/hicolor/*/apps/com.msmmovin.msmkhata_app.*

if command -v update-desktop-database >/dev/null 2>&1; then
    sudo update-desktop-database /usr/share/applications 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

if [ "$PURGE_DATA" = true ]; then
    echo "🧼 4/4. Purging user session, credentials, cached ledger data & tokens..."
    # Clean current user's local share, cache, and config
    rm -rf "$HOME/.local/share/com.msmmovin.msmkhata_app" 2>/dev/null || true
    rm -rf "$HOME/.local/share/msmkhata" 2>/dev/null || true
    rm -rf "$HOME/.local/share/msmkhata_app" 2>/dev/null || true
    rm -rf "$HOME/.cache/msmkhata" 2>/dev/null || true
    rm -rf "$HOME/.cache/msmkhata_app" 2>/dev/null || true
    rm -rf "$HOME/.config/msmkhata" 2>/dev/null || true
    rm -rf "$HOME/.config/msmkhata_app" 2>/dev/null || true

    # Clean all users in /home if run with sudo
    if [ -d "/home" ]; then
        for udir in /home/*; do
            if [ -d "$udir" ]; then
                sudo rm -rf "$udir/.local/share/com.msmmovin.msmkhata_app" 2>/dev/null || true
                sudo rm -rf "$udir/.local/share/msmkhata" 2>/dev/null || true
                sudo rm -rf "$udir/.local/share/msmkhata_app" 2>/dev/null || true
                sudo rm -rf "$udir/.cache/msmkhata" 2>/dev/null || true
                sudo rm -rf "$udir/.cache/msmkhata_app" 2>/dev/null || true
                sudo rm -rf "$udir/.config/msmkhata" 2>/dev/null || true
                sudo rm -rf "$udir/.config/msmkhata_app" 2>/dev/null || true
            fi
        done
    fi
    echo "   ✅ Previous login sessions and local cache completely wiped."
else
    echo "ℹ️  User login session & local cache preserved (--keep-data)."
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ MsmKhata has been completely and cleanly uninstalled!"
echo "════════════════════════════════════════════════════════════"
echo ""
