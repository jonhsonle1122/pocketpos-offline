import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/report_repository.dart';

/// Builds CSV / Excel exports of sales and hands them to the Android share
/// sheet (the buyer can save them to Drive, e-mail them, etc.).
class ExportService {
  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  static const List<String> _headers = [
    'Order',
    'Date',
    'Payment',
    'Status',
    'Items',
    'Subtotal',
    'Discount',
    'Tax',
    'Total',
  ];

  /// Plain CSV with amounts as decimal numbers in the shop's currency units.
  static String buildSalesCsv(List<SaleExportRow> rows) {
    final buffer = StringBuffer();
    buffer.writeln(_headers.join(','));
    for (final r in rows) {
      buffer.writeln([
        _csv(r.orderNumber),
        _csv(_dateFmt.format(r.createdAt)),
        _csv(r.paymentMethod),
        _csv(r.status),
        r.itemCount,
        _amount(r.subtotalCents),
        _amount(r.discountCents),
        _amount(r.taxCents),
        _amount(r.totalCents),
      ].join(','));
    }
    return buffer.toString();
  }

  /// A formatted .xlsx workbook with one "Sales" sheet, written directly
  /// as OOXML (see pubspec.yaml for why the `excel` package is not used).
  /// Text cells use inline strings; money cells are real numbers so the
  /// buyer can sum/filter them in Excel or Google Sheets.
  static List<int> buildSalesXlsx(List<SaleExportRow> rows, String currencyCode) {
    final sheet = StringBuffer();
    sheet.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheet.write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheet.write('<cols>'
        '<col min="1" max="1" width="12"/><col min="2" max="2" width="18"/>'
        '<col min="3" max="4" width="12"/><col min="5" max="5" width="8"/>'
        '<col min="6" max="9" width="13"/></cols>');
    sheet.write('<sheetData>');

    void rowXml(int r, List<String> cells) {
      sheet.write('<row r="$r">');
      for (var c = 0; c < cells.length; c++) {
        sheet.write(cells[c]);
      }
      sheet.write('</row>');
    }

    String textCell(int r, int c, String value, {bool bold = false}) {
      final ref = '${_colName(c)}$r';
      final style = bold ? ' s="1"' : '';
      return '<c r="$ref" t="inlineStr"$style><is><t>${_xmlEscape(value)}</t></is></c>';
    }

    String numCell(int r, int c, num value) {
      final ref = '${_colName(c)}$r';
      return '<c r="$ref"><v>$value</v></c>';
    }

    rowXml(1, [
      for (var c = 0; c < _headers.length; c++)
        textCell(1, c, _headers[c], bold: true),
    ]);
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rowIndex = i + 2;
      rowXml(rowIndex, [
        textCell(rowIndex, 0, r.orderNumber),
        textCell(rowIndex, 1, _dateFmt.format(r.createdAt)),
        textCell(rowIndex, 2, r.paymentMethod),
        textCell(rowIndex, 3, r.status),
        numCell(rowIndex, 4, r.itemCount),
        numCell(rowIndex, 5, r.subtotalCents / 100),
        numCell(rowIndex, 6, r.discountCents / 100),
        numCell(rowIndex, 7, r.taxCents / 100),
        numCell(rowIndex, 8, r.totalCents / 100),
      ]);
    }
    final totalRow = rows.length + 2;
    final grandTotal = rows.fold<int>(0, (sum, r) => sum + r.totalCents);
    rowXml(totalRow, [
      textCell(totalRow, 0, 'TOTAL', bold: true),
      for (var c = 1; c < 8; c++) textCell(totalRow, c, ''),
      numCell(totalRow, 8, grandTotal / 100),
    ]);
    sheet.write('</sheetData></worksheet>');

    final files = <String, String>{
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '</Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>',
      'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="Sales" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
          '</Relationships>',
      'xl/styles.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
          '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
          '<fills count="2"><fill><patternFill patternType="none"/></fill>'
          '<fill><patternFill patternType="gray125"/></fill></fills>'
          '<borders count="1"><border/></borders>'
          '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
          '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
          '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
          '</styleSheet>',
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };

    final archive = Archive();
    files.forEach((name, content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    return ZipEncoder().encode(archive);
  }

  static String _colName(int index) {
    // 0 -> A, 25 -> Z, 26 -> AA
    var n = index + 1;
    var name = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      name = String.fromCharCode(65 + rem) + name;
      n = (n - 1) ~/ 26;
    }
    return name;
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  /// Writes [bytes] to a file in the app's export folder and opens the
  /// system share sheet for it. Returns the file so callers can also report
  /// where it was saved.
  static Future<File> shareBytes(
    List<int> bytes,
    String fileName, {
    String? mimeType,
    String? subject,
  }) async {
    final dir = await _exportDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: subject ?? fileName,
      ),
    );
    return file;
  }

  static Future<File> shareText(
    String text,
    String fileName, {
    String mimeType = 'text/csv',
  }) async {
    final dir = await _exportDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(text, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)], subject: fileName),
    );
    return file;
  }

  static Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _amount(int cents) => (cents / 100).toStringAsFixed(2);

  static String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
