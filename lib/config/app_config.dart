import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// SINGLE REBRAND POINT
///
/// Everything a buyer needs to change to make this app their own product
/// lives in this file (plus the Android app label / icon — see README.md
/// "Rebrand guide"). Change the values below, rebuild, done.
/// ─────────────────────────────────────────────────────────────────────────
class AppConfig {
  AppConfig._();

  /// Product / listing name of the app itself.
  static const String appName = 'PocketPOS Offline';

  /// Short tagline shown on the welcome screen and About section.
  static const String tagline = 'Sell without internet';

  /// Brand seed colour for the Material 3 colour scheme (deep teal).
  static const Color primaryColor = Color(0xFF0F766E);

  /// Accent colour for money totals, warnings and highlights (amber).
  static const Color accentColor = Color(0xFFF59E0B);

  /// Danger colour for destructive actions (void, out of stock).
  static const Color dangerColor = Color(0xFFDC2626);

  /// Currency used for a brand-new install (buyer/end user can change it
  /// later in Settings → Money).
  static const String defaultCurrencyCode = 'USD';

  /// Default tax rate (percent) for a brand-new install.
  static const double defaultTaxRatePercent = 0.0;

  /// Whether default prices include tax for a brand-new install.
  static const bool defaultPricesIncludeTax = false;

  /// Placeholder support e-mail shown in the About section.
  static const String supportEmail = 'support@example.com';

  /// App version label (keep in sync with pubspec.yaml `version:`).
  static const String appVersion = '1.0.0';
}

/// Currencies offered in Settings → Money. Keep the list small and practical.
class CurrencyOption {
  final String code;
  final String symbol;
  final int decimalDigits;

  /// Denominations in minor units (cents), largest first — used for the
  /// change breakdown on the payment screen.
  final List<int> denominations;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.decimalDigits,
    required this.denominations,
  });
}

const List<CurrencyOption> kCurrencies = [
  CurrencyOption(
    code: 'USD',
    symbol: r'$',
    decimalDigits: 2,
    denominations: [10000, 5000, 2000, 1000, 500, 100, 25, 10, 5, 1],
  ),
  CurrencyOption(
    code: 'EUR',
    symbol: '€',
    decimalDigits: 2,
    denominations: [5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5, 2, 1],
  ),
  CurrencyOption(
    code: 'GBP',
    symbol: '£',
    decimalDigits: 2,
    denominations: [5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5, 2, 1],
  ),
  CurrencyOption(
    code: 'AUD',
    symbol: r'$',
    decimalDigits: 2,
    denominations: [10000, 5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5],
  ),
  CurrencyOption(
    code: 'CAD',
    symbol: r'$',
    decimalDigits: 2,
    denominations: [10000, 5000, 2000, 1000, 500, 200, 100, 25, 10, 5],
  ),
  CurrencyOption(
    code: 'INR',
    symbol: '₹',
    decimalDigits: 2,
    denominations: [50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100, 50],
  ),
  CurrencyOption(
    code: 'JPY',
    symbol: '¥',
    decimalDigits: 0,
    denominations: [1000000, 500000, 100000, 50000, 10000, 5000, 1000, 500],
  ),
  CurrencyOption(
    code: 'VND',
    symbol: '₫',
    decimalDigits: 0,
    denominations: [
      50000000, 20000000, 10000000, 5000000, 2000000, 1000000, 500000, 200000,
      100000,
    ],
  ),
];

CurrencyOption currencyByCode(String code) => kCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => kCurrencies.first,
    );
