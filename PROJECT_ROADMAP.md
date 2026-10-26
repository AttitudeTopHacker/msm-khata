# MsmKhata — Project Architecture & Roadmap
**Organization:** msm.movin (Est. 2022)  
**Project Name:** MsmKhata  
**Document Created:** October 26, 2026  
**Status:** Ready for Implementation  

---

## 1. Project Concept & Core Purpose

`MsmKhata` ek **purely personal financial ledger & tracker** hai. Isme kisi customer ya client ka billing system nahi hai, balki aapka niji hisab-kitab rahega:
1. **Len-Den (People Ledger):**
   - **Kisse liye (Borrowed / Maine Liye):** Kis-kis se udhar liya aur kisko lautana baki hai.
   - **Kisko diye (Lent / Maine Diye):** Kis-kis dost/vyakti ko paise diye aur kisse wapas aana baki hai.
   - **Kitne Baki Hain (Pending Balance):** Har vyakti ka net balance aur total market me kitna lena/dena baki hai.
   - **Partial Settlements:** Tukdon me repayment ka automatic hisab.

2. **Personal Expenses & Income (Self Tracker):**
   - Daily kharche (Food, Travel, Bills, etc.).
   - Dynamic Category system.

---

## 2. Key Features

- **On-the-Fly Dynamic Creation:**
  - Transaction karte waqt agar user naya category ya naye vyakti ka naam type karta hai, to automatically background me naya record create ho jayega.
- **Smart Filters:**
  - Filter by Person (e.g., Sirf "Rahul" ka poora hisab).
  - Filter by Status ("Jinse paise lene baki hain", "Jinko dene baki hain", "Settled").
  - Date & Type filters (Daily, Weekly, Monthly, Custom Range).
  - Custom Saved Filters (Apne pasandeeda filter save karne ki suvidha).
- **Graphs & Percentages:**
  - Net Position Card (Total Lena Hai vs Total Dena Hai).
  - Category-wise Spending Donut/Pie Chart.
  - Monthly Cash Flow & Len-Den Trends.
- **Authentication & Cloud Sync:**
  - Supabase Auth: Google Sign-In & GitHub Sign-In.
  - Google Drive Backup: Ek click me poore hisab ka backup Google Drive par save.
  - Environment Security: Saare API keys aur credentials `.env` file me surakshit rahenge.

---

## 3. Recommended Tech Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Backend API** | **Python (FastAPI)** | Clean, high-performance async APIs, stats & calculation engine, Google Drive integration. |
| **Database** | **Supabase (PostgreSQL)** | RLS (Row Level Security), real-time updates, auto REST endpoints. |
| **Authentication** | **Supabase Auth** | Built-in Google & GitHub OAuth. |
| **Desktop & Mobile** | **Flutter** *(Native cross-platform)* | Android, iOS, Linux, Windows, macOS ke liye ek hi clean codebase. |
| **Web Dashboard** | **React / Vite** | Modern, premium responsive web interface. |
| **Config** | **python-dotenv (.env)** | Secrets, Supabase URL, Anon Key, Drive API credentials. |

---

## 4. Database Schema (Supabase PostgreSQL)

```sql
-- 1. Profiles
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. People / Contacts (Len-den ke liye)
CREATE TABLE persons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Categories (Dynamic self-expense/income tags)
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT CHECK (type IN ('EXPENSE', 'INCOME', 'BOTH')),
    color TEXT DEFAULT '#4F46E5',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Transactions (Main Ledger)
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    person_id UUID REFERENCES persons(id) ON DELETE SET NULL, -- Agar kisi ko diya/liya
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL, -- Agar self expense hai
    type TEXT NOT NULL CHECK (type IN ('GIVEN', 'TAKEN', 'EXPENSE', 'INCOME')),
    amount NUMERIC(12, 2) NOT NULL,
    payment_mode TEXT DEFAULT 'CASH' CHECK (payment_mode IN ('CASH', 'UPI', 'BANK_TRANSFER', 'OTHER')),
    due_date DATE,
    is_settled BOOLEAN DEFAULT FALSE,
    notes TEXT,
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Saved Filters
CREATE TABLE saved_filters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    filter_name TEXT NOT NULL,
    filter_criteria JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 5. Implementation Progress & Next Steps

- [x] **Step 1: Database & Environment Setup**
  - Supabase Project: `msm-khata` (`dzjzinbogydbnatkibuw`) connected.
  - Core database schema applied (`profiles`, `persons`, `categories`, `transactions`, `saved_filters`).
  - `.env` and `.env.example` configured.
- [x] **Step 2: Python Backend (FastAPI) & Financial Engine**
  - Modular clean architecture (`app/models`, `app/services`, `app/routers`).
  - Supabase connection singleton in [app/database.py](file:///home/salman/StudioProjects/msmkhata/app/database.py).
  - Contacts & Len-Den CRUD (`/api/v1/persons`).
  - Dynamic on-the-fly Person & Category auto-creation in [app/services/ledger_service.py](file:///home/salman/StudioProjects/msmkhata/app/services/ledger_service.py).
  - Live Net Balance engine (Lena Hai vs Dena Hai).
  - Multi-criteria Transactions API (`/api/v1/transactions`).
  - Dashboard analytics & visual stats breakdown (`/api/v1/stats/summary`).
  - Integration tests verified: `tests/test_api.py`.
- [x] **Step 3: Cross-Platform Frontend (Flutter App)**
  - Flutter SDK installed & symlinked in `~/.local/bin`.
  - Application structure created in [msmkhata_app/](file:///home/salman/StudioProjects/msmkhata/msmkhata_app).
  - Modern Dark Theme with indigo/purple accents.
  - Net Position Card widget ([net_position_card.dart](file:///home/salman/StudioProjects/msmkhata/msmkhata_app/lib/widgets/net_position_card.dart)) displaying Total Lena Hai vs Total Dena Hai.
  - Dashboard screen ([dashboard_screen.dart](file:///home/salman/StudioProjects/msmkhata/msmkhata_app/lib/screens/dashboard_screen.dart)) with Quick Actions (Maine Diye, Maine Liye, Kharcha, Kamai).
  - Contacts & Len-Den management screen ([persons_screen.dart](file:///home/salman/StudioProjects/msmkhata/msmkhata_app/lib/screens/persons_screen.dart)) with balance status filters.
  - On-the-fly Transaction Entry modal ([add_transaction_screen.dart](file:///home/salman/StudioProjects/msmkhata/msmkhata_app/lib/screens/add_transaction_screen.dart)).
  - Direct API service ([api_service.dart](file:///home/salman/StudioProjects/msmkhata/msmkhata_app/lib/services/api_service.dart)) communicating with FastAPI backend.
  - Cross-platform support ready for **Linux Desktop**, **Windows Desktop**, and **Android APK**.
- [x] **Step 4: Google Drive Backup & Data Export Integration**
  - Full snapshot backup generator ([backup_service.py](file:///home/salman/StudioProjects/msmkhata/app/services/backup_service.py)).
  - Direct 1-Click JSON export (`/api/v1/backup/export/json`).
  - Formatted CSV export for Excel / Google Sheets (`/api/v1/backup/export/csv`).
  - Google Drive REST API v3 auto-uploader into `'MsmKhata Backups'` folder (`/api/v1/backup/google-drive`).
  - Verified with test suite: [tests/test_api.py](file:///home/salman/StudioProjects/msmkhata/tests/test_api.py).

---
*Maintained by Antigravity IDE for Salman / msm.movin (2022)*



