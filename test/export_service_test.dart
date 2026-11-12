import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpos_offline/data/repositories/report_repository.dart';
import 'package:pocketpos_offline/services/export_service.dart';

SaleExportRow _row(String order, int total) => SaleExportRow(
      orderNumber: order,
      createdAt: DateTime(2026, 11, 11, 9, 30),
      paymentMethod: 'Cash',
      status: 'COMPLETED',
      itemCount: 2,
      subtotalCents: total,
      discountCents: 0,
      taxCents: 0,
      totalCents: total,
    );

void main() {
  test('CSV export has a header and one line per sale', () {
    final csv = ExportService.buildSalesCsv([_row('#1001', 1500), _row('#1002', 250)]);
    final lines = csv.trim().split('\n');
    expect(lines.length, 3);
    expect(lines.first, startsWith('Order,Date,Payment'));
    expect(lines[1], contains('#1001'));
    expect(lines[1], contains('15.00'));
    expect(lines[2], contains('2.50'));
  });

  test('XLSX export produces a valid, readable workbook', () {
    final bytes =
        ExportService.buildSalesXlsx([_row('#1001', 1500)], 'USD');
    expect(bytes.length, greaterThan(500));
    // XLSX files are ZIP archives: magic bytes "PK".
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4B);

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('xl/worksheets/sheet1.xml'));
    expect(names, contains('xl/workbook.xml'));

    final sheetFile =
        archive.files.firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
    final sheetXml = utf8.decode(sheetFile.content as List<int>);
    expect(sheetXml, contains('Order')); // header
    expect(sheetXml, contains('#1001')); // order number cell
    expect(sheetXml, contains('<v>15.0</v>')); // numeric total cell
    expect(sheetXml, contains('TOTAL'));
  });
}
