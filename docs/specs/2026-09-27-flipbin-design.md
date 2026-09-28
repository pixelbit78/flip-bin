# FlipBin — Inventory & Expense Tracking for Resellers

**Date:** 2026-09-27
**Status:** Draft
**App Name:** FlipBin
**Platform:** Flutter Web (PWA)

---

## 1. Overview

FlipBin is a mobile-first Progressive Web App (PWA) built with Flutter for online resellers
to track inventory and business expenses. The app replaces a manual Google Sheets workflow
with a purpose-built tool that supports barcode scanning, product lookup, and one-tap
Google Sheets export.

### 1.1 Target User

A single user (the reseller) who sources items — primarily video games, DVDs, Blu-rays,
and CDs — from thrift stores, garage sales, and retail clearance, then resells on platforms
like eBay, Mercari, and Poshmark.

### 1.2 Success Criteria

- Scan a barcode at a store and have the item's metadata auto-populated in under 3 seconds
- Add an inventory item or expense in fewer taps than the current spreadsheet workflow
- All data available offline (critical for stores with poor cell signal)
- One-tap export to Google Sheets for backup and tax/accounting purposes

---

## 2. Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Framework** | Flutter Web (PWA) | Installable on phone home screen, camera access, offline support via service worker |
| **State Management** | Riverpod | Clean, testable, good for async data flows |
| **Local DB** | Drift (SQLite for web via IndexedDB) | Typed SQL queries, migrations, reactive streams |
| **Barcode Scanning** | `mobile_scanner` | MLKit-based, works in mobile browsers |
| **Google Sheets Sync** | `googleapis` + `google_sign_in` | OAuth2, Sheets API v4 |
| **HTTP Client** | `dio` | For barcode API lookups with retry/timeout support |
| **Routing** | `go_router` | Declarative URL-based routing |
| **Image Storage** | IndexedDB blobs | Receipt photos stored locally in browser storage |

---

## 3. Data Model

### 3.1 InventoryItem

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | int (auto) | Yes | Primary key |
| `dateAdded` | date | Yes | When the item was acquired |
| `barcode` | string | No | UPC/EAN — nullable for retro cartridges without barcodes |
| `itemDescription` | string | Yes | e.g. "Resident Evil Biohazard Gold Edition Xbox" |
| `type` | enum | Yes | Game, DVD, Blu-ray, CD, Book, Other |
| `cost` | decimal | Yes | What the reseller paid |
| `quantity` | int | Yes | Defaults to 1 |
| `platform` | string | No | Selling platform (eBay, Mercari, Poshmark, etc.) |
| `status` | enum | Yes | Active, Sold, Personal |
| `dateSold` | date | No | Set when status changes to Sold |
| `daysToSell` | int (computed) | — | `dateSold - dateAdded`, computed on read |
| `saleNumber` | string | No | Order/reference number |
| `comments` | string | No | Freeform notes |
| `imageUrl` | string | No | Product image from barcode lookup or user photo |
| `lookupName` | string | No | Product name returned by barcode API (kept separate so user can override `itemDescription`) |
| `lookupDescription` | string | No | Extended description from barcode API |

### 3.2 Expense

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | int (auto) | Yes | Primary key |
| `date` | date | Yes | Purchase date |
| `merchant` | string | Yes | Walmart, Staples, USPS, Walgreens, etc. |
| `receiptImagePath` | string | No | Local reference to receipt photo blob in IndexedDB |
| `upc` | string | No | Barcode of the supply item |
| `itemDescription` | string | Yes | e.g. "Bubble wrap" |
| `quantity` | int | Yes | Number of units purchased |
| `unitPrice` | decimal | Yes | Price per unit |
| `total` | decimal (computed) | — | `quantity × unitPrice`, computed on read |
| `expenseType` | enum | Yes | Shipping, Equipment, Software, Travel, Other |
| `taxAmount` | decimal | No | Sales tax paid |

### 3.3 BarcodeCache

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `barcode` | string | Yes | Primary key (the UPC/EAN) |
| `productName` | string | No | Name returned by API |
| `description` | string | No | Extended description |
| `imageUrl` | string | No | Product image URL |
| `category` | string | No | Product category |
| `source` | string | Yes | Which API returned this result |
| `fetchedAt` | datetime | Yes | Timestamp for cache freshness |

The `BarcodeCache` avoids redundant API calls — frequently purchased supplies (e.g. bubble
wrap UPC `810142295154`) are looked up once and reused.

---

## 4. UX Design

Visual mockups for all key screens are provided as the UX reference. All screens follow a
dark-mode Material Design theme with a deep blue-gray palette.

### 4.1 Screen Inventory

