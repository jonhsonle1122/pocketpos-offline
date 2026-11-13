import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketpos_offline/data/app_database.dart';
import 'package:pocketpos_offline/data/models.dart';
import 'package:pocketpos_offline/data/repositories/product_repository.dart';
import 'package:pocketpos_offline/data/repositories/report_repository.dart';
import 'package:pocketpos_offline/data/repositories/sale_repository.dart';
import 'package:pocketpos_offline/domain/cart.dart';
import 'package:pocketpos_offline/screens/reports_screen.dart';
import 'package:pocketpos_offline/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regression test for the 1.0.1 Reports fix: on first run the dashboard's
/// initState load can run before the async demo-data seed finishes, and
/// HomeScreen's IndexedStack keeps the screen alive, so the first visit to
/// Reports showed a stale "No sales in this period yet" until the user
/// switched tabs. [ReportsScreenState.reload] (called by HomeScreen on
/// every tab visit) must pick up sales that arrived after the first load.
///
/// NOTE: sqflite FFI completions need the real event loop, but widget
/// tests run in a fake-async zone where those Futures never resolve (the
/// spinner never goes away and pumpAndSettle times out). All database
/// work and all settling therefore go through [WidgetTester.runAsync],
/// and settling uses explicit pumps instead of pumpAndSettle.
void main() {
  AppDatabase? database;
  ProductRepository? products;
  SaleRepository? sales;
  late AppState appState;

  setUp(() {
    sqfliteFfiInit();
  });

  tearDown(() async {
    await database?.close();
    database = null;
  });

  /// Opens the in-memory database and wires a real AppState around it.
  /// Must run inside runAsync: FFI work stalls in the fake-async zone.
  Future<void> openTestDb(WidgetTester tester) async {
    await tester.runAsync(() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: (db, _) => AppDatabase.createSchema(db),
        ),
      );
      database = AppDatabase(db);
      products = ProductRepository(database!);
      sales = SaleRepository(database!);
      appState = AppState()
        ..database = database!
        ..reports = ReportRepository(database!);
    });
  }

  Future<void> recordSaleToday(WidgetTester tester) async {
    await tester.runAsync(() async {
      final widget = await products!.upsertProduct(const Product(
        name: 'Widget',
        costCents: 400,
        priceCents: 1000,
        stockQty: 10,
      ));
      final cart = Cart()..add(widget);
      await sales!.completeSale(
        lines: cart.lines,
        totals: cart.totals(taxRatePercent: 0, pricesIncludeTax: false),
        discountType: DiscountType.none,
        discountValue: 0,
        taxRatePercent: 0,
        pricesIncludeTax: false,
        paymentMethod: PaymentMethod.cash,
        tenderedCents: 1000,
      );
    });
  }

  /// Lets pending real-async work (the FFI report query) finish, then
  /// pumps the rebuilt frame. Replaces pumpAndSettle, which never settles
  /// while the loading spinner is up and the query is stuck in fake async.
  Future<void> settleLoad(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<GlobalKey<ReportsScreenState>> pumpReports(
      WidgetTester tester) async {
    await openTestDb(tester);
    // The ListView builds lazily: use a tall viewport so the whole
    // dashboard (including the lower "Top products" section) is built.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());
    final key = GlobalKey<ReportsScreenState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: Scaffold(body: ReportsScreen(key: key))),
      ),
    );
    await tester.pump(); // First frame: initState's post-frame _load starts.
    await settleLoad(tester);
    return key;
  }

  testWidgets('reload picks up sales recorded after the first load',
      (tester) async {
    final key = await pumpReports(tester);
    expect(find.text('No sales in this period yet'), findsOneWidget);

    // A sale lands after the dashboard's first load (as the demo seed
    // does on first run). Without a reload the stale empty state stays.
    await recordSaleToday(tester);
    await tester.pump();
    expect(find.text('No sales in this period yet'), findsOneWidget);

    // ...but reload() (what HomeScreen calls on every tab visit) does.
    key.currentState!.reload();
    await settleLoad(tester);
    expect(find.text('No sales in this period yet'), findsNothing);
    expect(find.text('Revenue by hour'), findsOneWidget);
    expect(find.text('Top products'), findsOneWidget);
  });

  testWidgets('reload keeps the selected range', (tester) async {
    final key = await pumpReports(tester);
    await recordSaleToday(tester);
    key.currentState!.reload();
    await settleLoad(tester);
    expect(find.text('Revenue by hour'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pump();
    await settleLoad(tester);
    expect(find.text('Revenue by day'), findsOneWidget);

    key.currentState!.reload();
    await settleLoad(tester);
    expect(find.text('Revenue by day'), findsOneWidget);
    expect(find.text('No sales in this period yet'), findsNothing);
  });
}
