# FlipBin 📦

> **Fast, offline-first inventory & expense tracking for online resellers.**

FlipBin is a mobile-first Progressive Web App (PWA) built with **Flutter Web**, **Riverpod**, and **Drift (SQLite)**. It replaces manual spreadsheet entry with an intuitive, barcode-scanning workflow designed for sourcing video games, media, and collectibles at thrift stores, garage sales, and clearance racks.

**Canonical deploy:** [Vercel](https://vercel.com) (Hobby). GitHub Pages is retired as the production host.

---

## ✨ Features

- 📷 **Instant Barcode Scanner & Cascading Lookup**
  - Integrated camera viewfinder with real-time barcode detection (`mobile_scanner` 7.x).
  - Cascading product metadata resolution: **Local SQLite Cache** → **same-origin `/api/upc` (UPCitemdb via Vercel serverless)** → **Manual Entry**.
  - Manual barcode entry with instant auto-lookup; camera detect and **Look Up** share one path.
  - Shows looking-up / result / not-found states in the scanner UI.

- 📦 **Inventory Management**
  - Category classification: *Game, DVD, Blu-ray, CD, Book, Other*.
  - Status lifecycle: *Active, Sold, Personal*.
  - Track purchase cost, target platform (*eBay, Mercari, Poshmark, etc.*), and sale number.
  - Automatically calculates **Days to Sell** when items transition to Sold.
  - Full-text search and category/status filter chips.

- 💳 **Expense Tracking**
  - Categorized expense logging: *Shipping, Equipment, Software, Travel, Other*.
  - Quantity, unit price, calculated total, and sales tax.
  - Monthly expense filtering with dynamic running totals.
  - Receipt image capture and attachment.

- 📊 **Reseller Dashboard**
  - Real-time metric cards for active inventory count, total inventory investment, and monthly operating expenses.
  - One-tap quick actions for scanning and adding inventory.

- 🔄 **Two-Way Google Sheets Backup (Export & Import)**
  - **Export to Sheets**: Uploads all inventory and expense records to a clean Google Spreadsheet titled `FlipBin Export` in your Google Drive root.
  - **Import from Sheets**: Restores and overwrites local database with data from Google Sheets, complete with a safety confirmation dialog.
  - **One-Click Direct Access**: "Open Sheet" button directly opens `https://docs.google.com/spreadsheets/d/<id>/edit` in your browser.

- ⚡ **Offline-First & PWA Architecture**
  - Fully functional in thrift stores and warehouse dead zones with no internet connection.
  - Powered by Drift SQLite running locally in the browser via WebAssembly (`sql-wasm.wasm`) and IndexedDB persistence.
  - Installable to home screens on iOS and Android via Web App Manifest.

---

## 🌐 Production (Vercel)

| Item | Value |
|------|--------|
| **Production URL** | _Set after first `vercel --prod` deploy (e.g. `https://flip-bin.vercel.app` or your custom domain)_ |
| **UPC proxy** | `GET /api/upc?upc=<digits>` → clean JSON `{ barcode, productName, description, imageUrl, category, source }` |
| **Hosting** | Vercel Hobby — Flutter `build/web` static + Node serverless `api/upc` |

### Barcode lookup cascade

1. **Local SQLite cache** (Drift) — instant, offline.
2. **Same-origin `/api/upc`** on web (Vercel function calls [UPCitemdb trial](https://api.upcitemdb.com/prod/trial/lookup) server-side to avoid CORS). Non-web builds may call UPCitemdb directly.
3. **Not found** → scanner shows not-found UI; user can add manually.

Open Food Facts / Open Products Facts are **not** used.

### OAuth origins (required after cutover)

Steve must add the **Vercel production origin** (and preview origins if used) in Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Web client → **Authorized JavaScript origins**:

- Production: `https://<your-vercel-host>` (e.g. `https://flip-bin.vercel.app`)
- Local: `http://localhost:8080`

Without this, Google Sign-In / Sheets sync will fail on the Vercel host even though barcode lookup works.

---

## 🛠️ Tech Stack

| Component | Technology | Description |
|-----------|------------|-------------|
| **Framework** | Flutter 3.x (Web PWA) | Cross-platform UI optimized for mobile and desktop web |
| **State Management** | Flutter Riverpod 2.x | Reactive dependency injection and stream providers |
| **Database** | Drift 2.x + SQLite (WASM) | Strongly typed local SQL database with reactive queries |
| **Barcode Scanner** | `mobile_scanner` 7.x | Hardware-accelerated camera barcode detection |
| **UPC proxy** | Vercel Serverless (`api/upc`) | Server-side UPCitemdb trial lookup |
| **Google APIs** | `google_sign_in` + `googleapis` | OAuth 2.0 authentication, Sheets API v4, Drive API v3 |
| **HTTP Client** | `dio` + `http` | Resilient network requests with timeouts and error handling |
| **Navigation** | `go_router` | Declarative, URL-driven routing |
| **Deploy** | Vercel Hobby | Static Flutter web + `/api` functions |

---

## 📁 Repository Structure

```text
flip-bin/
├── api/
│   └── upc.js                         # Vercel serverless UPC proxy
├── scripts/
│   ├── vercel-install.sh              # Install Flutter + pub get (Vercel)
│   └── vercel-build.sh                # flutter build web --release --base-href /
├── vercel.json                        # SPA rewrites, outputDirectory, headers
├── package.json                       # Node engine for serverless runtime
├── docs/
│   ├── plans/
│   └── specs/
├── flipbin/                           # Main Flutter project
│   ├── lib/
│   │   ├── database/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/                  # Barcode lookup, Sheets, images
│   │   └── widgets/
│   ├── test/
│   ├── tool/                          # Local serve.dart (COOP-free static)
│   └── web/
└── README.md
```

---

## 🚀 Getting Started

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+ recommended)
- Google Chrome or Chromium-based browser
- Optional: [Vercel CLI](https://vercel.com/docs/cli) for deploys (`npm i -g vercel`)

### 2. Setup & Installation

```bash
git clone https://github.com/pixelbit78/flip-bin.git
cd flip-bin/flipbin
flutter pub get
```

### 3. Running Locally

```bash
# Build once, then serve with SPA fallback
flutter build web --release --base-href /
dart run tool/serve.dart
```

Open `http://localhost:8080`.

To exercise the UPC proxy locally, run `vercel dev` from the **repo root** (requires Vercel login / link) so `/api/upc` is available beside the static build.

### 4. Manual web build (if not using Vercel build)

```bash
cd flipbin
flutter build web --release --base-href /
# Output: flipbin/build/web  (deploy this directory; NOT /flip-bin/ base-href)
```

GitHub Pages `/flip-bin/` base-href is **retired**. Always use `--base-href /` for Vercel root hosting.

---

## 🔑 Google Cloud Setup (OAuth & Sheets Sync)

1. **Google Cloud Console**:
   - Create or select a project in the [Google Cloud Console](https://console.developers.google.com).
   - Configure the **OAuth Consent Screen** (User Type: External, Scopes: `spreadsheets`, `drive.file`, `userinfo.profile`, `userinfo.email`).
   - Create an **OAuth 2.0 Client ID** (Application type: *Web application*).
   - Add **Authorized JavaScript origins**:
     - `http://localhost:8080`
     - `https://<your-vercel-production-host>` ← **required after Vercel cutover**

2. **Enable Required Google APIs**:
   - [Google People API](https://console.developers.google.com/apis/api/people.googleapis.com/overview)
   - [Google Sheets API](https://console.developers.google.com/apis/api/sheets.googleapis.com/overview)
   - [Google Drive API](https://console.developers.google.com/apis/api/drive.googleapis.com/overview)

3. **Configure in FlipBin**:
   - Settings → **OAuth Client ID Configuration (Web)** → paste Client ID (or use the pre-configured default).
   - Click **Sign In with Google**.

---

## 🧪 Testing

```bash
cd flipbin
flutter analyze
flutter test
```

---

## ☁️ Deploy (Vercel Hobby)

From the **repository root** (linked to GitHub `pixelbit78/flip-bin`):

```bash
npm i -g vercel
vercel login          # GitHub SSO recommended
vercel link           # link to Hobby project / import GitHub repo
vercel --prod         # production deploy
```

`vercel.json` runs `scripts/vercel-install.sh` (Flutter stable + `pub get`) and `scripts/vercel-build.sh` (`flutter build web --release --base-href /`), then publishes `flipbin/build/web` with `/api/upc` as a serverless function and SPA rewrites to `index.html`.

**Alternative:** import the GitHub repo in the Vercel dashboard (Hobby) and deploy from `main`; root directory = repo root.

---

## 📖 Documentation

- 📋 [Design Specification](docs/specs/2026-09-27-flipbin-design.md) — Architectural overview, data models, screen flows, and visual mockups.
- 📝 [Implementation Plan](docs/plans/2026-09-27-flipbin.md) — Step-by-step TDD tasks executed during MVP development.

---

## 📄 License

This project is licensed under the MIT License.
