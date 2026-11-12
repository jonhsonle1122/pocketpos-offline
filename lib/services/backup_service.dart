import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../data/models.dart';

/// Versioned JSON backup of the ENTIRE database (BUILD-SPEC §10):
///
/// `{version, exportedAt, settings, categories, products, sales, saleItems,
///   stockMovements}`
///
/// Export reads raw rows (lossless); restore validates the payload, then
/// replaces all data inside a single transaction — a failed restore leaves
/// the current data untouched.
class BackupService {
  static const int backupVersion = 1;

  final AppDatabase _database;
  BackupService(this._database);

  Database get _db => _database.db;

  static const List<String> _tables = [
    'categories',
    'products',
    'sales',
    'sale_items',
    'stock_movements',
  ];

  static const Map<String, String> _backupKeys = {
    'categories': 'categories',
    'products': 'products',
    'sales': 'sales',
    'sale_items': 'saleItems',
    'stock_movements': 'stockMovements',
  };

  Future<Map<String, dynamic>> exportData() async {
    final result = <String, dynamic>{
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final settingsRows = await _db.query('settings');
    result['settings'] = {
      for (final r in settingsRows) r['key'] as String: r['value'] as String,
    };
    for (final table in _tables) {
      result[_backupKeys[table]!] = await _db.query(table, orderBy: 'id ASC');
    }
    return result;
  }

  Future<String> exportJson() async =>
      const JsonEncoder.withIndent('  ').convert(await exportData());

  /// Validates [data] as a backup payload. Throws [FormatException] with a
  /// user-readable message when anything essential is missing or wrong.
  static void validate(Map<String, dynamic> data) {
    final version = data['version'];
    if (version is! num || version.toInt() != backupVersion) {
      throw const FormatException(
          'This file is not a compatible PocketPOS backup (version mismatch).');
    }
    for (final key in ['settings', 'categories', 'products', 'sales', 'saleItems', 'stockMovements']) {
      if (!data.containsKey(key)) {
        throw FormatException('Backup file is missing the "$key" section.');
      }
    }
    if (data['settings'] is! Map) {
      throw const FormatException('Backup settings section is invalid.');
    }
    for (final key in ['categories', 'products', 'sales', 'saleItems', 'stockMovements']) {
      if (data[key] is! List) {
        throw FormatException('Backup section "$key" is invalid.');
      }
    }
  }

  /// Parses and validates a JSON backup string.
  static Map<String, dynamic> decodeAndValidate(String jsonText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const FormatException('The selected file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a PocketPOS backup.');
    }
    validate(decoded);
    return decoded;
  }

  /// Replaces ALL data with the backup contents, in one transaction.
  Future<void> importData(Map<String, dynamic> data) async {
    validate(data);
    await _db.transaction((txn) async {
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }
      await txn.delete('settings');

      final settings = (data['settings'] as Map).cast<String, dynamic>();
      for (final entry in settings.entries) {
        await txn.insert('settings', {
          'key': entry.key,
          'value': entry.value.toString(),
        });
      }
      for (final table in _tables) {
        final rows = (data[_backupKeys[table]!] as List).cast<dynamic>();
        for (final raw in rows) {
          final row = (raw as Map).cast<String, dynamic>();
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> importJson(String jsonText) async =>
      importData(decodeAndValidate(jsonText));

  /// The settings contained in a backup (post-restore app state reload).
  static AppSettings settingsFromBackup(Map<String, dynamic> data) {
    final raw = (data['settings'] as Map).cast<String, dynamic>();
    return AppSettings.fromKeyValues(
        raw.map((k, v) => MapEntry(k, v.toString())));
  }
}
