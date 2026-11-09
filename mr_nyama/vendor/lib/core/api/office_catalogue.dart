class OfficeProduct {
  final String code, name, category, unit, status;
  final String? imageKey;
  final int? price;
  final bool available;
  const OfficeProduct(
      {required this.code,
      required this.name,
      required this.category,
      required this.unit,
      this.imageKey,
      this.price,
      this.available = false,
      this.status = 'active'});
  factory OfficeProduct.fromJson(Map<String, dynamic> p) => OfficeProduct(
      code: p['code'] as String,
      name: p['name'] as String,
      category: p['category'] as String,
      unit: p['unit'] as String,
      imageKey: p['image_key'] as String?,
      price: p['price'] as int?,
      available: p['available'] == true,
      status: p['status'] as String);
}

class OfficeCategory {
  final String code, name;
  const OfficeCategory(this.code, this.name);
}

/// The units every business has; their names come from [Strings.unitName].
const builtInUnits = ['bird', 'piece', 'portion', 'tray', 'kg'];

/// A unit the business added (MN016). Its counting rule is fixed when it is
/// created: whole numbers only, or decimals allowed like kg.
class OfficeUnit {
  final String code, name;
  final bool allowsDecimal;
  const OfficeUnit(this.code, this.name, {this.allowsDecimal = false});
  factory OfficeUnit.fromJson(Map<String, dynamic> u) =>
      OfficeUnit(u['code'] as String, u['name'] as String,
          allowsDecimal: u['allows_decimal'] == true);
}

/// kg, and added units that allow decimals; every other unit is counted
/// in whole numbers.
bool unitAllowsDecimal(String unit, Map<String, OfficeUnit> added) =>
    unit == 'kg' || (added[unit]?.allowsDecimal ?? false);

class OfficeStationPrice {
  final String stationId, stationName;
  final int? amount;
  final bool overridden;
  const OfficeStationPrice(
      this.stationId, this.stationName, this.amount, this.overridden);
}
