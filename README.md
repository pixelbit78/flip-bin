# FlipBin 📦

> **Fast, offline-first inventory & expense tracking for online resellers.**

FlipBin is a mobile-first Progressive Web App (PWA) built with **Flutter Web**, **Riverpod**, and **Drift (SQLite)**. It replaces manual spreadsheet entry with an intuitive, barcode-scanning workflow designed for sourcing video games, media, and collectibles at thrift stores, garage sales, and clearance racks.

---

## ✨ Features

- 📷 **Instant Barcode Scanner & Cascading Lookup**
  - Integrated camera viewfinder with real-time barcode detection (`mobile_scanner`).
  - Cascading product metadata resolution: **Local SQLite Cache** ➔ **UPCitemdb API** ➔ **Open Food Facts API** ➔ **Manual Entry**.
  - Manual barcode entry with instant auto-lookup for items without scannable barcodes.

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

## 🛠️ Tech Stack

| Component | Technology | Description |
|-----------|------------|-------------|
| **Framework** | Flutter 3.x (Web PWA) | Cross-platform UI optimized for mobile and desktop web |
| **State Management** | Flutter Riverpod 2.x | Reactive dependency injection and stream providers |
| **Database** | Drift 2.x + SQLite (WASM) | Strongly typed local SQL database with reactive queries |
| **Barcode Scanner** | `mobile_scanner` | Hardware-accelerated camera barcode detection |
| **Google APIs** | `google_sign_in` + `googleapis` | OAuth 2.0 authentication, Sheets API v4, Drive API v3 |
| **HTTP Client** | `dio` + `http` | Resilient network requests with timeouts and error handling |
| **Navigation** | `go_router` | Declarative, URL-driven routing |

---

## 📁 Repository Structure

```text
flip-bin/
├── docs/
│   ├── plans/
│   │   └── 2026-09-27-flipbin.md        # Step-by-step TDD implementation plan
│   └── specs/
│       ├── 2026-09-27-flipbin-design.md # Full design and architectural specification
│       └── flipbin-mockups/             # High-fidelity UI design mockups
├── flipbin/                             # Main Flutter project
│   ├── lib/
│   │   ├── database/                    # Drift SQLite schema, DAOs, and connection logic
│   │   ├── models/                      # Enums and core data structures
│   │   ├── providers/                   # Riverpod state providers and business logic
│   │   ├── screens/                     # UI screens (Dashboard, Inventory, Expenses, Scanner, Settings)
│   │   ├── services/                    # Barcode lookup, image storage, Google Sheets API
│   │   └── widgets/                     # Reusable UI components and badges
│   ├── test/                            # Comprehensive unit, DAO, and widget tests
│   ├── tool/                            # Development utility scripts (e.g. serve.dart)
│   └── web/                             # PWA configuration, manifest, icons, and sql-wasm binaries
└── README.md
```

---

## 🚀 Getting Started

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+ recommended)
- Google Chrome or Chromium-based browser

### 2. Setup & Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/pixelbit78/flip-bin.git
cd flip-bin/flipbin
flutter pub get
```

### 3. Running Locally

Because SQLite WebAssembly requires specific Cross-Origin headers (`COOP`/`COEP`), FlipBin includes a custom development server:

```bash
# Start the local development server (serves on port 8080 with COOP/COEP enabled)
dart run tool/serve.dart
```

Open your browser and navigate to:
```
http://localhost:8080
```

---

## 🔑 Google Cloud Setup (OAuth & Sheets Sync)

To enable Google Sign-In and Google Sheets Export/Import:

1. **Google Cloud Console**:
   - Create or select a project in the [Google Cloud Console](https://console.developers.google.com).
   - Configure the **OAuth Consent Screen** (User Type: External, Scopes: `spreadsheets`, `drive.file`, `userinfo.profile`, `userinfo.email`).
   - Create an **OAuth 2.0 Client ID** (Application type: *Web application*).
   - Add `http://localhost:8080` to **Authorized JavaScript origins**.

2. **Enable Required Google APIs**:
   - [Google People API](https://console.developers.google.com/apis/api/people.googleapis.com/overview) (Required for profile details)
   - [Google Sheets API](https://console.developers.google.com/apis/api/sheets.googleapis.com/overview) (Required for spreadsheet read/write)
   - [Google Drive API](https://console.developers.google.com/apis/api/drive.googleapis.com/overview) (Required for locating and creating the backup file)

3. **Configure in FlipBin**:
   - In FlipBin, navigate to **Settings**.
   - Expand **OAuth Client ID Configuration (Web)** and paste your Client ID (or use the pre-configured default).
   - Click **Sign In with Google**.

---

## 🧪 Testing

FlipBin is built following strict Test-Driven Development (TDD) practices, with 100% test coverage across database queries, lookup failover, business logic, and UI widgets:

```bash
cd flipbin

# Run static analysis
flutter analyze

# Run the automated test suite (43 unit & widget tests)
flutter test
```

---

## 📖 Documentation

- 📋 [Design Specification](docs/specs/2026-09-27-flipbin-design.md) — Architectural overview, data models, screen flows, and visual mockups.
- 📝 [Implementation Plan](docs/plans/2026-09-27-flipbin.md) — Step-by-step TDD tasks executed during MVP development.

---

## 📄 License

This project is licensed under the MIT License.
