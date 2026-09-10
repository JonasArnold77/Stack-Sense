/// Eine real gekaufte Packung eines Supplements ("Lager"). Fest an genau
/// einen Stack-Eintrag gekoppelt (stackEntryId), damit sich der Verbrauch aus
/// dem Kalender ableiten lässt. [totalUnits] ist in DERSELBEN Einheit wie die
/// getrackte Dosis des Eintrags (trackableDoseFor(entry).unit) — es gibt
/// bewusst keine mg↔Kapsel-Umrechnung.
class InventoryPackage {
  final String id;
  final String stackEntryId;
  final String productName;
  final String shop;
  final String? reorderUrl;
  final double totalUnits;
  final String unit;
  final DateTime openedAt;
  final double? price;
  final DateTime addedAt;

  const InventoryPackage({
    required this.id,
    required this.stackEntryId,
    required this.productName,
    required this.shop,
    this.reorderUrl,
    required this.totalUnits,
    required this.unit,
    required this.openedAt,
    this.price,
    required this.addedAt,
  });

  InventoryPackage copyWith({
    String? productName,
    String? shop,
    String? reorderUrl,
    double? totalUnits,
    String? unit,
    DateTime? openedAt,
    double? price,
  }) =>
      InventoryPackage(
        id: id,
        stackEntryId: stackEntryId,
        productName: productName ?? this.productName,
        shop: shop ?? this.shop,
        reorderUrl: reorderUrl ?? this.reorderUrl,
        totalUnits: totalUnits ?? this.totalUnits,
        unit: unit ?? this.unit,
        openedAt: openedAt ?? this.openedAt,
        price: price ?? this.price,
        addedAt: addedAt,
      );

  factory InventoryPackage.fromJson(Map<String, dynamic> json) => InventoryPackage(
        id: json['id'] as String,
        stackEntryId: json['stackEntryId'] as String,
        productName: json['productName'] as String,
        shop: json['shop'] as String,
        reorderUrl: json['reorderUrl'] as String?,
        totalUnits: (json['totalUnits'] as num).toDouble(),
        unit: json['unit'] as String,
        openedAt: DateTime.parse(json['openedAt'] as String),
        price: (json['price'] as num?)?.toDouble(),
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stackEntryId': stackEntryId,
        'productName': productName,
        'shop': shop,
        'reorderUrl': reorderUrl,
        'totalUnits': totalUnits,
        'unit': unit,
        'openedAt': openedAt.toIso8601String(),
        'price': price,
        'addedAt': addedAt.toIso8601String(),
      };
}
