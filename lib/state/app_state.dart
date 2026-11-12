import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/app_database.dart';
import '../data/models.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/sale_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/backup_service.dart';
import '../services/printer_service.dart';
import '../services/seed_service.dart';

/// Root app state: owns the database, repositories, services and the
/// current [AppSettings]. Screens read repositories through this object and
/// listen to it for settings changes.
class AppState extends ChangeNotifier {
  late final AppDatabase database;
  late final ProductRepository products;
  late final SaleRepository sales;
  late final SettingsRepository settingsRepo;
  late final ReportRepository reports;
  late final BackupService backup;
  late final SeedService seed;
  final PrinterService printer = ThermalPrinterService();

  AppSettings settings = const AppSettings(
    currencyCode: AppConfig.defaultCurrencyCode,
    taxRatePercent: AppConfig.defaultTaxRatePercent,
    pricesIncludeTax: AppConfig.defaultPricesIncludeTax,
  );

  bool _ready = false;
  bool get isReady => _ready;
  bool get isFirstRun => !settings.setupComplete;

  Future<void> init() async {
    database = await AppDatabase.openDefault();
    products = ProductRepository(database);
    sales = SaleRepository(database);
    settingsRepo = SettingsRepository(database);
    reports = ReportRepository(database);
    backup = BackupService(database);
    seed = SeedService(products, sales);
    settings = await settingsRepo.load();
    printer.restoreSavedPrinter(settings.savedPrinterJson, settings.savedPrinterName);
    _ready = true;
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings next) async {
    settings = next;
    await settingsRepo.save(next);
    notifyListeners();
  }

  /// Re-reads settings from the database (e.g. after a backup restore).
  Future<void> reloadSettings() async {
    settings = await settingsRepo.load();
    printer.restoreSavedPrinter(settings.savedPrinterJson, settings.savedPrinterName);
    notifyListeners();
  }

  /// First-run completion: persist the chosen shop basics and mark setup
  /// done. When [withDemoData] is true the demo catalogue + sales are
  /// seeded and the shop is named "Mini Mart" unless the user typed a name.
  Future<void> completeSetup({
    required String shopName,
    required String currencyCode,
    required double taxRatePercent,
    required bool withDemoData,
  }) async {
    var next = settings.copyWith(
      shopName: shopName.trim().isEmpty && withDemoData
          ? SeedService.demoShopName
          : shopName.trim(),
      currencyCode: currencyCode,
      taxRatePercent: taxRatePercent,
      setupComplete: true,
    );
    await saveSettings(next);
    if (withDemoData) {
      await seed.seedDemo(next);
      // Seeding does not change settings; reload not needed.
    }
    notifyListeners();
  }
}