| Screen | Mockup | Purpose |
|--------|--------|---------|
| Dashboard | [dashboard_mockup.jpg](flipbin-mockups/dashboard_mockup_1790540000765.jpg) | Home screen with inventory/expense summary cards and primary action buttons |
| Barcode Scanner | [scan_screen_mockup.jpg](flipbin-mockups/scan_screen_mockup_1790540009882.jpg) | Camera viewfinder with scan overlay, product lookup result card, add-to buttons |
| Inventory List | [inventory_list_mockup.jpg](flipbin-mockups/inventory_list_mockup_1790540018082.jpg) | Searchable/filterable item list with thumbnails, type badges, cost, status chips |
| Item Detail/Edit | [item_detail_mockup.jpg](flipbin-mockups/item_detail_mockup_1790540025779.jpg) | Full item form with product image, all data fields, save/delete actions |
| Expenses List | [expenses_list_mockup.jpg](flipbin-mockups/expenses_list_mockup_1790540034054.jpg) | Monthly expense list with receipt thumbnails, filters, running total |

### 4.2 Navigation

Bottom navigation bar with 4 tabs:
- **Home** — Dashboard with summary stats and action buttons
- **Inventory** — Full inventory list with search/filter
- **Expenses** — Expense list with search/filter by type and month
- **Settings** — Google account, sync, export/import options

### 4.3 Key Interactions

1. **Scan → Add flow:** Tap "Scan Barcode" → camera opens → barcode detected → API
   lookup runs → result card with product image/name/category appears → user taps
   "Add to Inventory" or "Add to Expenses" → pre-filled form opens → review/edit → Save.

2. **Quick-add without scanning:** Tap "+ Add Item" on Dashboard or FAB on list screens
   for manual entry (retro cartridges without barcodes).

3. **Status change workflow:** On Item Detail screen, change status dropdown from
   "Active" → "Sold" and `dateSold` auto-fills with today's date. `daysToSell` computes
   automatically. Both fields are editable for backdating.

4. **Expense receipt capture:** When adding an expense, tap the image area to take a
   photo of the receipt. Stored as a blob in IndexedDB.

---

## 5. Barcode Lookup Flow

### 5.1 Cascading API Strategy

```
Scan UPC
  │
  ├─ Check local BarcodeCache
  │    ├─ HIT  → Use cached data (instant, free, offline)
  │    └─ MISS → Try APIs in order:
  │
  ├─ 1. UPC Database API
  │      └─ Returns: name, description, image, category
  │      └─ Free tier available, broad retail product coverage
  │
  ├─ 2. Open Food Facts API
  │      └─ Returns: name, image, category
  │      └─ Free, community-driven
  │
  └─ 3. Manual entry fallback
         └─ UPC string populates the barcode field
         └─ User types description manually
         └─ Toast: "No product found for this barcode"

Result → Save to BarcodeCache → Pre-fill the Add Item/Expense form
```

### 5.2 Key Behaviors

- **Cache-first:** Once a barcode is looked up, subsequent scans of the same UPC use
  the cached result. No redundant API calls.
- **Offline resilience:** If no network, the barcode string still populates the UPC field.
  User fills in details manually. An optional "Retry Lookup" button appears when
  connectivity returns.
- **Editable results:** API data pre-fills the form but every field is editable. The API
  name is stored in `lookupName` while the user's description goes in `itemDescription`,
  so the user always has full control.
- **Timeout:** API calls time out after 5 seconds to avoid blocking the user.

---

## 6. Google Sheets Sync

### 6.1 Authentication

- Google Sign-In via OAuth2 on the Settings screen
- Scopes: Google Sheets API (read/write), Google Drive API (create files)
- Token stored locally; user signs in once

### 6.2 Sync Behavior

| Action | Behavior |
|--------|----------|
| **First sync** | Creates a new Google Sheet titled "FlipBin Export" in the user's Drive with two tabs: "Inventory" and "Expenses" |
| **Subsequent syncs** | Full overwrite — clears the sheet and writes all current data fresh |
| **Trigger** | Manual only — user taps "Sync Now" in Settings. No auto-sync. |

### 6.3 Export Column Layout

Matches the user's existing spreadsheet format for familiarity.

**Inventory tab columns:**
`Date Added | Barcode UPC | Item Description | Type | Cost | Platform | Status | Date Sold | Personal Use Date | DaysToSell | Comments | Sale Nbr`

**Expenses tab columns:**
`Date | Merchant | Receipt Image | UPC | Item Desc | Qty | Price | Total | Type | With Tax`

> The "Receipt Image" column exports the filename reference only, not the image binary.

### 6.4 What Sync Does NOT Do

- No real-time or automatic sync
- No bi-directional merge (the app is the source of truth, the Sheet is the backup)
- No image upload (structured data only)

### 6.5 Future Enhancement: Import from Google Sheets

