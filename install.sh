#!/usr/bin/env bash
#
# Copyright (c) 2022 msm.movin. All rights reserved.
# Proprietary software of msm.movin organization.
#
# MsmKhata 1-Click Installer, Updater & Launcher
#

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

TARGET_VER="1.0.7"
if [ -f "$PROJECT_ROOT/VERSION" ]; then
    TARGET_VER=$(cat "$PROJECT_ROOT/VERSION" | tr -d '[:space:]')
fi

echo "════════════════════════════════════════════════════════════"
echo "  🌟 MsmKhata Setup & Launcher v$TARGET_VER (msm.movin)"
echo "════════════════════════════════════════════════════════════"

# Detect if an existing installation or user session exists on the system
IS_INSTALLED=false
INSTALLED_VER="Unknown"

if [ -f "/opt/msmkhata/msmkhata_app" ]; then
    IS_INSTALLED=true
    INSTALLED_VER="Installed"
fi

if dpkg -l 2>/dev/null | grep -q "^ii[[:space:]]*msmkhata"; then
    IS_INSTALLED=true
    INSTALLED_VER=$(dpkg -l msmkhata 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "Installed")
fi

if [ -f "/usr/bin/msmkhata" ]; then
    IS_INSTALLED=true
fi

# Also detect if previous session exists in local share
HAS_PREV_SESSION=false
if [ -d "$HOME/.local/share/com.msmmovin.msmkhata_app" ]; then
    HAS_PREV_SESSION=true
fi

MODE="fresh"

# Parse CLI flags if passed
for arg in "$@"; do
    case "$arg" in
        --update|-u)
            MODE="update"
            ;;
        --reinstall|-r)
            MODE="reinstall"
            ;;
        --fresh|-f)
            MODE="fresh"
            ;;
    esac
done

if { [ "$IS_INSTALLED" = true ] || [ "$HAS_PREV_SESSION" = true ]; } && [ "$MODE" = "fresh" ]; then
    echo "  ⚠️  Previous MsmKhata Installation / Saved Session Detected!"
    echo "  Installed Version : v$INSTALLED_VER"
    echo "  Target Version    : v$TARGET_VER"
    echo "────────────────────────────────────────────────────────────"
    echo "  What would you like to do?"
    echo "  [1] Update / Upgrade to v$TARGET_VER (Recommended)"
    echo "      - Preserves signed-in user session & local ledger cache"
    echo "      - Updates binaries, desktop entries & app icons"
    echo ""
    echo "  [2] Clean Reinstall"
    echo "      - Completely wipes old installation & cached sessions"
    echo "      - Performs a 100% fresh, clean installation"
    echo ""
    echo "  [3] Cancel"
    echo "────────────────────────────────────────────────────────────"

    if [ -t 0 ]; then
        read -p "Select option [1-3] (Default: 1): " USER_CHOICE
        case "$USER_CHOICE" in
            2)
                MODE="reinstall"
                ;;
            3)
                echo "❌ Installation cancelled."
                exit 0
                ;;
            *)
                MODE="update"
                ;;
        esac
    else
        # Non-interactive terminal: default to update
        echo "ℹ️  Non-interactive terminal detected. Defaulting to Update / Upgrade..."
        MODE="update"
    fi
fi

if [ "$MODE" = "reinstall" ]; then
    echo "🛑 Running clean uninstaller and wiping previous sessions..."
    if [ -f "./uninstall.sh" ]; then
        ./uninstall.sh --purge
    fi
    echo "✨ Old installation & sessions wiped cleanly. Proceeding with fresh install..."
elif [ "$MODE" = "update" ]; then
    echo "🔄 Preparing update: stopping running processes and preserving user session..."
    pkill -x "msmkhata_app" 2>/dev/null || true
    pkill -f "^/opt/msmkhata/msmkhata_app" 2>/dev/null || true
fi

# Locate prebuilt Debian package if available
DEB_FILE=""
if [ -f "msmkhata_${TARGET_VER}_linux_amd64.deb" ]; then
    DEB_FILE="msmkhata_${TARGET_VER}_linux_amd64.deb"
