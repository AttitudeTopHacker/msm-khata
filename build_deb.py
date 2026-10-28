#!/usr/bin/env python3
"""
MsmKhata Debian (.deb) Package Builder
Builds a production Debian installer package for MsmKhata desktop.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APP_DIR = ROOT / "msmkhata_app"
VERSION_FILE = ROOT / "VERSION"
DIST_DIR = ROOT / "dist" / "deb"

def get_version() -> str:
    if VERSION_FILE.exists():
        return VERSION_FILE.read_text().strip()
    return "1.0.7"

def run(cmd, cwd=ROOT):
    print(f"==> Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    res = subprocess.run(cmd, cwd=cwd, shell=isinstance(cmd, str))
    if res.returncode != 0:
        print(f"❌ Command failed with returncode {res.returncode}")
        sys.exit(res.returncode)

def main():
    version = get_version()
    arch = "amd64"
    pkg_name = "msmkhata"
    deb_dir_name = f"{pkg_name}_{version}_{arch}"
    deb_root = DIST_DIR / deb_dir_name
    output_deb = ROOT / f"{pkg_name}_{version}_linux_{arch}.deb"

    print("════════════════════════════════════════════════════════════")
    print(f"  🔨 Building MsmKhata Debian (.deb) Package v{version}")
    print("════════════════════════════════════════════════════════════")

    # 1. Build Flutter Linux Release
    print("\n[1/4] Building Flutter Linux Release...")
    run(["flutter", "pub", "get"], cwd=APP_DIR)
    run(["flutter", "build", "linux", "--release", "--obfuscate", "--split-debug-info=symbols"], cwd=APP_DIR)

    bundle_src = APP_DIR / "build" / "linux" / "x64" / "release" / "bundle"
    if not bundle_src.exists():
        print(f"❌ Error: Flutter bundle not found at {bundle_src}")
        sys.exit(1)

    # 2. Setup debian layout
    print("\n[2/4] Setting up package root directory structure...")
    if deb_root.exists():
        shutil.rmtree(deb_root)

    deb_debian = deb_root / "DEBIAN"
    deb_opt = deb_root / "opt" / pkg_name
    deb_bin = deb_root / "usr" / "bin"
    deb_apps = deb_root / "usr" / "share" / "applications"
    deb_pixmaps = deb_root / "usr" / "share" / "pixmaps"
    deb_icons_scalable = deb_root / "usr" / "share" / "icons" / "hicolor" / "scalable" / "apps"
    deb_icons_256 = deb_root / "usr" / "share" / "icons" / "hicolor" / "256x256" / "apps"

    for d in [deb_debian, deb_opt, deb_bin, deb_apps, deb_pixmaps, deb_icons_scalable, deb_icons_256]:
        d.mkdir(parents=True, exist_ok=True)

    # Copy bundle
    print("   Copying binary bundle...")
    shutil.copytree(bundle_src, deb_opt, dirs_exist_ok=True)
    executable = deb_opt / "msmkhata_app"
    if executable.exists():
        os.chmod(executable, 0o755)

    # Launcher
    launcher = deb_bin / "msmkhata"
    launcher.write_text("""#!/usr/bin/env bash
exec /opt/msmkhata/msmkhata_app "$@"
""")
    os.chmod(launcher, 0o755)

    # Desktop entry
    desktop = deb_apps / "msmkhata.desktop"
    desktop.write_text("""[Desktop Entry]
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
""")
    os.chmod(desktop, 0o644)

    # Icons
    icon_svg = ROOT / "assets" / "icon.svg"
    icon_png = ROOT / "assets" / "icon.png"
    if icon_svg.exists():
        shutil.copy(icon_svg, deb_icons_scalable / "msmkhata.svg")
        shutil.copy(icon_svg, deb_icons_scalable / "com.msmmovin.msmkhata_app.svg")
    if icon_png.exists():
        shutil.copy(icon_png, deb_pixmaps / "msmkhata.png")
        shutil.copy(icon_png, deb_pixmaps / "com.msmmovin.msmkhata_app.png")
        shutil.copy(icon_png, deb_icons_256 / "msmkhata.png")
        shutil.copy(icon_png, deb_icons_256 / "com.msmmovin.msmkhata_app.png")

    # 3. Create hooks (postinst, prerm, postrm) & control
    print("\n[3/4] Creating Debian control and lifecycle hooks...")

    # prerm
    prerm = deb_debian / "prerm"
    prerm.write_text("""#!/bin/sh
set -e
pkill -f "msmkhata" 2>/dev/null || true
exit 0
""")
    os.chmod(prerm, 0o755)

    # postinst
    postinst = deb_debian / "postinst"
    postinst.write_text("""#!/bin/sh
set -e
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications 2>/dev/null || true
fi
exit 0
""")
    os.chmod(postinst, 0o755)

    # postrm (Crucial: on purge, removes leftover user sessions so uninstall doesn't leave user signed in!)
    postrm = deb_debian / "postrm"
    postrm.write_text("""#!/bin/sh
set -e
case "$1" in
  purge)
    rm -rf /opt/msmkhata 2>/dev/null || true
    for udir in /home/*; do
      if [ -d "$udir" ]; then
        rm -rf "$udir/.local/share/com.msmmovin.msmkhata_app" 2>/dev/null || true
        rm -rf "$udir/.local/share/msmkhata" 2>/dev/null || true
        rm -rf "$udir/.local/share/msmkhata_app" 2>/dev/null || true
        rm -rf "$udir/.cache/msmkhata" 2>/dev/null || true
        rm -rf "$udir/.cache/msmkhata_app" 2>/dev/null || true
        rm -rf "$udir/.config/msmkhata" 2>/dev/null || true
      fi
    done
    ;;
  remove|upgrade|failed-upgrade|abort-install|abort-upgrade|disappear)
    ;;
esac
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications 2>/dev/null || true
fi
exit 0
""")
    os.chmod(postrm, 0o755)

    # Calculate installed size (in KB)
    installed_size = subprocess.check_output(["du", "-sk", str(deb_root)]).decode().split()[0]

    control = deb_debian / "control"
    control.write_text(f"""Package: {pkg_name}
Version: {version}
Section: utils
Priority: optional
Architecture: {arch}
Installed-Size: {installed_size}
Maintainer: AttitudeTopHacker <msm.movin@gmail.com>
Depends: libc6, libgtk-3-0, libglib2.0-0
Description: MsmKhata - Native Financial Ledger & Tracker
 Native cross-platform financial ledger and tracker desktop application
 built with Flutter and Supabase, maintained by msm.movin (Est. 2022).
""")
    os.chmod(control, 0o644)

    # 4. Build .deb
    print(f"\n[4/4] Building .deb package: {output_deb.name}...")
    run(["dpkg-deb", "--build", "--root-owner-group", str(deb_root), str(output_deb)])

    print("\n════════════════════════════════════════════════════════════")
    print(f"  🎉 Debian Package Created Successfully: {output_deb}")
    print(f"  Install with: sudo dpkg -i {output_deb.name}")
    print("════════════════════════════════════════════════════════════\n")

if __name__ == "__main__":
    main()
