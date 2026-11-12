import 'package:intl/intl.dart';

import '../config/app_config.dart';

/// Money helpers. ALL money in this app is stored and computed as integer
/// minor units ("cents") to avoid floating-point rounding errors. Conversion
/// to a display value happens only at formatting time.
class Money {
  Money._();

  static final Map<String, NumberFormat> _formatters = {};

  /// Formats [cents] (minor units) for [currencyCode], e.g. `1234` → `$12.34`.
  static String format(int cents, String currencyCode) {
    final option = currencyByCode(currencyCode);
    final formatter = _formatters.putIfAbsent(
      currencyCode,
      () => NumberFormat.currency(
        locale: 'en_US',
        symbol: option.symbol,
        decimalDigits: option.decimalDigits,
      ),
    );
    return formatter.format(cents / 100);
  }

  /// Formats a single denomination value, e.g. `500` → `$5.00` (for the
  /// change breakdown list, shown without decimals for whole bills).
  static String formatDenomination(int denominationCents, String currencyCode) {
    return format(denominationCents, currencyCode);
  }

  /// Parses a user-typed decimal amount (e.g. "12.50") into cents.
  /// Returns null when the text is not a valid non-negative amount.
  static int? tryParseToCents(String text) {
    final cleaned = text.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  /// Converts cents back to an editable decimal string, e.g. `1250` → `12.50`.
  static String centsToEditText(int cents) =>
      (cents / 100).toStringAsFixed(2);

  /// Greedy change breakdown: how many of each denomination make up
  /// [changeCents]. Returns a map denomination → count (insertion ordered,
  /// largest first), omitting zero counts. A leftover smaller than the
  /// smallest denomination is ignored (standard cashier rounding).
  static Map<int, int> changeBreakdown(int changeCents, String currencyCode) {
    final result = <int, int>{};
    if (changeCents <= 0) return result;
    var remaining = changeCents;
    for (final denomination in currencyByCode(currencyCode).denominations) {
      if (remaining >= denomination) {
        final count = remaining ~/ denomination;
        result[denomination] = count;
        remaining -= count * denomination;
      }
    }
    return result;
  }
}