elif [ -f "dist/deb/msmkhata_${TARGET_VER}_linux_amd64.deb" ]; then
    DEB_FILE="dist/deb/msmkhata_${TARGET_VER}_linux_amd64.deb"
fi

if [ -n "$DEB_FILE" ]; then
    echo "📦 1/3. Installing prebuilt Debian package ($DEB_FILE)..."
    sudo dpkg -i "$DEB_FILE" || sudo apt-get install -f -y
else
    echo "🔨 1/3. Building Flutter Linux release bundle..."
    cd "$PROJECT_ROOT/msmkhata_app"
    flutter pub get
    flutter build linux --release --obfuscate --split-debug-info=symbols
    cd "$PROJECT_ROOT"

    echo "📦 2/3. Deploying binaries to /opt/msmkhata..."
    sudo mkdir -p /opt/msmkhata
    sudo cp -r msmkhata_app/build/linux/x64/release/bundle/* /opt/msmkhata/
    sudo chmod +x /opt/msmkhata/msmkhata_app

    echo "🚀 Creating /usr/bin/msmkhata launcher..."
    sudo bash -c 'cat << "EOF" > /usr/bin/msmkhata
#!/usr/bin/env bash
exec /opt/msmkhata/msmkhata_app "$@"
EOF'
    sudo chmod 755 /usr/bin/msmkhata

    echo "🖼️  3/3. Installing desktop entry and application icons..."
    sudo mkdir -p /usr/share/applications
    sudo mkdir -p /usr/share/pixmaps
    sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
    sudo mkdir -p /usr/share/icons/hicolor/256x256/apps

    sudo bash -c 'cat << "EOF" > /usr/share/applications/msmkhata.desktop
[Desktop Entry]
Name=MsmKhata
GenericName=Financial Ledger
Comment=Personal Financial Ledger & Tracker by msm.movin
Exec=/usr/bin/msmkhata %u
Icon=msmkhata
Terminal=false
Type=Application
Categories=Finance;Office;Utility;
Keywords=ledger;finance;money;khata;accounting;
StartupWMClass=com.msmmovin.msmkhata_app
MimeType=x-scheme-handler/io.supabase.msmkhata;
EOF'
    sudo chmod 644 /usr/share/applications/msmkhata.desktop

    if [ -f "assets/icon.svg" ]; then
        sudo cp "assets/icon.svg" /usr/share/icons/hicolor/scalable/apps/msmkhata.svg
        sudo cp "assets/icon.svg" /usr/share/icons/hicolor/scalable/apps/com.msmmovin.msmkhata_app.svg
        sudo chmod 644 /usr/share/icons/hicolor/scalable/apps/msmkhata.svg
        sudo chmod 644 /usr/share/icons/hicolor/scalable/apps/com.msmmovin.msmkhata_app.svg
    fi
    if [ -f "assets/icon.png" ]; then
        sudo cp "assets/icon.png" /usr/share/pixmaps/msmkhata.png
        sudo cp "assets/icon.png" /usr/share/pixmaps/com.msmmovin.msmkhata_app.png
        sudo cp "assets/icon.png" /usr/share/icons/hicolor/256x256/apps/msmkhata.png
        sudo cp "assets/icon.png" /usr/share/icons/hicolor/256x256/apps/com.msmmovin.msmkhata_app.png
        sudo chmod 644 /usr/share/pixmaps/msmkhata.png
        sudo chmod 644 /usr/share/pixmaps/com.msmmovin.msmkhata_app.png
        sudo chmod 644 /usr/share/icons/hicolor/256x256/apps/msmkhata.png
        sudo chmod 644 /usr/share/icons/hicolor/256x256/apps/com.msmmovin.msmkhata_app.png
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        sudo update-desktop-database /usr/share/applications 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
if [ "$MODE" = "update" ]; then
    echo "  🎉 MsmKhata v$TARGET_VER Update Complete!"
    echo "  User session and local accounts preserved."
else
    echo "  🎉 MsmKhata v$TARGET_VER Clean Installation Complete!"
fi
echo "  Launch MsmKhata from your application menu or run: msmkhata"
echo "════════════════════════════════════════════════════════════"
echo ""

# Launch MsmKhata if running in an active graphical desktop session
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    exec /usr/bin/msmkhata &
fi
