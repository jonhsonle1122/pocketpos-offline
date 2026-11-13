# Changelog

## 1.0.1 — 2026-11-13

Polish fixes from real-device testing (no behaviour changes otherwise).

- Branded launcher icon: the default Flutter icon is replaced with the
  PocketPOS receipt icon (legacy `ic_launcher.png` for all densities plus
  an adaptive icon for Android 8.0+), and the launch splash now shows the
  branded icon instead of a blank screen.
- About section shows the real support e-mail instead of the
  `support@example.com` placeholder.
- Reports no longer shows a stale empty state: the dashboard reloads every
  time the Reports tab is selected, so sales completed (or demo data
  seeded) after the first load appear immediately. Overlapping loads are
  guarded so a slow earlier query can never overwrite fresher results.

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
