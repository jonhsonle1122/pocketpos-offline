# PocketPOS Offline — Flutter POS + Inventory (Full App Source Code)

A complete, working point-of-sale and inventory app for Android that runs a
small shop **entirely offline**: no server, no hosting, no accounts, no
monthly backend costs. Install it, pair a thermal printer, and start
selling in about 15 minutes.

Built with Flutter (Material 3) + SQLite. All data lives on the device.

> Working product name — rename it in one place (`lib/config/app_config.dart`,
> see the Rebrand guide below).

---

## Features

- **Sell (checkout)** — product grid with photos/initials, category chips,
  text search, camera barcode scan-to-add, cart with quantity steppers,
  percent or fixed discounts, tax added on top *or* included in prices
  (configurable), hold/park a sale and resume it later.
- **Payment** — Cash / Card / Other recording, cash keypad with quick-tender
  chips, **change due with a denomination breakdown** ("dispense 1× $5,
  2× $1…"), and a hard block when the tendered cash is insufficient.
- **Receipts & printing** — ESC/POS thermal printing over **Bluetooth, USB
  and Network** (58mm and 80mm), receipt preview when no printer is
  connected (the app never blocks a sale), auto-print toggle, cash-drawer
  kick toggle, test print, reprint from order history.
- **Products & inventory** — full CRUD with categories, barcodes, cost and
  sale prices, product photos, active/inactive flag, low-stock thresholds
  and badges, out-of-stock protection at the till.
- **Stock control** — stock in/out adjustments with reasons (Restock
  purchase, Damaged, Expired, Correction, Customer return), a full
  movement audit log, and a hard rule that stock never goes below zero.
- **Orders** — sales history grouped by day with day totals, order-number
  search, full order detail, receipt reprint, and **void sale** (restores
  stock, keeps the audit record, excluded from reports).
- **Reports** — Today / Week / Month: revenue, order count, average
  basket, profit estimate, hourly (today) or daily bar chart, top
  products, low-stock alerts. **Export to Excel (.xlsx) and CSV.**
- **Backup & restore** — one versioned JSON file with everything
  (products, sales, stock movements, settings). Restore validates the
  file first and replaces data atomically.
- **First-run setup** — a 2-minute welcome flow: shop name, currency,
  tax rate, then either start empty or explore with demo data
  (sample "Mini Mart" shop with products and backdated sales).

Currencies included: USD, EUR, GBP, AUD, CAD, INR, JPY, VND — each with
cash denominations for the change breakdown.

## Quickstart (< 15 minutes to a running demo)

Prerequisites: Flutter stable (this package was built with Flutter 3.47.9 /
Dart 3.13.7) and an Android device or emulator.

```bash
cd app
flutter pub get
flutter run            # pick your Android device
```

On first launch choose **Explore with demo data** — the app seeds a sample
shop with 12 products and sales for today and yesterday, so checkout,
reports and exports work immediately. No configuration files, no server,
no API keys.

To build an APK instead:

```bash
flutter build apk --debug      # quick test build
flutter build apk --release    # see "Release builds & signing" below
```

## Rebrand guide

Everything product-specific is centralised:

1. **`lib/config/app_config.dart`** — the single rebrand point: app name,
   tagline, brand colour (deep teal `#0F766E`), accent colour, default
   currency/tax, support e-mail placeholder, version label.
2. **Android app label** — `android/app/src/main/AndroidManifest.xml`
   (`android:label="PocketPOS Offline"`).
3. **Application ID** — `android/app/build.gradle.kts`
   (`com.pocketpos.offline` is a placeholder; set your own and move the
   `MainActivity.kt` package folder to match).
4. **App icon** — replace the launcher icons in
   `android/app/src/main/res/mipmap-*` (or use a generator such as
   `flutter_launcher_icons`).
5. **Shop identity shown on receipts** (shop name, address, phone, footer)
   is *end-user data*, edited in the app under Settings — not code.

## Printer setup (summary)

1. Power on any standard **ESC/POS** thermal printer (58mm or 80mm).
2. In the app: **Settings → Printer → Printer settings**.
3. Choose the connection tab — **Bluetooth** (pair the printer in Android
   settings first), **USB** (OTG cable), or **Network** (same Wi-Fi; use
   *Search devices* or *Add by IP*, port 9100).
4. Tap **Connect**, pick the paper width, run a **Test print**.
5. Optional: enable *Auto-print receipt after payment* and *Open cash
   drawer when printing*.

No printer? Sales continue normally and the receipt is shown as an
on-screen preview that can be reprinted later from Orders.

## Architecture

Clean, modular, no code generation:

```
lib/
  config/app_config.dart     Single rebrand point + currency table
  domain/                    Pure Dart business logic (unit-tested)
    cart.dart                  Cart lines, discount & tax totals math
    money.dart                 Integer-cents formatting, change breakdown
  data/
    app_database.dart          SQLite schema (sqflite)
    models.dart                Product, Sale, SaleItem, AppSettings, reports
    repositories/              Product, Sale, Settings, Report repositories
  services/
    printer_service.dart       PrinterService interface + ESC/POS impl
    receipt_builder.dart       Receipt text lines + ESC/POS bytes
    export_service.dart        CSV writer + built-in XLSX (OOXML) writer
    backup_service.dart        Versioned JSON backup / restore
    seed_service.dart          Demo shop data
  state/                     provider ChangeNotifiers (AppState, cart, catalog)
  screens/                   The 12 screens (welcome → settings)
  widgets/                   Shared UI (cart panel, product tile, money rows…)
```

Money is **integer cents everywhere** — never doubles — so totals are exact.
Sales are written in a single database transaction together with their
stock decrements and audit movements.

State management is `provider` (ChangeNotifier). The database layer depends
only on `sqflite`'s `Database` interface, which is what makes the
repository-level unit tests with an in-memory ffi database possible.

### A note on the XLSX exporter

The `excel` package is deliberately *not* used: `excel` 4.0.6 does not
compile against `archive` ^4, which the thermal-printer plugin requires
(via `image`). `export_service.dart` therefore writes standards-compliant
OOXML `.xlsx` files directly (real numeric cells, bold header, totals
row). The output is verified by unit tests that unzip the file and assert
its contents.

## Testing

```bash
flutter analyze   # must report: No issues found
flutter test      # 24 tests
```

Covered by tests: cart totals for both discount types and both tax modes,
stock caps, change denomination breakdown, money parsing/formatting, sale
completion decrementing stock, void restoring stock, insufficient-tender
rejection, below-zero stock protection, report aggregation for a seeded
day (revenue/orders/profit/hourly buckets/top products, voided sales
excluded), backup export → import round-trip equality, and CSV/XLSX
export content.

## Release builds & signing

`flutter build apk --release` in a fresh checkout signs with the **debug
key** (Flutter's default). That is fine for testing but **you must add
your own signing keystore before selling or publishing**:

1. Create a keystore: `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Create `android/key.properties` with `storePassword`, `keyPassword`,
   `keyAlias` and `storeFile` (do not commit real passwords).
3. Wire a `signingConfigs.release` block in `android/app/build.gradle.kts`
   that reads `key.properties`, and set it as the release signing config.
4. Rebuild: `flutter build apk --release` (or `appbundle` for Play).

## Support scope

What the seller supports (suggested wording for your listing): installation
help using this README, questions about the documented features, and bug
fixes for the current version. Customisation, hosting (none needed), and
third-party printer hardware troubleshooting are out of scope. The Extended
license optionally includes one setup assist.

## Known limitations

- **Android only.** iOS is not included (USB host printing is an Android
  capability; iOS would be Bluetooth-only). Windows desktop is a possible
  future add-on — the printer stack supports it, but it is **not** part of
  this package.
- **Payments are recorded, not processed.** Card/Other mean "paid by that
  method" — there is no payment-gateway integration by design (offline).
- Single device, single shop, no cloud sync — by design.
- Product quantities are whole units (no weighed/fractional items).
- Physical printing could not be verified in the build environment used
  for this package (a VM without printer hardware or a working Android
  build daemon — see `BUILD-LOG.md` in the venture folder); the printing
  code compiles and follows the ESC/POS plugin's documented API, and every
  print path degrades gracefully to the receipt preview. **Test with your
  own printer before going live.**
- The demo shop and sample data are in English with USD defaults; set your
  currency/tax in the welcome flow or Settings.

## License

Commercial source-code license — see `LICENSE`. One purchase covers one
end product (Regular) per the marketplace terms; final license wording is
set by the seller at listing time.
