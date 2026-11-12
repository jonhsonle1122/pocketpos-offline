import 'package:sqflite/sqflite.dart';

import '../app_database.dart';
import '../models.dart';

class SettingsRepository {
  final AppDatabase _database;
  SettingsRepository(this._database);

  Database get _db => _database.db;

  Future<AppSettings> load() async {
    final rows = await _db.query('settings');
    final kv = {for (final r in rows) r['key'] as String: r['value'] as String};
    return AppSettings.fromKeyValues(kv);
  }

  Future<void> save(AppSettings settings) async {
    final batch = _db.batch();
    settings.toKeyValues().forEach((key, value) {
      batch.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }
}
