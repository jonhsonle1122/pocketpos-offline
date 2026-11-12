/// Plain data models for the POS. Money fields are always integer cents.
library;

class Category {
  final int? id;
  final String name;

  const Category({this.id, required this.name});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class Product {
  final int? id;
  final String name;
  final int? categoryId;
  final String? barcode;
  final int costCents;
  final int priceCents;
  final int stockQty;
  final int lowStockThreshold;
  final bool active;
  final String? photoPath;
  final DateTime? createdAt;

  const Product({
    this.id,
    required this.name,
    this.categoryId,
    this.barcode,
    this.costCents = 0,
    required this.priceCents,
    this.stockQty = 0,
    this.lowStockThreshold = 5,
    this.active = true,
    this.photoPath,
    this.createdAt,
  });

  bool get isOutOfStock => stockQty <= 0;
  bool get isLowStock => stockQty > 0 && stockQty <= lowStockThreshold;

  Product copyWith({
    int? id,
    String? name,
    int? categoryId,
    String? barcode,
    int? costCents,
    int? priceCents,
    int? stockQty,
    int? lowStockThreshold,
    bool? active,
    String? photoPath,
    DateTime? createdAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        barcode: barcode ?? this.barcode,
        costCents: costCents ?? this.costCents,
        priceCents: priceCents ?? this.priceCents,
        stockQty: stockQty ?? this.stockQty,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        active: active ?? this.active,
        photoPath: photoPath ?? this.photoPath,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category_id': categoryId,
        'barcode': barcode,
        'cost_cents': costCents,
        'price_cents': priceCents,
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        'active': active ? 1 : 0,
        'photo_path': photoPath,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        categoryId: map['category_id'] as int?,
        barcode: map['barcode'] as String?,
        costCents: (map['cost_cents'] as num?)?.toInt() ?? 0,
        priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
        stockQty: (map['stock_qty'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 5,
        active: (map['active'] as num?)?.toInt() != 0,
        photoPath: map['photo_path'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.name == name &&
      other.categoryId == categoryId &&
      other.barcode == barcode &&
      other.costCents == costCents &&
      other.priceCents == priceCents &&
      other.stockQty == stockQty &&
      other.lowStockThreshold == lowStockThreshold &&
      other.active == active &&
      other.photoPath == photoPath;

  @override
  int get hashCode => Object.hash(id, name, categoryId, barcode, costCents,
      priceCents, stockQty, lowStockThreshold, active, photoPath);
}

enum PaymentMethod {
  cash('Cash'),
  card('Card'),
  other('Other');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod fromName(String? name) => PaymentMethod.values
      .firstWhere((m) => m.name == name, orElse: () => PaymentMethod.cash);
}

enum SaleStatus {
  completed('COMPLETED'),
  voided('VOIDED');

  const SaleStatus(this.dbValue);
  final String dbValue;

  static SaleStatus fromDb(String? value) =>
      value == 'VOIDED' ? SaleStatus.voided : SaleStatus.completed;
}

enum DiscountType {
  none,
  percent,
  fixed;

  String get label => switch (this) {
        DiscountType.none => 'No discount',
        DiscountType.percent => 'Percent (%)',
        DiscountType.fixed => 'Fixed amount',
      };
}

class SaleItem {
  final int? id;
  final int? saleId;
  final int? productId;
  final String productName;
  final int unitPriceCents;
  final int costCents;
  final int qty;

  const SaleItem({
    this.id,
    this.saleId,
    this.productId,
    required this.productName,
    required this.unitPriceCents,
    this.costCents = 0,
    required this.qty,
  });

  int get lineTotalCents => unitPriceCents * qty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'product_name': productName,
        'unit_price_cents': unitPriceCents,
        'cost_cents': costCents,
        'qty': qty,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        id: map['id'] as int?,
        saleId: map['sale_id'] as int?,
        productId: map['product_id'] as int?,
        productName: map['product_name'] as String,
        unitPriceCents: (map['unit_price_cents'] as num).toInt(),
        costCents: (map['cost_cents'] as num?)?.toInt() ?? 0,
        qty: (map['qty'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is SaleItem &&
      other.id == id &&
      other.saleId == saleId &&
      other.productId == productId &&
      other.productName == productName &&
      other.unitPriceCents == unitPriceCents &&
      other.costCents == costCents &&
      other.qty == qty;

  @override
  int get hashCode => Object.hash(
      id, saleId, productId, productName, unitPriceCents, costCents, qty);
}

class Sale {
  final int? id;
  final String orderNumber;
  final DateTime createdAt;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final DiscountType discountType;
  final double discountValue;
  final double taxRatePercent;
  final bool pricesIncludeTax;
  final PaymentMethod paymentMethod;
  final int? tenderedCents;
  final int changeCents;
  final SaleStatus status;
  final List<SaleItem> items;

  const Sale({
    this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.subtotalCents,
    this.discountCents = 0,
    this.taxCents = 0,
    required this.totalCents,
    this.discountType = DiscountType.none,
    this.discountValue = 0,
    this.taxRatePercent = 0,
    this.pricesIncludeTax = false,
    this.paymentMethod = PaymentMethod.cash,
    this.tenderedCents,
    this.changeCents = 0,
    this.status = SaleStatus.completed,
    this.items = const [],
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);

  Sale copyWith({SaleStatus? status, List<SaleItem>? items, int? id}) => Sale(
        id: id ?? this.id,
        orderNumber: orderNumber,
        createdAt: createdAt,
        subtotalCents: subtotalCents,
        discountCents: discountCents,
        taxCents: taxCents,
        totalCents: totalCents,
        discountType: discountType,
        discountValue: discountValue,
        taxRatePercent: taxRatePercent,
        pricesIncludeTax: pricesIncludeTax,
        paymentMethod: paymentMethod,
        tenderedCents: tenderedCents,
        changeCents: changeCents,
        status: status ?? this.status,
        items: items ?? this.items,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'order_number': orderNumber,
        'created_at': createdAt.toIso8601String(),
        'subtotal_cents': subtotalCents,
        'discount_cents': discountCents,
        'tax_cents': taxCents,
        'total_cents': totalCents,
        'discount_type': discountType.name,
        'discount_value': discountValue,
        'tax_rate_percent': taxRatePercent,
        'prices_include_tax': pricesIncludeTax ? 1 : 0,
        'payment_method': paymentMethod.name,
        'tendered_cents': tenderedCents,
        'change_cents': changeCents,
        'status': status.dbValue,
      };

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem> items = const []}) =>
      Sale(
        id: map['id'] as int?,
        orderNumber: map['order_number'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        subtotalCents: (map['subtotal_cents'] as num).toInt(),
        discountCents: (map['discount_cents'] as num?)?.toInt() ?? 0,
        taxCents: (map['tax_cents'] as num?)?.toInt() ?? 0,
        totalCents: (map['total_cents'] as num).toInt(),
        discountType: DiscountType.values.firstWhere(
          (d) => d.name == map['discount_type'],
          orElse: () => DiscountType.none,
        ),
        discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0,
        taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0,
        pricesIncludeTax: (map['prices_include_tax'] as num?)?.toInt() == 1,
        paymentMethod: PaymentMethod.fromName(map['payment_method'] as String?),
        tenderedCents: (map['tendered_cents'] as num?)?.toInt(),
        changeCents: (map['change_cents'] as num?)?.toInt() ?? 0,
        status: SaleStatus.fromDb(map['status'] as String?),
        items: items,
      );

  @override
  bool operator ==(Object other) =>
      other is Sale &&
      other.id == id &&
      other.orderNumber == orderNumber &&
      other.totalCents == totalCents &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, orderNumber, totalCents, status);
}

/// Standard stock adjustment reasons (BUILD-SPEC §6).
const List<String> kStockReasons = [
  'Restock purchase',
  'Damaged',
  'Expired',
  'Correction',
  'Customer return',
];

class StockMovement {
  final int? id;
  final int? productId;
  final String productName;
  final int delta;
  final String reason;
  final String? note;
  final int resultingQty;
  final DateTime createdAt;

  const StockMovement({
    this.id,
    this.productId,
    required this.productName,
    required this.delta,
    required this.reason,
    this.note,
    required this.resultingQty,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'product_name': productName,
        'delta': delta,
        'reason': reason,
        'note': note,
        'resulting_qty': resultingQty,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        productId: map['product_id'] as int?,
        productName: map['product_name'] as String,
        delta: (map['delta'] as num).toInt(),
        reason: map['reason'] as String,
        note: map['note'] as String?,
        resultingQty: (map['resulting_qty'] as num).toInt(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is StockMovement &&
      other.id == id &&
      other.productId == productId &&
      other.productName == productName &&
      other.delta == delta &&
      other.reason == reason &&
      other.note == note &&
      other.resultingQty == resultingQty;

  @override
  int get hashCode =>
      Object.hash(id, productId, productName, delta, reason, note, resultingQty);
}

/// All persisted user settings: shop profile + money + printer preferences.
class AppSettings {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String receiptFooter;
  final String currencyCode;
  final double taxRatePercent;
  final bool pricesIncludeTax;
  final bool setupComplete;

  // Printer preferences
  final int paperMm; // 58 or 80
  final bool autoPrint;
  final bool openDrawerOnPrint;
  final String? savedPrinterJson;
  final String? savedPrinterName;

  const AppSettings({
    this.shopName = '',
    this.shopAddress = '',
    this.shopPhone = '',
    this.receiptFooter = 'Thank you for shopping!',
    this.currencyCode = 'USD',
    this.taxRatePercent = 0,
    this.pricesIncludeTax = false,
    this.setupComplete = false,
    this.paperMm = 80,
    this.autoPrint = true,
    this.openDrawerOnPrint = false,
    this.savedPrinterJson,
    this.savedPrinterName,
  });

  AppSettings copyWith({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    String? receiptFooter,
    String? currencyCode,
    double? taxRatePercent,
    bool? pricesIncludeTax,
    bool? setupComplete,
    int? paperMm,
    bool? autoPrint,
    bool? openDrawerOnPrint,
    String? savedPrinterJson,
    String? savedPrinterName,
    bool clearPrinter = false,
  }) =>
      AppSettings(
        shopName: shopName ?? this.shopName,
        shopAddress: shopAddress ?? this.shopAddress,
        shopPhone: shopPhone ?? this.shopPhone,
        receiptFooter: receiptFooter ?? this.receiptFooter,
        currencyCode: currencyCode ?? this.currencyCode,
        taxRatePercent: taxRatePercent ?? this.taxRatePercent,
        pricesIncludeTax: pricesIncludeTax ?? this.pricesIncludeTax,
        setupComplete: setupComplete ?? this.setupComplete,
        paperMm: paperMm ?? this.paperMm,
        autoPrint: autoPrint ?? this.autoPrint,
        openDrawerOnPrint: openDrawerOnPrint ?? this.openDrawerOnPrint,
        savedPrinterJson: clearPrinter
            ? null
            : (savedPrinterJson ?? this.savedPrinterJson),
        savedPrinterName: clearPrinter
            ? null
            : (savedPrinterName ?? this.savedPrinterName),
      );

  Map<String, String> toKeyValues() => {
        'shopName': shopName,
        'shopAddress': shopAddress,
        'shopPhone': shopPhone,
        'receiptFooter': receiptFooter,
        'currencyCode': currencyCode,
        'taxRatePercent': taxRatePercent.toString(),
        'pricesIncludeTax': pricesIncludeTax ? '1' : '0',
        'setupComplete': setupComplete ? '1' : '0',
        'paperMm': paperMm.toString(),
        'autoPrint': autoPrint ? '1' : '0',
        'openDrawerOnPrint': openDrawerOnPrint ? '1' : '0',
        'savedPrinterJson': savedPrinterJson ?? '',
        'savedPrinterName': savedPrinterName ?? '',
      };

  factory AppSettings.fromKeyValues(Map<String, String> kv) => AppSettings(
        shopName: kv['shopName'] ?? '',
        shopAddress: kv['shopAddress'] ?? '',
        shopPhone: kv['shopPhone'] ?? '',
        receiptFooter: kv['receiptFooter'] ?? 'Thank you for shopping!',
        currencyCode: kv['currencyCode'] ?? 'USD',
        taxRatePercent: double.tryParse(kv['taxRatePercent'] ?? '') ?? 0,
        pricesIncludeTax: kv['pricesIncludeTax'] == '1',
        setupComplete: kv['setupComplete'] == '1',
        paperMm: int.tryParse(kv['paperMm'] ?? '') ?? 80,
        autoPrint: kv['autoPrint'] != '0',
        openDrawerOnPrint: kv['openDrawerOnPrint'] == '1',
        savedPrinterJson:
            (kv['savedPrinterJson'] ?? '').isEmpty ? null : kv['savedPrinterJson'],
        savedPrinterName:
            (kv['savedPrinterName'] ?? '').isEmpty ? null : kv['savedPrinterName'],
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.shopName == shopName &&
      other.shopAddress == shopAddress &&
      other.shopPhone == shopPhone &&
      other.receiptFooter == receiptFooter &&
      other.currencyCode == currencyCode &&
      other.taxRatePercent == taxRatePercent &&
      other.pricesIncludeTax == pricesIncludeTax &&
      other.setupComplete == setupComplete &&
      other.paperMm == paperMm &&
      other.autoPrint == autoPrint &&
      other.openDrawerOnPrint == openDrawerOnPrint &&
      other.savedPrinterJson == savedPrinterJson &&
      other.savedPrinterName == savedPrinterName;

  @override
  int get hashCode => Object.hashAll([
        shopName,
        shopAddress,
        shopPhone,
        receiptFooter,
        currencyCode,
        taxRatePercent,
        pricesIncludeTax,
        setupComplete,
        paperMm,
        autoPrint,
        openDrawerOnPrint,
        savedPrinterJson,
        savedPrinterName,
      ]);
}

/// Aggregated report for a date range (BUILD-SPEC §7).
class ReportData {
  final DateTime start;
  final DateTime end;
  final int revenueCents;
  final int orderCount;
  final int profitCents;
  final List<ReportBucket> buckets;
  final List<TopProduct> topProducts;
  final List<Product> lowStockProducts;

  const ReportData({
    required this.start,
    required this.end,
    required this.revenueCents,
    required this.orderCount,
    required this.profitCents,
    required this.buckets,
    required this.topProducts,
    required this.lowStockProducts,
  });

  int get avgBasketCents => orderCount == 0 ? 0 : revenueCents ~/ orderCount;
}

class ReportBucket {
  final String label;
  final int revenueCents;
  const ReportBucket({required this.label, required this.revenueCents});
}

class TopProduct {
  final String productName;
  final int qtySold;
  final int revenueCents;
  const TopProduct({
    required this.productName,
    required this.qtySold,
    required this.revenueCents,
  });
}