> [!NOTE]
> **Planned for a future release:** Provide import logic to read data from a user-specified
> Google Sheet and load it into the app. This import **overwrites all existing app data**
> with the sheet contents. Use case: migrating existing spreadsheet data into FlipBin, or
> restoring from a backup.

---

## 7. Error Handling & Edge Cases

### 7.1 Barcode Scanning

| Scenario | Behavior |
|----------|----------|
| Camera permission denied | Instructional message with steps to enable in browser settings |
| Barcode won't scan (damaged/blurry) | Manual UPC text entry field below the viewfinder |
| API lookup returns no results | UPC populates the form, "No product found" toast, manual entry |
| No network during scan | Barcode captured, lookup skipped, manual entry with "Retry Lookup" option |

### 7.2 Data Entry

| Scenario | Behavior |
|----------|----------|
| Required fields missing | Save button disabled with inline validation hints |
| Duplicate barcode in inventory | Allowed without warning — user may buy the same item multiple times |
| Status → "Sold" | Auto-fills `dateSold` to today, computes `daysToSell`. Both editable for backdating. |
| Decimal cost entry | Currency input formatted to 2 decimal places |

### 7.3 Google Sheets Sync

| Scenario | Behavior |
|----------|----------|
| Not signed in | "Sign in with Google" button shown, sync button disabled |
| Network fails mid-sync | Error toast: "Sync failed — your data is safe locally. Try again." No partial writes. |
| Sheet deleted from Drive | Next sync creates a fresh sheet |

### 7.4 Storage

| Scenario | Behavior |
|----------|----------|
| Browser storage >80% quota | Warning banner on Dashboard |
| User clears browser data | ⚠️ Data loss — Settings screen shows "last synced" timestamp and encourages regular Google Sheets backups |

---

## 8. Project Structure

```
flipbin/
├── lib/
│   ├── main.dart                  # App entry point, provider scope, router
│   ├── app/
│   │   ├── router.dart            # GoRouter configuration
│   │   └── theme.dart             # Dark theme definition
│   ├── models/
│   │   ├── inventory_item.dart    # InventoryItem entity
│   │   ├── expense.dart           # Expense entity
│   │   ├── barcode_cache.dart     # BarcodeCache entity
│   │   └── enums.dart             # ItemType, ItemStatus, ExpenseType enums
│   ├── database/
│   │   ├── database.dart          # Drift database class, tables, DAOs
│   │   └── database.g.dart        # Generated Drift code
│   ├── services/
│   │   ├── barcode_lookup_service.dart   # Cascading API lookup logic
│   │   ├── google_sheets_service.dart    # OAuth + Sheets API sync
│   │   └── image_storage_service.dart    # IndexedDB blob storage for receipts
│   ├── providers/
│   │   ├── database_provider.dart        # Drift DB provider
│   │   ├── inventory_provider.dart       # Inventory list/filter state
│   │   ├── expense_provider.dart         # Expense list/filter state
│   │   ├── scanner_provider.dart         # Scanner + lookup state
│   │   └── sync_provider.dart            # Google Sheets sync state
│   └── screens/
│       ├── dashboard/
│       │   └── dashboard_screen.dart
│       ├── scanner/
│       │   └── scanner_screen.dart
│       ├── inventory/
│       │   ├── inventory_list_screen.dart
│       │   └── item_detail_screen.dart
│       ├── expenses/
│       │   ├── expense_list_screen.dart
│       │   └── expense_detail_screen.dart
│       └── settings/
│           └── settings_screen.dart
├── web/
│   ├── index.html
│   ├── manifest.json              # PWA manifest
│   └── service_worker.js          # Offline caching
├── test/
│   ├── models/
│   ├── services/
│   ├── providers/
│   └── screens/
└── pubspec.yaml
```

---

## 9. Scope Summary

### MVP (This Build)

- ✅ Dashboard with summary stats
- ✅ Barcode scanning with cascading API lookup + local cache
- ✅ Inventory CRUD (add, edit, delete, status change)
- ✅ Expense CRUD with receipt photo capture
- ✅ Search and filter on both lists
- ✅ Google Sign-In + manual Sheets export (Sync Now)
- ✅ PWA installable with offline support
- ✅ Dark mode Material Design UI per mockups

### Future Enhancements (Not in MVP)

- 🔮 **Import from Google Sheets** — read a user-specified Google Sheet and overwrite all app data (migration/restore scenario)
- 🔮 Receipt image backup to Google Drive
- 🔮 PriceCharting API integration for game/media market pricing
- 🔮 eBay API integration for sold comps
- 🔮 Advanced reporting/analytics dashboard
- 🔮 Batch barcode scanning (scan multiple items in succession)
- 🔮 CSV export
