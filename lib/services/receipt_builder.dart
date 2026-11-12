import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../domain/money.dart';

/// Builds receipt content from a completed [Sale] and the shop [AppSettings]:
/// fixed-width text lines for the on-screen preview, and ESC/POS bytes for
/// thermal printers. The same lines feed both, so what the cashier previews
/// is what prints.
class ReceiptBuilder {
  /// Characters per line for a paper width: 58mm → 32, 80mm → 48.
  static int charsForPaper(int paperMm) => paperMm <= 58 ? 32 : 48;

  static List<String> buildTextLines(Sale sale, AppSettings settings,
      {int? paperMm}) {
    final width = charsForPaper(paperMm ?? settings.paperMm);
    final cur = settings.currencyCode;
    final lines = <String>[];

    void center(String text) => lines.add(_center(text, width));
    void row(String left, String right) =>
        lines.add(_twoCols(left, right, width));
    void hr() => lines.add('-' * width);

    if (settings.shopName.isNotEmpty) center(settings.shopName.toUpperCase());
    if (settings.shopAddress.isNotEmpty) center(settings.shopAddress);
    if (settings.shopPhone.isNotEmpty) center(settings.shopPhone);
    hr();
    row(sale.orderNumber, DateFormat('dd MMM yyyy HH:mm').format(sale.createdAt));
    hr();
    for (final item in sale.items) {
      lines.add(_clip(item.productName, width));
      row('  ${item.qty} x ${Money.format(item.unitPriceCents, cur)}',
          Money.format(item.lineTotalCents, cur));
    }
    hr();
    row('Subtotal', Money.format(sale.subtotalCents, cur));
    if (sale.discountCents > 0) {
      row('Discount', '-${Money.format(sale.discountCents, cur)}');
    }
    if (sale.taxCents > 0 || sale.taxRatePercent > 0) {
      final label = sale.pricesIncludeTax
          ? 'Tax (incl. ${_trimRate(sale.taxRatePercent)}%)'
          : 'Tax (${_trimRate(sale.taxRatePercent)}%)';
      row(label, Money.format(sale.taxCents, cur));
    }
    row('TOTAL', Money.format(sale.totalCents, cur));
    hr();
    row('Paid by', sale.paymentMethod.label);
    if (sale.paymentMethod == PaymentMethod.cash && sale.tenderedCents != null) {
      row('Cash received', Money.format(sale.tenderedCents!, cur));
      row('Change', Money.format(sale.changeCents, cur));
    }
    if (sale.status == SaleStatus.voided) {
      hr();
      center('*** VOIDED ***');
    }
    hr();
    if (settings.receiptFooter.isNotEmpty) center(settings.receiptFooter);
    return lines;
  }

  /// ESC/POS byte stream for the same receipt.
  static Future<List<int>> buildEscPosBytes(
    Sale sale,
    AppSettings settings, {
    required bool openDrawer,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = settings.paperMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final gen = Generator(paper, profile);
    final width = charsForPaper(settings.paperMm);
    final cur = settings.currencyCode;
    var bytes = <int>[];
    bytes += gen.reset();

    void center(String text, {bool bold = false, PosTextSize? size}) {
      bytes += gen.text(
        _clip(text, width),
        styles: PosStyles(
          align: PosAlign.center,
          bold: bold,
          height: size ?? PosTextSize.size1,
          width: size ?? PosTextSize.size1,
        ),
      );
    }

    void row(String left, String right, {bool bold = false}) {
      final line = _twoCols(left, right, width);
      bytes += gen.text(line, styles: PosStyles(bold: bold));
    }

    if (settings.shopName.isNotEmpty) {
      center(settings.shopName.toUpperCase(),
          bold: true, size: PosTextSize.size2);
    }
    if (settings.shopAddress.isNotEmpty) center(settings.shopAddress);
    if (settings.shopPhone.isNotEmpty) center(settings.shopPhone);
    bytes += gen.hr();
    row(sale.orderNumber,
        DateFormat('dd MMM yyyy HH:mm').format(sale.createdAt));
    bytes += gen.hr();
    for (final item in sale.items) {
      bytes += gen.text(_clip(item.productName, width));
      row('  ${item.qty} x ${Money.format(item.unitPriceCents, cur)}',
          Money.format(item.lineTotalCents, cur));
    }
    bytes += gen.hr();
    row('Subtotal', Money.format(sale.subtotalCents, cur));
    if (sale.discountCents > 0) {
      row('Discount', '-${Money.format(sale.discountCents, cur)}');
    }
    if (sale.taxCents > 0 || sale.taxRatePercent > 0) {
      final label = sale.pricesIncludeTax
          ? 'Tax (incl. ${_trimRate(sale.taxRatePercent)}%)'
          : 'Tax (${_trimRate(sale.taxRatePercent)}%)';
      row(label, Money.format(sale.taxCents, cur));
    }
    row('TOTAL', Money.format(sale.totalCents, cur), bold: true);
    bytes += gen.hr();
    row('Paid by', sale.paymentMethod.label);
    if (sale.paymentMethod == PaymentMethod.cash && sale.tenderedCents != null) {
      row('Cash received', Money.format(sale.tenderedCents!, cur));
      row('Change', Money.format(sale.changeCents, cur));
    }
    if (sale.status == SaleStatus.voided) {
      bytes += gen.hr();
      center('*** VOIDED ***', bold: true);
    }
    bytes += gen.hr();
    if (settings.receiptFooter.isNotEmpty) center(settings.receiptFooter);
    bytes += gen.feed(2);
    if (openDrawer) bytes += gen.drawer();
    bytes += gen.cut();
    return bytes;
  }

  /// Small test ticket printed from Printer settings.
  static Future<List<int>> buildTestBytes(AppSettings settings) async {
    final profile = await CapabilityProfile.load();
    final paper = settings.paperMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final gen = Generator(paper, profile);
    var bytes = <int>[];
    bytes += gen.reset();
    bytes += gen.text(
      settings.shopName.isEmpty ? 'Test print' : settings.shopName.toUpperCase(),
      styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2),
    );
    bytes += gen.text('Printer connection OK',
        styles: const PosStyles(align: PosAlign.center));
    bytes += gen.text(
        DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center));
    bytes += gen.feed(2);
    bytes += gen.cut();
    return bytes;
  }

  static String _center(String text, int width) {
    final clipped = _clip(text, width);
    final pad = (width - clipped.length) ~/ 2;
    return (' ' * (pad < 0 ? 0 : pad)) + clipped;
  }

  static String _twoCols(String left, String right, int width) {
    if (left.length + right.length + 1 <= width) {
      return left + ' ' * (width - left.length - right.length) + right;
    }
    final maxLeft = width - right.length - 1;
    return '${left.substring(0, maxLeft)} $right';
  }

  static String _clip(String text, int width) =>
      text.length <= width ? text : text.substring(0, width);

  static String _trimRate(double rate) {
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');
  }
}
