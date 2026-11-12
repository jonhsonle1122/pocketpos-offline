# Changelog

## 1.0.0 — 2026-11-11

Initial release.

- Complete offline POS: sell/checkout with cart, hold/resume, discounts
  (percent/fixed), tax added or included, barcode scan-to-add.
- Payment screen with cash keypad, quick-tender chips, change due with
  denomination breakdown, insufficient-tender protection.
- ESC/POS thermal printing (Bluetooth / USB / Network, 58/80mm) behind a
  `PrinterService` interface, with receipt-preview fallback, auto-print
  and cash-drawer options, test print and reprint.
- Products & inventory CRUD, categories, photos, low-stock badges and
  thresholds, stock adjustments with reasons and a movement audit log.
- Orders history grouped by day, order detail, void sale with stock
  restoration.
- Reports (Today/Week/Month) with revenue, orders, average basket, profit
  estimate, hourly/daily charts and top products; Excel (.xlsx) and CSV
  export.
- Versioned JSON backup/restore of the whole database.
- First-run welcome flow with optional demo data ("Mini Mart").
- 24 unit tests; `flutter analyze` clean.
