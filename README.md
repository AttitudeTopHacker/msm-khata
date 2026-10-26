# MsmKhata (msm.movin)

> **MsmKhata** is a personal financial ledger & tracker (Len-Den: Lena Hai vs Dena Hai), built with Supabase, FastAPI, and Flutter.

## Architecture

1. **Database & Auth (Supabase PostgreSQL):**
   - Tables: `profiles`, `persons`, `categories`, `transactions`, `saved_filters`
   - Trigger: `handle_new_user()` auto-syncs Google & GitHub OAuth avatar and name to `profiles`
   - Real-time row-level security (RLS) enabled

2. **Backend Engine (FastAPI):**
   - Modular REST API (`/api/v1`)
   - Net balance engine (`ledger_service.py`), auto-creation of persons/categories
   - Google Drive REST v3 multipart backup and JSON/CSV export engine

3. **Frontend (Native Flutter):**
   - Pure Flutter client (`msmkhata_app`)
   - Native Linux desktop window (GTK3), Windows native, and Android APK support
   - Dark modern financial UI with balance summaries and transaction modals

4. **CI/CD & Cloud Builds (GitHub Actions):**
   - Automated cloud compilation with 0% local CPU load
   - Builds native Linux `.deb`, Windows `.exe`/`.zip`, and Android `.apk` simultaneously on every push or manual trigger
   - Downloadable standalone artifacts generated directly from GitHub Actions

## Cloud Build & Native Releases

Zero local build lag: GitHub's cloud runners automatically compile all native targets.

To get the latest compiled builds:
1. Navigate to the **Actions** tab on GitHub: [msm-khata Actions](https://github.com/AttitudeTopHacker/msm-khata/actions)
2. Click on the latest run under **Build Native Releases (.exe, .deb, .apk)**.
3. Under the **Artifacts** section at the bottom, download any package:
   - 🐧 **Linux**: `msmkhata_1.0.0_linux_amd64.deb`  
     ```bash
     sudo dpkg -i msmkhata_1.0.0_linux_amd64.deb
     ```
   - 🪟 **Windows**: `msmkhata_1.0.0_windows_x64.zip` or `msmkhata_1.0.0_windows.exe`  
     Extract and run `msmkhata_app.exe` (or `msmkhata.exe`).
   - 📱 **Android**: `msmkhata_1.0.0_android.apk`  
     Install directly on your Android phone/tablet.

---
*Created and maintained by AttitudeTopHacker (msm.movin, Est. 2022)*
