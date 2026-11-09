// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CatalogProductsTable extends CatalogProducts
    with TableInfo<$CatalogProductsTable, CatalogProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
      'price', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _priceVersionMeta =
      const VerificationMeta('priceVersion');
  @override
  late final GeneratedColumn<String> priceVersion = GeneratedColumn<String>(
      'price_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _imageKeyMeta =
      const VerificationMeta('imageKey');
  @override
  late final GeneratedColumn<String> imageKey = GeneratedColumn<String>(
      'image_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _availableMeta =
      const VerificationMeta('available');
  @override
  late final GeneratedColumn<int> available = GeneratedColumn<int>(
      'available', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _heldMeta = const VerificationMeta('held');
  @override
  late final GeneratedColumn<String> held = GeneratedColumn<String>(
      'held', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cutFromMeta =
      const VerificationMeta('cutFrom');
  @override
  late final GeneratedColumn<String> cutFrom = GeneratedColumn<String>(
      'cut_from', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cutCountMeta =
      const VerificationMeta('cutCount');
  @override
  late final GeneratedColumn<int> cutCount = GeneratedColumn<int>(
      'cut_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        price,
        priceVersion,
        category,
        imageKey,
        available,
        held,
        cutFrom,
        cutCount,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_products';
  @override
  VerificationContext validateIntegrity(Insertable<CatalogProduct> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('price_version')) {
      context.handle(
          _priceVersionMeta,
          priceVersion.isAcceptableOrUnknown(
              data['price_version']!, _priceVersionMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('image_key')) {
      context.handle(_imageKeyMeta,
          imageKey.isAcceptableOrUnknown(data['image_key']!, _imageKeyMeta));
    }
    if (data.containsKey('available')) {
      context.handle(_availableMeta,
          available.isAcceptableOrUnknown(data['available']!, _availableMeta));
    }
    if (data.containsKey('held')) {
      context.handle(
          _heldMeta, held.isAcceptableOrUnknown(data['held']!, _heldMeta));
    }
    if (data.containsKey('cut_from')) {
      context.handle(_cutFromMeta,
          cutFrom.isAcceptableOrUnknown(data['cut_from']!, _cutFromMeta));
    }
    if (data.containsKey('cut_count')) {
      context.handle(_cutCountMeta,
          cutCount.isAcceptableOrUnknown(data['cut_count']!, _cutCountMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogProduct(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price']),
      priceVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}price_version']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      imageKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_key']),
      available: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}available']),
      held: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}held']),
      cutFrom: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cut_from']),
      cutCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cut_count']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $CatalogProductsTable createAlias(String alias) {
    return $CatalogProductsTable(attachedDatabase, alias);
  }
}

class CatalogProduct extends DataClass implements Insertable<CatalogProduct> {
  final String id;
  final String name;

  /// Whole shillings. Null when the server has no price for it yet: such a
  /// product is shown but cannot be sold.
  final int? price;
  final String? priceVersion;
  final String category;

  /// Key of a bundled, approved product photo, if one exists.
  final String? imageKey;

  /// Units the server last recorded with this vendor; null when stock is
  /// not tracked yet.
  final int? available;

  /// The server's own stock of this product (whole-number string), and the
  /// product it is cut from with how many one gives. Unsent sales of pieces
  /// cut what they come from (`stock_pool.dart`). Null when not sent.
  final String? held;
  final String? cutFrom;
  final int? cutCount;
  final int sortOrder;
  const CatalogProduct(
      {required this.id,
      required this.name,
      this.price,
      this.priceVersion,
      required this.category,
      this.imageKey,
      this.available,
      this.held,
      this.cutFrom,
      this.cutCount,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    if (!nullToAbsent || priceVersion != null) {
      map['price_version'] = Variable<String>(priceVersion);
    }
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || imageKey != null) {
      map['image_key'] = Variable<String>(imageKey);
    }
    if (!nullToAbsent || available != null) {
      map['available'] = Variable<int>(available);
    }
    if (!nullToAbsent || held != null) {
      map['held'] = Variable<String>(held);
    }
    if (!nullToAbsent || cutFrom != null) {
      map['cut_from'] = Variable<String>(cutFrom);
    }
    if (!nullToAbsent || cutCount != null) {
      map['cut_count'] = Variable<int>(cutCount);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CatalogProductsCompanion toCompanion(bool nullToAbsent) {
    return CatalogProductsCompanion(
      id: Value(id),
      name: Value(name),
      price:
          price == null && nullToAbsent ? const Value.absent() : Value(price),
      priceVersion: priceVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(priceVersion),
      category: Value(category),
      imageKey: imageKey == null && nullToAbsent
          ? const Value.absent()
          : Value(imageKey),
      available: available == null && nullToAbsent
          ? const Value.absent()
          : Value(available),
      held: held == null && nullToAbsent ? const Value.absent() : Value(held),
      cutFrom: cutFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(cutFrom),
      cutCount: cutCount == null && nullToAbsent
          ? const Value.absent()
          : Value(cutCount),
      sortOrder: Value(sortOrder),
    );
  }

  factory CatalogProduct.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogProduct(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<int?>(json['price']),
      priceVersion: serializer.fromJson<String?>(json['priceVersion']),
      category: serializer.fromJson<String>(json['category']),
      imageKey: serializer.fromJson<String?>(json['imageKey']),
      available: serializer.fromJson<int?>(json['available']),
      held: serializer.fromJson<String?>(json['held']),
      cutFrom: serializer.fromJson<String?>(json['cutFrom']),
      cutCount: serializer.fromJson<int?>(json['cutCount']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<int?>(price),
      'priceVersion': serializer.toJson<String?>(priceVersion),
      'category': serializer.toJson<String>(category),
      'imageKey': serializer.toJson<String?>(imageKey),
      'available': serializer.toJson<int?>(available),
      'held': serializer.toJson<String?>(held),
      'cutFrom': serializer.toJson<String?>(cutFrom),
      'cutCount': serializer.toJson<int?>(cutCount),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CatalogProduct copyWith(
          {String? id,
          String? name,
          Value<int?> price = const Value.absent(),
          Value<String?> priceVersion = const Value.absent(),
          String? category,
          Value<String?> imageKey = const Value.absent(),
          Value<int?> available = const Value.absent(),
          Value<String?> held = const Value.absent(),
          Value<String?> cutFrom = const Value.absent(),
          Value<int?> cutCount = const Value.absent(),
          int? sortOrder}) =>
      CatalogProduct(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price.present ? price.value : this.price,
        priceVersion:
            priceVersion.present ? priceVersion.value : this.priceVersion,
        category: category ?? this.category,
        imageKey: imageKey.present ? imageKey.value : this.imageKey,
        available: available.present ? available.value : this.available,
        held: held.present ? held.value : this.held,
        cutFrom: cutFrom.present ? cutFrom.value : this.cutFrom,
        cutCount: cutCount.present ? cutCount.value : this.cutCount,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  CatalogProduct copyWithCompanion(CatalogProductsCompanion data) {
    return CatalogProduct(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      priceVersion: data.priceVersion.present
          ? data.priceVersion.value
          : this.priceVersion,
      category: data.category.present ? data.category.value : this.category,
      imageKey: data.imageKey.present ? data.imageKey.value : this.imageKey,
      available: data.available.present ? data.available.value : this.available,
      held: data.held.present ? data.held.value : this.held,
      cutFrom: data.cutFrom.present ? data.cutFrom.value : this.cutFrom,
      cutCount: data.cutCount.present ? data.cutCount.value : this.cutCount,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogProduct(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('priceVersion: $priceVersion, ')
          ..write('category: $category, ')
          ..write('imageKey: $imageKey, ')
          ..write('available: $available, ')
          ..write('held: $held, ')
          ..write('cutFrom: $cutFrom, ')
          ..write('cutCount: $cutCount, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, price, priceVersion, category,
      imageKey, available, held, cutFrom, cutCount, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogProduct &&
          other.id == this.id &&
          other.name == this.name &&
          other.price == this.price &&
          other.priceVersion == this.priceVersion &&
          other.category == this.category &&
          other.imageKey == this.imageKey &&
          other.available == this.available &&
          other.held == this.held &&
          other.cutFrom == this.cutFrom &&
          other.cutCount == this.cutCount &&
          other.sortOrder == this.sortOrder);
}

class CatalogProductsCompanion extends UpdateCompanion<CatalogProduct> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> price;
  final Value<String?> priceVersion;
  final Value<String> category;
  final Value<String?> imageKey;
  final Value<int?> available;
  final Value<String?> held;
  final Value<String?> cutFrom;
  final Value<int?> cutCount;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CatalogProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.priceVersion = const Value.absent(),
    this.category = const Value.absent(),
    this.imageKey = const Value.absent(),
    this.available = const Value.absent(),
    this.held = const Value.absent(),
    this.cutFrom = const Value.absent(),
    this.cutCount = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogProductsCompanion.insert({
    required String id,
    required String name,
    this.price = const Value.absent(),
    this.priceVersion = const Value.absent(),
    this.category = const Value.absent(),
    this.imageKey = const Value.absent(),
    this.available = const Value.absent(),
    this.held = const Value.absent(),
    this.cutFrom = const Value.absent(),
    this.cutCount = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<CatalogProduct> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? price,
    Expression<String>? priceVersion,
    Expression<String>? category,
    Expression<String>? imageKey,
    Expression<int>? available,
    Expression<String>? held,
    Expression<String>? cutFrom,
    Expression<int>? cutCount,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (priceVersion != null) 'price_version': priceVersion,
      if (category != null) 'category': category,
      if (imageKey != null) 'image_key': imageKey,
      if (available != null) 'available': available,
      if (held != null) 'held': held,
      if (cutFrom != null) 'cut_from': cutFrom,
      if (cutCount != null) 'cut_count': cutCount,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogProductsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int?>? price,
      Value<String?>? priceVersion,
      Value<String>? category,
      Value<String?>? imageKey,
      Value<int?>? available,
      Value<String?>? held,
      Value<String?>? cutFrom,
      Value<int?>? cutCount,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return CatalogProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      priceVersion: priceVersion ?? this.priceVersion,
      category: category ?? this.category,
      imageKey: imageKey ?? this.imageKey,
      available: available ?? this.available,
      held: held ?? this.held,
      cutFrom: cutFrom ?? this.cutFrom,
      cutCount: cutCount ?? this.cutCount,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (priceVersion.present) {
      map['price_version'] = Variable<String>(priceVersion.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (imageKey.present) {
      map['image_key'] = Variable<String>(imageKey.value);
    }
    if (available.present) {
      map['available'] = Variable<int>(available.value);
    }
    if (held.present) {
      map['held'] = Variable<String>(held.value);
    }
    if (cutFrom.present) {
      map['cut_from'] = Variable<String>(cutFrom.value);
    }
    if (cutCount.present) {
      map['cut_count'] = Variable<int>(cutCount.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('priceVersion: $priceVersion, ')
          ..write('category: $category, ')
          ..write('imageKey: $imageKey, ')
          ..write('available: $available, ')
          ..write('held: $held, ')
          ..write('cutFrom: $cutFrom, ')
          ..write('cutCount: $cutCount, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vendorIdMeta =
      const VerificationMeta('vendorId');
  @override
  late final GeneratedColumn<String> vendorId = GeneratedColumn<String>(
      'vendor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
      'total', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _creditCustomerIdMeta =
      const VerificationMeta('creditCustomerId');
  @override
  late final GeneratedColumn<String> creditCustomerId = GeneratedColumn<String>(
      'credit_customer_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _creditCustomerNameMeta =
      const VerificationMeta('creditCustomerName');
  @override
  late final GeneratedColumn<String> creditCustomerName =
      GeneratedColumn<String>('credit_customer_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('saved'));
  static const VerificationMeta _verificationMeta =
      const VerificationMeta('verification');
  @override
  late final GeneratedColumn<String> verification = GeneratedColumn<String>(
      'verification', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unverified'));
  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        vendorId,
        recordedAt,
        paymentMethod,
        total,
        creditCustomerId,
        creditCustomerName,
        syncStatus,
        verification
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(Insertable<Sale> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('vendor_id')) {
      context.handle(_vendorIdMeta,
          vendorId.isAcceptableOrUnknown(data['vendor_id']!, _vendorIdMeta));
    } else if (isInserting) {
      context.missing(_vendorIdMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    } else if (isInserting) {
      context.missing(_paymentMethodMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
          _totalMeta, total.isAcceptableOrUnknown(data['total']!, _totalMeta));
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('credit_customer_id')) {
      context.handle(
          _creditCustomerIdMeta,
          creditCustomerId.isAcceptableOrUnknown(
              data['credit_customer_id']!, _creditCustomerIdMeta));
    }
    if (data.containsKey('credit_customer_name')) {
      context.handle(
          _creditCustomerNameMeta,
          creditCustomerName.isAcceptableOrUnknown(
              data['credit_customer_name']!, _creditCustomerNameMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('verification')) {
      context.handle(
          _verificationMeta,
          verification.isAcceptableOrUnknown(
              data['verification']!, _verificationMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      vendorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vendor_id'])!,
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_method'])!,
      total: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total'])!,
      creditCustomerId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}credit_customer_id']),
      creditCustomerName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}credit_customer_name']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      verification: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}verification'])!,
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  /// UUID made on the phone; the server accepts each one once.
  final String clientId;
  final String vendorId;
  final DateTime recordedAt;

  /// `cash`, `mpesa` or `credit`, as the vendor chose. An M-Pesa choice is
  /// the vendor's report, not a verified payment.
  final String paymentMethod;
  final int total;

  /// A credit sale's customer (MN018), and their name as shown then.
  final String? creditCustomerId;
  final String? creditCustomerName;

  /// `saved` (on the phone only) until the sync milestone sends it.
  final String syncStatus;

  /// Set only from the server: `unverified` or `verified` (staff checked
  /// it). Vendors cannot change or void a verified sale (VR9).
  final String verification;
  const Sale(
      {required this.clientId,
      required this.vendorId,
      required this.recordedAt,
      required this.paymentMethod,
      required this.total,
      this.creditCustomerId,
      this.creditCustomerName,
      required this.syncStatus,
      required this.verification});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    map['vendor_id'] = Variable<String>(vendorId);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['payment_method'] = Variable<String>(paymentMethod);
    map['total'] = Variable<int>(total);
    if (!nullToAbsent || creditCustomerId != null) {
      map['credit_customer_id'] = Variable<String>(creditCustomerId);
    }
    if (!nullToAbsent || creditCustomerName != null) {
      map['credit_customer_name'] = Variable<String>(creditCustomerName);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['verification'] = Variable<String>(verification);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      clientId: Value(clientId),
      vendorId: Value(vendorId),
      recordedAt: Value(recordedAt),
      paymentMethod: Value(paymentMethod),
      total: Value(total),
      creditCustomerId: creditCustomerId == null && nullToAbsent
          ? const Value.absent()
          : Value(creditCustomerId),
      creditCustomerName: creditCustomerName == null && nullToAbsent
          ? const Value.absent()
          : Value(creditCustomerName),
      syncStatus: Value(syncStatus),
      verification: Value(verification),
    );
  }

  factory Sale.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      clientId: serializer.fromJson<String>(json['clientId']),
      vendorId: serializer.fromJson<String>(json['vendorId']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      total: serializer.fromJson<int>(json['total']),
      creditCustomerId: serializer.fromJson<String?>(json['creditCustomerId']),
      creditCustomerName:
          serializer.fromJson<String?>(json['creditCustomerName']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      verification: serializer.fromJson<String>(json['verification']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'vendorId': serializer.toJson<String>(vendorId),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'total': serializer.toJson<int>(total),
      'creditCustomerId': serializer.toJson<String?>(creditCustomerId),
      'creditCustomerName': serializer.toJson<String?>(creditCustomerName),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'verification': serializer.toJson<String>(verification),
    };
  }

  Sale copyWith(
          {String? clientId,
          String? vendorId,
          DateTime? recordedAt,
          String? paymentMethod,
          int? total,
          Value<String?> creditCustomerId = const Value.absent(),
          Value<String?> creditCustomerName = const Value.absent(),
          String? syncStatus,
          String? verification}) =>
      Sale(
        clientId: clientId ?? this.clientId,
        vendorId: vendorId ?? this.vendorId,
        recordedAt: recordedAt ?? this.recordedAt,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        total: total ?? this.total,
        creditCustomerId: creditCustomerId.present
            ? creditCustomerId.value
            : this.creditCustomerId,
        creditCustomerName: creditCustomerName.present
            ? creditCustomerName.value
            : this.creditCustomerName,
        syncStatus: syncStatus ?? this.syncStatus,
        verification: verification ?? this.verification,
      );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      vendorId: data.vendorId.present ? data.vendorId.value : this.vendorId,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      total: data.total.present ? data.total.value : this.total,
      creditCustomerId: data.creditCustomerId.present
          ? data.creditCustomerId.value
          : this.creditCustomerId,
      creditCustomerName: data.creditCustomerName.present
          ? data.creditCustomerName.value
          : this.creditCustomerName,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      verification: data.verification.present
          ? data.verification.value
          : this.verification,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('clientId: $clientId, ')
          ..write('vendorId: $vendorId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('total: $total, ')
          ..write('creditCustomerId: $creditCustomerId, ')
          ..write('creditCustomerName: $creditCustomerName, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('verification: $verification')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientId, vendorId, recordedAt, paymentMethod,
      total, creditCustomerId, creditCustomerName, syncStatus, verification);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.clientId == this.clientId &&
          other.vendorId == this.vendorId &&
          other.recordedAt == this.recordedAt &&
          other.paymentMethod == this.paymentMethod &&
          other.total == this.total &&
          other.creditCustomerId == this.creditCustomerId &&
          other.creditCustomerName == this.creditCustomerName &&
          other.syncStatus == this.syncStatus &&
          other.verification == this.verification);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> clientId;
  final Value<String> vendorId;
  final Value<DateTime> recordedAt;
  final Value<String> paymentMethod;
  final Value<int> total;
  final Value<String?> creditCustomerId;
  final Value<String?> creditCustomerName;
  final Value<String> syncStatus;
  final Value<String> verification;
  final Value<int> rowid;
  const SalesCompanion({
    this.clientId = const Value.absent(),
    this.vendorId = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.total = const Value.absent(),
    this.creditCustomerId = const Value.absent(),
    this.creditCustomerName = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.verification = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String clientId,
    required String vendorId,
    required DateTime recordedAt,
    required String paymentMethod,
    required int total,
    this.creditCustomerId = const Value.absent(),
    this.creditCustomerName = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.verification = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientId = Value(clientId),
        vendorId = Value(vendorId),
        recordedAt = Value(recordedAt),
        paymentMethod = Value(paymentMethod),
        total = Value(total);
  static Insertable<Sale> custom({
    Expression<String>? clientId,
    Expression<String>? vendorId,
    Expression<DateTime>? recordedAt,
    Expression<String>? paymentMethod,
    Expression<int>? total,
    Expression<String>? creditCustomerId,
    Expression<String>? creditCustomerName,
    Expression<String>? syncStatus,
    Expression<String>? verification,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (vendorId != null) 'vendor_id': vendorId,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (total != null) 'total': total,
      if (creditCustomerId != null) 'credit_customer_id': creditCustomerId,
      if (creditCustomerName != null)
        'credit_customer_name': creditCustomerName,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (verification != null) 'verification': verification,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith(
      {Value<String>? clientId,
      Value<String>? vendorId,
      Value<DateTime>? recordedAt,
      Value<String>? paymentMethod,
      Value<int>? total,
      Value<String?>? creditCustomerId,
      Value<String?>? creditCustomerName,
      Value<String>? syncStatus,
      Value<String>? verification,
      Value<int>? rowid}) {
    return SalesCompanion(
      clientId: clientId ?? this.clientId,
      vendorId: vendorId ?? this.vendorId,
      recordedAt: recordedAt ?? this.recordedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      total: total ?? this.total,
      creditCustomerId: creditCustomerId ?? this.creditCustomerId,
      creditCustomerName: creditCustomerName ?? this.creditCustomerName,
      syncStatus: syncStatus ?? this.syncStatus,
      verification: verification ?? this.verification,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (vendorId.present) {
      map['vendor_id'] = Variable<String>(vendorId.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (creditCustomerId.present) {
      map['credit_customer_id'] = Variable<String>(creditCustomerId.value);
    }
    if (creditCustomerName.present) {
      map['credit_customer_name'] = Variable<String>(creditCustomerName.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (verification.present) {
      map['verification'] = Variable<String>(verification.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('clientId: $clientId, ')
          ..write('vendorId: $vendorId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('total: $total, ')
          ..write('creditCustomerId: $creditCustomerId, ')
          ..write('creditCustomerName: $creditCustomerName, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('verification: $verification, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SaleLinesTable extends SaleLines
    with TableInfo<$SaleLinesTable, SaleLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _saleClientIdMeta =
      const VerificationMeta('saleClientId');
  @override
  late final GeneratedColumn<String> saleClientId = GeneratedColumn<String>(
      'sale_client_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sales (client_id)'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceMeta =
      const VerificationMeta('unitPrice');
  @override
  late final GeneratedColumn<int> unitPrice = GeneratedColumn<int>(
      'unit_price', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _priceVersionMeta =
      const VerificationMeta('priceVersion');
  @override
  late final GeneratedColumn<String> priceVersion = GeneratedColumn<String>(
      'price_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lineTotalMeta =
      const VerificationMeta('lineTotal');
  @override
  late final GeneratedColumn<int> lineTotal = GeneratedColumn<int>(
      'line_total', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _exceedsRecordedStockMeta =
      const VerificationMeta('exceedsRecordedStock');
  @override
  late final GeneratedColumn<bool> exceedsRecordedStock = GeneratedColumn<bool>(
      'exceeds_recorded_stock', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("exceeds_recorded_stock" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        saleClientId,
        productId,
        productName,
        quantity,
        unitPrice,
        priceVersion,
        lineTotal,
        exceedsRecordedStock
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_lines';
  @override
  VerificationContext validateIntegrity(Insertable<SaleLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sale_client_id')) {
      context.handle(
          _saleClientIdMeta,
          saleClientId.isAcceptableOrUnknown(
              data['sale_client_id']!, _saleClientIdMeta));
    } else if (isInserting) {
      context.missing(_saleClientIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(_unitPriceMeta,
          unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta));
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('price_version')) {
      context.handle(
          _priceVersionMeta,
          priceVersion.isAcceptableOrUnknown(
              data['price_version']!, _priceVersionMeta));
    }
    if (data.containsKey('line_total')) {
      context.handle(_lineTotalMeta,
          lineTotal.isAcceptableOrUnknown(data['line_total']!, _lineTotalMeta));
    } else if (isInserting) {
      context.missing(_lineTotalMeta);
    }
    if (data.containsKey('exceeds_recorded_stock')) {
      context.handle(
          _exceedsRecordedStockMeta,
          exceedsRecordedStock.isAcceptableOrUnknown(
              data['exceeds_recorded_stock']!, _exceedsRecordedStockMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      saleClientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_client_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      unitPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unit_price'])!,
      priceVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}price_version']),
      lineTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}line_total'])!,
      exceedsRecordedStock: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}exceeds_recorded_stock'])!,
    );
  }

  @override
  $SaleLinesTable createAlias(String alias) {
    return $SaleLinesTable(attachedDatabase, alias);
  }
}

class SaleLine extends DataClass implements Insertable<SaleLine> {
  final int id;
  final String saleClientId;
  final String productId;
  final String productName;
  final int quantity;

  /// The price the vendor saw, and its version, at the moment of sale.
  final int unitPrice;
  final String? priceVersion;
  final int lineTotal;

  /// The phone's records showed fewer units than sold. The sale is still
  /// recorded; the server raises an "oversold" exception for staff.
  final bool exceedsRecordedStock;
  const SaleLine(
      {required this.id,
      required this.saleClientId,
      required this.productId,
      required this.productName,
      required this.quantity,
      required this.unitPrice,
      this.priceVersion,
      required this.lineTotal,
      required this.exceedsRecordedStock});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sale_client_id'] = Variable<String>(saleClientId);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price'] = Variable<int>(unitPrice);
    if (!nullToAbsent || priceVersion != null) {
      map['price_version'] = Variable<String>(priceVersion);
    }
    map['line_total'] = Variable<int>(lineTotal);
    map['exceeds_recorded_stock'] = Variable<bool>(exceedsRecordedStock);
    return map;
  }

  SaleLinesCompanion toCompanion(bool nullToAbsent) {
    return SaleLinesCompanion(
      id: Value(id),
      saleClientId: Value(saleClientId),
      productId: Value(productId),
      productName: Value(productName),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      priceVersion: priceVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(priceVersion),
      lineTotal: Value(lineTotal),
      exceedsRecordedStock: Value(exceedsRecordedStock),
    );
  }

  factory SaleLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleLine(
      id: serializer.fromJson<int>(json['id']),
      saleClientId: serializer.fromJson<String>(json['saleClientId']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPrice: serializer.fromJson<int>(json['unitPrice']),
      priceVersion: serializer.fromJson<String?>(json['priceVersion']),
      lineTotal: serializer.fromJson<int>(json['lineTotal']),
      exceedsRecordedStock:
          serializer.fromJson<bool>(json['exceedsRecordedStock']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'saleClientId': serializer.toJson<String>(saleClientId),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'quantity': serializer.toJson<int>(quantity),
      'unitPrice': serializer.toJson<int>(unitPrice),
      'priceVersion': serializer.toJson<String?>(priceVersion),
      'lineTotal': serializer.toJson<int>(lineTotal),
      'exceedsRecordedStock': serializer.toJson<bool>(exceedsRecordedStock),
    };
  }

  SaleLine copyWith(
          {int? id,
          String? saleClientId,
          String? productId,
          String? productName,
          int? quantity,
          int? unitPrice,
          Value<String?> priceVersion = const Value.absent(),
          int? lineTotal,
          bool? exceedsRecordedStock}) =>
      SaleLine(
        id: id ?? this.id,
        saleClientId: saleClientId ?? this.saleClientId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        priceVersion:
            priceVersion.present ? priceVersion.value : this.priceVersion,
        lineTotal: lineTotal ?? this.lineTotal,
        exceedsRecordedStock: exceedsRecordedStock ?? this.exceedsRecordedStock,
      );
  SaleLine copyWithCompanion(SaleLinesCompanion data) {
    return SaleLine(
      id: data.id.present ? data.id.value : this.id,
      saleClientId: data.saleClientId.present
          ? data.saleClientId.value
          : this.saleClientId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      priceVersion: data.priceVersion.present
          ? data.priceVersion.value
          : this.priceVersion,
      lineTotal: data.lineTotal.present ? data.lineTotal.value : this.lineTotal,
      exceedsRecordedStock: data.exceedsRecordedStock.present
          ? data.exceedsRecordedStock.value
          : this.exceedsRecordedStock,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleLine(')
          ..write('id: $id, ')
          ..write('saleClientId: $saleClientId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('priceVersion: $priceVersion, ')
          ..write('lineTotal: $lineTotal, ')
          ..write('exceedsRecordedStock: $exceedsRecordedStock')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, saleClientId, productId, productName,
      quantity, unitPrice, priceVersion, lineTotal, exceedsRecordedStock);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleLine &&
          other.id == this.id &&
          other.saleClientId == this.saleClientId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.priceVersion == this.priceVersion &&
          other.lineTotal == this.lineTotal &&
          other.exceedsRecordedStock == this.exceedsRecordedStock);
}

class SaleLinesCompanion extends UpdateCompanion<SaleLine> {
  final Value<int> id;
  final Value<String> saleClientId;
  final Value<String> productId;
  final Value<String> productName;
  final Value<int> quantity;
  final Value<int> unitPrice;
  final Value<String?> priceVersion;
  final Value<int> lineTotal;
  final Value<bool> exceedsRecordedStock;
  const SaleLinesCompanion({
    this.id = const Value.absent(),
    this.saleClientId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.priceVersion = const Value.absent(),
    this.lineTotal = const Value.absent(),
    this.exceedsRecordedStock = const Value.absent(),
  });
  SaleLinesCompanion.insert({
    this.id = const Value.absent(),
    required String saleClientId,
    required String productId,
    required String productName,
    required int quantity,
    required int unitPrice,
    this.priceVersion = const Value.absent(),
    required int lineTotal,
    this.exceedsRecordedStock = const Value.absent(),
  })  : saleClientId = Value(saleClientId),
        productId = Value(productId),
        productName = Value(productName),
        quantity = Value(quantity),
        unitPrice = Value(unitPrice),
        lineTotal = Value(lineTotal);
  static Insertable<SaleLine> custom({
    Expression<int>? id,
    Expression<String>? saleClientId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<int>? quantity,
    Expression<int>? unitPrice,
    Expression<String>? priceVersion,
    Expression<int>? lineTotal,
    Expression<bool>? exceedsRecordedStock,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleClientId != null) 'sale_client_id': saleClientId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (priceVersion != null) 'price_version': priceVersion,
      if (lineTotal != null) 'line_total': lineTotal,
      if (exceedsRecordedStock != null)
        'exceeds_recorded_stock': exceedsRecordedStock,
    });
  }

  SaleLinesCompanion copyWith(
      {Value<int>? id,
      Value<String>? saleClientId,
      Value<String>? productId,
      Value<String>? productName,
      Value<int>? quantity,
      Value<int>? unitPrice,
      Value<String?>? priceVersion,
      Value<int>? lineTotal,
      Value<bool>? exceedsRecordedStock}) {
    return SaleLinesCompanion(
      id: id ?? this.id,
      saleClientId: saleClientId ?? this.saleClientId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      priceVersion: priceVersion ?? this.priceVersion,
      lineTotal: lineTotal ?? this.lineTotal,
      exceedsRecordedStock: exceedsRecordedStock ?? this.exceedsRecordedStock,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (saleClientId.present) {
      map['sale_client_id'] = Variable<String>(saleClientId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<int>(unitPrice.value);
    }
    if (priceVersion.present) {
      map['price_version'] = Variable<String>(priceVersion.value);
    }
    if (lineTotal.present) {
      map['line_total'] = Variable<int>(lineTotal.value);
    }
    if (exceedsRecordedStock.present) {
      map['exceeds_recorded_stock'] =
          Variable<bool>(exceedsRecordedStock.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleLinesCompanion(')
          ..write('id: $id, ')
          ..write('saleClientId: $saleClientId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('priceVersion: $priceVersion, ')
          ..write('lineTotal: $lineTotal, ')
          ..write('exceedsRecordedStock: $exceedsRecordedStock')
          ..write(')'))
        .toString();
  }
}

class $SaleVoidsTable extends SaleVoids
    with TableInfo<$SaleVoidsTable, SaleVoid> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleVoidsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _voidIdMeta = const VerificationMeta('voidId');
  @override
  late final GeneratedColumn<String> voidId = GeneratedColumn<String>(
      'void_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _saleClientIdMeta =
      const VerificationMeta('saleClientId');
  @override
  late final GeneratedColumn<String> saleClientId = GeneratedColumn<String>(
      'sale_client_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'UNIQUE REFERENCES sales (client_id)'));
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorIdMeta =
      const VerificationMeta('actorId');
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
      'actor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _requestedAtMeta =
      const VerificationMeta('requestedAt');
  @override
  late final GeneratedColumn<DateTime> requestedAt = GeneratedColumn<DateTime>(
      'requested_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('saved'));
  static const VerificationMeta _rejectionReasonMeta =
      const VerificationMeta('rejectionReason');
  @override
  late final GeneratedColumn<String> rejectionReason = GeneratedColumn<String>(
      'rejection_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        note,
        voidId,
        saleClientId,
        reason,
        actorId,
        requestedAt,
        syncStatus,
        rejectionReason
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_voids';
  @override
  VerificationContext validateIntegrity(Insertable<SaleVoid> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('void_id')) {
      context.handle(_voidIdMeta,
          voidId.isAcceptableOrUnknown(data['void_id']!, _voidIdMeta));
    } else if (isInserting) {
      context.missing(_voidIdMeta);
    }
    if (data.containsKey('sale_client_id')) {
      context.handle(
          _saleClientIdMeta,
          saleClientId.isAcceptableOrUnknown(
              data['sale_client_id']!, _saleClientIdMeta));
    } else if (isInserting) {
      context.missing(_saleClientIdMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(_actorIdMeta,
          actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta));
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('requested_at')) {
      context.handle(
          _requestedAtMeta,
          requestedAt.isAcceptableOrUnknown(
              data['requested_at']!, _requestedAtMeta));
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('rejection_reason')) {
      context.handle(
          _rejectionReasonMeta,
          rejectionReason.isAcceptableOrUnknown(
              data['rejection_reason']!, _rejectionReasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {voidId};
  @override
  SaleVoid map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleVoid(
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      voidId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}void_id'])!,
      saleClientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sale_client_id'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      actorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_id'])!,
      requestedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}requested_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      rejectionReason: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}rejection_reason']),
    );
  }

  @override
  $SaleVoidsTable createAlias(String alias) {
    return $SaleVoidsTable(attachedDatabase, alias);
  }
}

class SaleVoid extends DataClass implements Insertable<SaleVoid> {
  final String? note;

  /// UUID made on the phone; the server accepts each one once.
  final String voidId;
  final String saleClientId;

  /// `wrong_quantity`, `wrong_product`, `customer_cancelled`, `duplicate`
  /// or `other` (the server contract's reasons).
  final String reason;

  /// The vendor who asked, from the signed-in session.
  final String actorId;
  final DateTime requestedAt;

  /// `saved` (waiting to be sent), `accepted` or `rejected` by the server.
  final String syncStatus;

  /// Why the server refused, e.g. `already_verified`.
  final String? rejectionReason;
  const SaleVoid(
      {this.note,
      required this.voidId,
      required this.saleClientId,
      required this.reason,
      required this.actorId,
      required this.requestedAt,
      required this.syncStatus,
      this.rejectionReason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['void_id'] = Variable<String>(voidId);
    map['sale_client_id'] = Variable<String>(saleClientId);
    map['reason'] = Variable<String>(reason);
    map['actor_id'] = Variable<String>(actorId);
    map['requested_at'] = Variable<DateTime>(requestedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || rejectionReason != null) {
      map['rejection_reason'] = Variable<String>(rejectionReason);
    }
    return map;
  }

  SaleVoidsCompanion toCompanion(bool nullToAbsent) {
    return SaleVoidsCompanion(
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      voidId: Value(voidId),
      saleClientId: Value(saleClientId),
      reason: Value(reason),
      actorId: Value(actorId),
      requestedAt: Value(requestedAt),
      syncStatus: Value(syncStatus),
      rejectionReason: rejectionReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectionReason),
    );
  }

  factory SaleVoid.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleVoid(
      note: serializer.fromJson<String?>(json['note']),
      voidId: serializer.fromJson<String>(json['voidId']),
      saleClientId: serializer.fromJson<String>(json['saleClientId']),
      reason: serializer.fromJson<String>(json['reason']),
      actorId: serializer.fromJson<String>(json['actorId']),
      requestedAt: serializer.fromJson<DateTime>(json['requestedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      rejectionReason: serializer.fromJson<String?>(json['rejectionReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'note': serializer.toJson<String?>(note),
      'voidId': serializer.toJson<String>(voidId),
      'saleClientId': serializer.toJson<String>(saleClientId),
      'reason': serializer.toJson<String>(reason),
      'actorId': serializer.toJson<String>(actorId),
      'requestedAt': serializer.toJson<DateTime>(requestedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'rejectionReason': serializer.toJson<String?>(rejectionReason),
    };
  }

  SaleVoid copyWith(
          {Value<String?> note = const Value.absent(),
          String? voidId,
          String? saleClientId,
          String? reason,
          String? actorId,
          DateTime? requestedAt,
          String? syncStatus,
          Value<String?> rejectionReason = const Value.absent()}) =>
      SaleVoid(
        note: note.present ? note.value : this.note,
        voidId: voidId ?? this.voidId,
        saleClientId: saleClientId ?? this.saleClientId,
        reason: reason ?? this.reason,
        actorId: actorId ?? this.actorId,
        requestedAt: requestedAt ?? this.requestedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        rejectionReason: rejectionReason.present
            ? rejectionReason.value
            : this.rejectionReason,
      );
  SaleVoid copyWithCompanion(SaleVoidsCompanion data) {
    return SaleVoid(
      note: data.note.present ? data.note.value : this.note,
      voidId: data.voidId.present ? data.voidId.value : this.voidId,
      saleClientId: data.saleClientId.present
          ? data.saleClientId.value
          : this.saleClientId,
      reason: data.reason.present ? data.reason.value : this.reason,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      requestedAt:
          data.requestedAt.present ? data.requestedAt.value : this.requestedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      rejectionReason: data.rejectionReason.present
          ? data.rejectionReason.value
          : this.rejectionReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleVoid(')
          ..write('note: $note, ')
          ..write('voidId: $voidId, ')
          ..write('saleClientId: $saleClientId, ')
          ..write('reason: $reason, ')
          ..write('actorId: $actorId, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rejectionReason: $rejectionReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(note, voidId, saleClientId, reason, actorId,
      requestedAt, syncStatus, rejectionReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleVoid &&
          other.note == this.note &&
          other.voidId == this.voidId &&
          other.saleClientId == this.saleClientId &&
          other.reason == this.reason &&
          other.actorId == this.actorId &&
          other.requestedAt == this.requestedAt &&
          other.syncStatus == this.syncStatus &&
          other.rejectionReason == this.rejectionReason);
}

class SaleVoidsCompanion extends UpdateCompanion<SaleVoid> {
  final Value<String?> note;
  final Value<String> voidId;
  final Value<String> saleClientId;
  final Value<String> reason;
  final Value<String> actorId;
  final Value<DateTime> requestedAt;
  final Value<String> syncStatus;
  final Value<String?> rejectionReason;
  final Value<int> rowid;
  const SaleVoidsCompanion({
    this.note = const Value.absent(),
    this.voidId = const Value.absent(),
    this.saleClientId = const Value.absent(),
    this.reason = const Value.absent(),
    this.actorId = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SaleVoidsCompanion.insert({
    this.note = const Value.absent(),
    required String voidId,
    required String saleClientId,
    required String reason,
    required String actorId,
    required DateTime requestedAt,
    this.syncStatus = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : voidId = Value(voidId),
        saleClientId = Value(saleClientId),
        reason = Value(reason),
        actorId = Value(actorId),
        requestedAt = Value(requestedAt);
  static Insertable<SaleVoid> custom({
    Expression<String>? note,
    Expression<String>? voidId,
    Expression<String>? saleClientId,
    Expression<String>? reason,
    Expression<String>? actorId,
    Expression<DateTime>? requestedAt,
    Expression<String>? syncStatus,
    Expression<String>? rejectionReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (note != null) 'note': note,
      if (voidId != null) 'void_id': voidId,
      if (saleClientId != null) 'sale_client_id': saleClientId,
      if (reason != null) 'reason': reason,
      if (actorId != null) 'actor_id': actorId,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SaleVoidsCompanion copyWith(
      {Value<String?>? note,
      Value<String>? voidId,
      Value<String>? saleClientId,
      Value<String>? reason,
      Value<String>? actorId,
      Value<DateTime>? requestedAt,
      Value<String>? syncStatus,
      Value<String?>? rejectionReason,
      Value<int>? rowid}) {
    return SaleVoidsCompanion(
      note: note ?? this.note,
      voidId: voidId ?? this.voidId,
      saleClientId: saleClientId ?? this.saleClientId,
      reason: reason ?? this.reason,
      actorId: actorId ?? this.actorId,
      requestedAt: requestedAt ?? this.requestedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (voidId.present) {
      map['void_id'] = Variable<String>(voidId.value);
    }
    if (saleClientId.present) {
      map['sale_client_id'] = Variable<String>(saleClientId.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<DateTime>(requestedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rejectionReason.present) {
      map['rejection_reason'] = Variable<String>(rejectionReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleVoidsCompanion(')
          ..write('note: $note, ')
          ..write('voidId: $voidId, ')
          ..write('saleClientId: $saleClientId, ')
          ..write('reason: $reason, ')
          ..write('actorId: $actorId, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeliveriesTable extends Deliveries
    with TableInfo<$DeliveriesTable, Delivery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _consignmentIdMeta =
      const VerificationMeta('consignmentId');
  @override
  late final GeneratedColumn<String> consignmentId = GeneratedColumn<String>(
      'consignment_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _referenceMeta =
      const VerificationMeta('reference');
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
      'reference', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
      'sender', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stationKeyMeta =
      const VerificationMeta('stationKey');
  @override
  late final GeneratedColumn<String> stationKey = GeneratedColumn<String>(
      'station_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stationNameMeta =
      const VerificationMeta('stationName');
  @override
  late final GeneratedColumn<String> stationName = GeneratedColumn<String>(
      'station_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dispatchedAtMeta =
      const VerificationMeta('dispatchedAt');
  @override
  late final GeneratedColumn<DateTime> dispatchedAt = GeneratedColumn<DateTime>(
      'dispatched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        consignmentId,
        version,
        reference,
        sender,
        stationKey,
        stationName,
        dispatchedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deliveries';
  @override
  VerificationContext validateIntegrity(Insertable<Delivery> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('consignment_id')) {
      context.handle(
          _consignmentIdMeta,
          consignmentId.isAcceptableOrUnknown(
              data['consignment_id']!, _consignmentIdMeta));
    } else if (isInserting) {
      context.missing(_consignmentIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(_referenceMeta,
          reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta));
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(_senderMeta,
          sender.isAcceptableOrUnknown(data['sender']!, _senderMeta));
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('station_key')) {
      context.handle(
          _stationKeyMeta,
          stationKey.isAcceptableOrUnknown(
              data['station_key']!, _stationKeyMeta));
    } else if (isInserting) {
      context.missing(_stationKeyMeta);
    }
    if (data.containsKey('station_name')) {
      context.handle(
          _stationNameMeta,
          stationName.isAcceptableOrUnknown(
              data['station_name']!, _stationNameMeta));
    } else if (isInserting) {
      context.missing(_stationNameMeta);
    }
    if (data.containsKey('dispatched_at')) {
      context.handle(
          _dispatchedAtMeta,
          dispatchedAt.isAcceptableOrUnknown(
              data['dispatched_at']!, _dispatchedAtMeta));
    } else if (isInserting) {
      context.missing(_dispatchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {consignmentId};
  @override
  Delivery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Delivery(
      consignmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}consignment_id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference'])!,
      sender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender'])!,
      stationKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_key'])!,
      stationName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_name'])!,
      dispatchedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}dispatched_at'])!,
    );
  }

  @override
  $DeliveriesTable createAlias(String alias) {
    return $DeliveriesTable(attachedDatabase, alias);
  }
}

class Delivery extends DataClass implements Insertable<Delivery> {
  final String consignmentId;
  final int version;
  final String reference;
  final String sender;
  final String stationKey;
  final String stationName;
  final DateTime dispatchedAt;
  const Delivery(
      {required this.consignmentId,
      required this.version,
      required this.reference,
      required this.sender,
      required this.stationKey,
      required this.stationName,
      required this.dispatchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['consignment_id'] = Variable<String>(consignmentId);
    map['version'] = Variable<int>(version);
    map['reference'] = Variable<String>(reference);
    map['sender'] = Variable<String>(sender);
    map['station_key'] = Variable<String>(stationKey);
    map['station_name'] = Variable<String>(stationName);
    map['dispatched_at'] = Variable<DateTime>(dispatchedAt);
    return map;
  }

  DeliveriesCompanion toCompanion(bool nullToAbsent) {
    return DeliveriesCompanion(
      consignmentId: Value(consignmentId),
      version: Value(version),
      reference: Value(reference),
      sender: Value(sender),
      stationKey: Value(stationKey),
      stationName: Value(stationName),
      dispatchedAt: Value(dispatchedAt),
    );
  }

  factory Delivery.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Delivery(
      consignmentId: serializer.fromJson<String>(json['consignmentId']),
      version: serializer.fromJson<int>(json['version']),
      reference: serializer.fromJson<String>(json['reference']),
      sender: serializer.fromJson<String>(json['sender']),
      stationKey: serializer.fromJson<String>(json['stationKey']),
      stationName: serializer.fromJson<String>(json['stationName']),
      dispatchedAt: serializer.fromJson<DateTime>(json['dispatchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'consignmentId': serializer.toJson<String>(consignmentId),
      'version': serializer.toJson<int>(version),
      'reference': serializer.toJson<String>(reference),
      'sender': serializer.toJson<String>(sender),
      'stationKey': serializer.toJson<String>(stationKey),
      'stationName': serializer.toJson<String>(stationName),
      'dispatchedAt': serializer.toJson<DateTime>(dispatchedAt),
    };
  }

  Delivery copyWith(
          {String? consignmentId,
          int? version,
          String? reference,
          String? sender,
          String? stationKey,
          String? stationName,
          DateTime? dispatchedAt}) =>
      Delivery(
        consignmentId: consignmentId ?? this.consignmentId,
        version: version ?? this.version,
        reference: reference ?? this.reference,
        sender: sender ?? this.sender,
        stationKey: stationKey ?? this.stationKey,
        stationName: stationName ?? this.stationName,
        dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      );
  Delivery copyWithCompanion(DeliveriesCompanion data) {
    return Delivery(
      consignmentId: data.consignmentId.present
          ? data.consignmentId.value
          : this.consignmentId,
      version: data.version.present ? data.version.value : this.version,
      reference: data.reference.present ? data.reference.value : this.reference,
      sender: data.sender.present ? data.sender.value : this.sender,
      stationKey:
          data.stationKey.present ? data.stationKey.value : this.stationKey,
      stationName:
          data.stationName.present ? data.stationName.value : this.stationName,
      dispatchedAt: data.dispatchedAt.present
          ? data.dispatchedAt.value
          : this.dispatchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Delivery(')
          ..write('consignmentId: $consignmentId, ')
          ..write('version: $version, ')
          ..write('reference: $reference, ')
          ..write('sender: $sender, ')
          ..write('stationKey: $stationKey, ')
          ..write('stationName: $stationName, ')
          ..write('dispatchedAt: $dispatchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(consignmentId, version, reference, sender,
      stationKey, stationName, dispatchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Delivery &&
          other.consignmentId == this.consignmentId &&
          other.version == this.version &&
          other.reference == this.reference &&
          other.sender == this.sender &&
          other.stationKey == this.stationKey &&
          other.stationName == this.stationName &&
          other.dispatchedAt == this.dispatchedAt);
}

class DeliveriesCompanion extends UpdateCompanion<Delivery> {
  final Value<String> consignmentId;
  final Value<int> version;
  final Value<String> reference;
  final Value<String> sender;
  final Value<String> stationKey;
  final Value<String> stationName;
  final Value<DateTime> dispatchedAt;
  final Value<int> rowid;
  const DeliveriesCompanion({
    this.consignmentId = const Value.absent(),
    this.version = const Value.absent(),
    this.reference = const Value.absent(),
    this.sender = const Value.absent(),
    this.stationKey = const Value.absent(),
    this.stationName = const Value.absent(),
    this.dispatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeliveriesCompanion.insert({
    required String consignmentId,
    required int version,
    required String reference,
    required String sender,
    required String stationKey,
    required String stationName,
    required DateTime dispatchedAt,
    this.rowid = const Value.absent(),
  })  : consignmentId = Value(consignmentId),
        version = Value(version),
        reference = Value(reference),
        sender = Value(sender),
        stationKey = Value(stationKey),
        stationName = Value(stationName),
        dispatchedAt = Value(dispatchedAt);
  static Insertable<Delivery> custom({
    Expression<String>? consignmentId,
    Expression<int>? version,
    Expression<String>? reference,
    Expression<String>? sender,
    Expression<String>? stationKey,
    Expression<String>? stationName,
    Expression<DateTime>? dispatchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (consignmentId != null) 'consignment_id': consignmentId,
      if (version != null) 'version': version,
      if (reference != null) 'reference': reference,
      if (sender != null) 'sender': sender,
      if (stationKey != null) 'station_key': stationKey,
      if (stationName != null) 'station_name': stationName,
      if (dispatchedAt != null) 'dispatched_at': dispatchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeliveriesCompanion copyWith(
      {Value<String>? consignmentId,
      Value<int>? version,
      Value<String>? reference,
      Value<String>? sender,
      Value<String>? stationKey,
      Value<String>? stationName,
      Value<DateTime>? dispatchedAt,
      Value<int>? rowid}) {
    return DeliveriesCompanion(
      consignmentId: consignmentId ?? this.consignmentId,
      version: version ?? this.version,
      reference: reference ?? this.reference,
      sender: sender ?? this.sender,
      stationKey: stationKey ?? this.stationKey,
      stationName: stationName ?? this.stationName,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (consignmentId.present) {
      map['consignment_id'] = Variable<String>(consignmentId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (stationKey.present) {
      map['station_key'] = Variable<String>(stationKey.value);
    }
    if (stationName.present) {
      map['station_name'] = Variable<String>(stationName.value);
    }
    if (dispatchedAt.present) {
      map['dispatched_at'] = Variable<DateTime>(dispatchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveriesCompanion(')
          ..write('consignmentId: $consignmentId, ')
          ..write('version: $version, ')
          ..write('reference: $reference, ')
          ..write('sender: $sender, ')
          ..write('stationKey: $stationKey, ')
          ..write('stationName: $stationName, ')
          ..write('dispatchedAt: $dispatchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeliveryLinesTable extends DeliveryLines
    with TableInfo<$DeliveryLinesTable, DeliveryLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveryLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _consignmentIdMeta =
      const VerificationMeta('consignmentId');
  @override
  late final GeneratedColumn<String> consignmentId = GeneratedColumn<String>(
      'consignment_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
      'line_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _imageKeyMeta =
      const VerificationMeta('imageKey');
  @override
  late final GeneratedColumn<String> imageKey = GeneratedColumn<String>(
      'image_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [consignmentId, lineId, productId, productName, quantity, imageKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delivery_lines';
  @override
  VerificationContext validateIntegrity(Insertable<DeliveryLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('consignment_id')) {
      context.handle(
          _consignmentIdMeta,
          consignmentId.isAcceptableOrUnknown(
              data['consignment_id']!, _consignmentIdMeta));
    } else if (isInserting) {
      context.missing(_consignmentIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(_lineIdMeta,
          lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta));
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('image_key')) {
      context.handle(_imageKeyMeta,
          imageKey.isAcceptableOrUnknown(data['image_key']!, _imageKeyMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {consignmentId, lineId};
  @override
  DeliveryLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeliveryLine(
      consignmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}consignment_id'])!,
      lineId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}line_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      imageKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_key']),
    );
  }

  @override
  $DeliveryLinesTable createAlias(String alias) {
    return $DeliveryLinesTable(attachedDatabase, alias);
  }
}

class DeliveryLine extends DataClass implements Insertable<DeliveryLine> {
  final String consignmentId;
  final String lineId;
  final String productId;
  final String productName;
  final int quantity;
  final String? imageKey;
  const DeliveryLine(
      {required this.consignmentId,
      required this.lineId,
      required this.productId,
      required this.productName,
      required this.quantity,
      this.imageKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['consignment_id'] = Variable<String>(consignmentId);
    map['line_id'] = Variable<String>(lineId);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || imageKey != null) {
      map['image_key'] = Variable<String>(imageKey);
    }
    return map;
  }

  DeliveryLinesCompanion toCompanion(bool nullToAbsent) {
    return DeliveryLinesCompanion(
      consignmentId: Value(consignmentId),
      lineId: Value(lineId),
      productId: Value(productId),
      productName: Value(productName),
      quantity: Value(quantity),
      imageKey: imageKey == null && nullToAbsent
          ? const Value.absent()
          : Value(imageKey),
    );
  }

  factory DeliveryLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeliveryLine(
      consignmentId: serializer.fromJson<String>(json['consignmentId']),
      lineId: serializer.fromJson<String>(json['lineId']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      quantity: serializer.fromJson<int>(json['quantity']),
      imageKey: serializer.fromJson<String?>(json['imageKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'consignmentId': serializer.toJson<String>(consignmentId),
      'lineId': serializer.toJson<String>(lineId),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'quantity': serializer.toJson<int>(quantity),
      'imageKey': serializer.toJson<String?>(imageKey),
    };
  }

  DeliveryLine copyWith(
          {String? consignmentId,
          String? lineId,
          String? productId,
          String? productName,
          int? quantity,
          Value<String?> imageKey = const Value.absent()}) =>
      DeliveryLine(
        consignmentId: consignmentId ?? this.consignmentId,
        lineId: lineId ?? this.lineId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        imageKey: imageKey.present ? imageKey.value : this.imageKey,
      );
  DeliveryLine copyWithCompanion(DeliveryLinesCompanion data) {
    return DeliveryLine(
      consignmentId: data.consignmentId.present
          ? data.consignmentId.value
          : this.consignmentId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      imageKey: data.imageKey.present ? data.imageKey.value : this.imageKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryLine(')
          ..write('consignmentId: $consignmentId, ')
          ..write('lineId: $lineId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('imageKey: $imageKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      consignmentId, lineId, productId, productName, quantity, imageKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeliveryLine &&
          other.consignmentId == this.consignmentId &&
          other.lineId == this.lineId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.imageKey == this.imageKey);
}

class DeliveryLinesCompanion extends UpdateCompanion<DeliveryLine> {
  final Value<String> consignmentId;
  final Value<String> lineId;
  final Value<String> productId;
  final Value<String> productName;
  final Value<int> quantity;
  final Value<String?> imageKey;
  final Value<int> rowid;
  const DeliveryLinesCompanion({
    this.consignmentId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.imageKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeliveryLinesCompanion.insert({
    required String consignmentId,
    required String lineId,
    required String productId,
    required String productName,
    required int quantity,
    this.imageKey = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : consignmentId = Value(consignmentId),
        lineId = Value(lineId),
        productId = Value(productId),
        productName = Value(productName),
        quantity = Value(quantity);
  static Insertable<DeliveryLine> custom({
    Expression<String>? consignmentId,
    Expression<String>? lineId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<int>? quantity,
    Expression<String>? imageKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (consignmentId != null) 'consignment_id': consignmentId,
      if (lineId != null) 'line_id': lineId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (imageKey != null) 'image_key': imageKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeliveryLinesCompanion copyWith(
      {Value<String>? consignmentId,
      Value<String>? lineId,
      Value<String>? productId,
      Value<String>? productName,
      Value<int>? quantity,
      Value<String?>? imageKey,
      Value<int>? rowid}) {
    return DeliveryLinesCompanion(
      consignmentId: consignmentId ?? this.consignmentId,
      lineId: lineId ?? this.lineId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      imageKey: imageKey ?? this.imageKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (consignmentId.present) {
      map['consignment_id'] = Variable<String>(consignmentId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (imageKey.present) {
      map['image_key'] = Variable<String>(imageKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryLinesCompanion(')
          ..write('consignmentId: $consignmentId, ')
          ..write('lineId: $lineId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('imageKey: $imageKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptsTable extends Receipts with TableInfo<$ReceiptsTable, Receipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _receiptIdMeta =
      const VerificationMeta('receiptId');
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
      'receipt_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _consignmentIdMeta =
      const VerificationMeta('consignmentId');
  @override
  late final GeneratedColumn<String> consignmentId = GeneratedColumn<String>(
      'consignment_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _consignmentVersionMeta =
      const VerificationMeta('consignmentVersion');
  @override
  late final GeneratedColumn<int> consignmentVersion = GeneratedColumn<int>(
      'consignment_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stationKeyMeta =
      const VerificationMeta('stationKey');
  @override
  late final GeneratedColumn<String> stationKey = GeneratedColumn<String>(
      'station_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorIdMeta =
      const VerificationMeta('actorId');
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
      'actor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('saved'));
  static const VerificationMeta _conflictReasonMeta =
      const VerificationMeta('conflictReason');
  @override
  late final GeneratedColumn<String> conflictReason = GeneratedColumn<String>(
      'conflict_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        receiptId,
        eventId,
        consignmentId,
        consignmentVersion,
        stationKey,
        actorId,
        receivedAt,
        syncStatus,
        conflictReason
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(Insertable<Receipt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('receipt_id')) {
      context.handle(_receiptIdMeta,
          receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta));
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('consignment_id')) {
      context.handle(
          _consignmentIdMeta,
          consignmentId.isAcceptableOrUnknown(
              data['consignment_id']!, _consignmentIdMeta));
    } else if (isInserting) {
      context.missing(_consignmentIdMeta);
    }
    if (data.containsKey('consignment_version')) {
      context.handle(
          _consignmentVersionMeta,
          consignmentVersion.isAcceptableOrUnknown(
              data['consignment_version']!, _consignmentVersionMeta));
    } else if (isInserting) {
      context.missing(_consignmentVersionMeta);
    }
    if (data.containsKey('station_key')) {
      context.handle(
          _stationKeyMeta,
          stationKey.isAcceptableOrUnknown(
              data['station_key']!, _stationKeyMeta));
    } else if (isInserting) {
      context.missing(_stationKeyMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(_actorIdMeta,
          actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta));
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('conflict_reason')) {
      context.handle(
          _conflictReasonMeta,
          conflictReason.isAcceptableOrUnknown(
              data['conflict_reason']!, _conflictReasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {receiptId};
  @override
  Receipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Receipt(
      receiptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}receipt_id'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id'])!,
      consignmentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}consignment_id'])!,
      consignmentVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}consignment_version'])!,
      stationKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_key'])!,
      actorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_id'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      conflictReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}conflict_reason']),
    );
  }

  @override
  $ReceiptsTable createAlias(String alias) {
    return $ReceiptsTable(attachedDatabase, alias);
  }
}

class Receipt extends DataClass implements Insertable<Receipt> {
  final String receiptId;

  /// Idempotency key: the server records each event once.
  final String eventId;
  final String consignmentId;

  /// The manifest version the vendor counted against.
  final int consignmentVersion;
  final String stationKey;
  final String actorId;
  final DateTime receivedAt;

  /// `saved` (only on the phone), `accepted` by the server, `conflict`
  /// (needs staff review, e.g. the manifest changed) or `rejected`.
  final String syncStatus;
  final String? conflictReason;
  const Receipt(
      {required this.receiptId,
      required this.eventId,
      required this.consignmentId,
      required this.consignmentVersion,
      required this.stationKey,
      required this.actorId,
      required this.receivedAt,
      required this.syncStatus,
      this.conflictReason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['receipt_id'] = Variable<String>(receiptId);
    map['event_id'] = Variable<String>(eventId);
    map['consignment_id'] = Variable<String>(consignmentId);
    map['consignment_version'] = Variable<int>(consignmentVersion);
    map['station_key'] = Variable<String>(stationKey);
    map['actor_id'] = Variable<String>(actorId);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || conflictReason != null) {
      map['conflict_reason'] = Variable<String>(conflictReason);
    }
    return map;
  }

  ReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptsCompanion(
      receiptId: Value(receiptId),
      eventId: Value(eventId),
      consignmentId: Value(consignmentId),
      consignmentVersion: Value(consignmentVersion),
      stationKey: Value(stationKey),
      actorId: Value(actorId),
      receivedAt: Value(receivedAt),
      syncStatus: Value(syncStatus),
      conflictReason: conflictReason == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictReason),
    );
  }

  factory Receipt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Receipt(
      receiptId: serializer.fromJson<String>(json['receiptId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      consignmentId: serializer.fromJson<String>(json['consignmentId']),
      consignmentVersion: serializer.fromJson<int>(json['consignmentVersion']),
      stationKey: serializer.fromJson<String>(json['stationKey']),
      actorId: serializer.fromJson<String>(json['actorId']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      conflictReason: serializer.fromJson<String?>(json['conflictReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'receiptId': serializer.toJson<String>(receiptId),
      'eventId': serializer.toJson<String>(eventId),
      'consignmentId': serializer.toJson<String>(consignmentId),
      'consignmentVersion': serializer.toJson<int>(consignmentVersion),
      'stationKey': serializer.toJson<String>(stationKey),
      'actorId': serializer.toJson<String>(actorId),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'conflictReason': serializer.toJson<String?>(conflictReason),
    };
  }

  Receipt copyWith(
          {String? receiptId,
          String? eventId,
          String? consignmentId,
          int? consignmentVersion,
          String? stationKey,
          String? actorId,
          DateTime? receivedAt,
          String? syncStatus,
          Value<String?> conflictReason = const Value.absent()}) =>
      Receipt(
        receiptId: receiptId ?? this.receiptId,
        eventId: eventId ?? this.eventId,
        consignmentId: consignmentId ?? this.consignmentId,
        consignmentVersion: consignmentVersion ?? this.consignmentVersion,
        stationKey: stationKey ?? this.stationKey,
        actorId: actorId ?? this.actorId,
        receivedAt: receivedAt ?? this.receivedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        conflictReason:
            conflictReason.present ? conflictReason.value : this.conflictReason,
      );
  Receipt copyWithCompanion(ReceiptsCompanion data) {
    return Receipt(
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      consignmentId: data.consignmentId.present
          ? data.consignmentId.value
          : this.consignmentId,
      consignmentVersion: data.consignmentVersion.present
          ? data.consignmentVersion.value
          : this.consignmentVersion,
      stationKey:
          data.stationKey.present ? data.stationKey.value : this.stationKey,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      conflictReason: data.conflictReason.present
          ? data.conflictReason.value
          : this.conflictReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Receipt(')
          ..write('receiptId: $receiptId, ')
          ..write('eventId: $eventId, ')
          ..write('consignmentId: $consignmentId, ')
          ..write('consignmentVersion: $consignmentVersion, ')
          ..write('stationKey: $stationKey, ')
          ..write('actorId: $actorId, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('conflictReason: $conflictReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      receiptId,
      eventId,
      consignmentId,
      consignmentVersion,
      stationKey,
      actorId,
      receivedAt,
      syncStatus,
      conflictReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Receipt &&
          other.receiptId == this.receiptId &&
          other.eventId == this.eventId &&
          other.consignmentId == this.consignmentId &&
          other.consignmentVersion == this.consignmentVersion &&
          other.stationKey == this.stationKey &&
          other.actorId == this.actorId &&
          other.receivedAt == this.receivedAt &&
          other.syncStatus == this.syncStatus &&
          other.conflictReason == this.conflictReason);
}

class ReceiptsCompanion extends UpdateCompanion<Receipt> {
  final Value<String> receiptId;
  final Value<String> eventId;
  final Value<String> consignmentId;
  final Value<int> consignmentVersion;
  final Value<String> stationKey;
  final Value<String> actorId;
  final Value<DateTime> receivedAt;
  final Value<String> syncStatus;
  final Value<String?> conflictReason;
  final Value<int> rowid;
  const ReceiptsCompanion({
    this.receiptId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.consignmentId = const Value.absent(),
    this.consignmentVersion = const Value.absent(),
    this.stationKey = const Value.absent(),
    this.actorId = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.conflictReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptsCompanion.insert({
    required String receiptId,
    required String eventId,
    required String consignmentId,
    required int consignmentVersion,
    required String stationKey,
    required String actorId,
    required DateTime receivedAt,
    this.syncStatus = const Value.absent(),
    this.conflictReason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : receiptId = Value(receiptId),
        eventId = Value(eventId),
        consignmentId = Value(consignmentId),
        consignmentVersion = Value(consignmentVersion),
        stationKey = Value(stationKey),
        actorId = Value(actorId),
        receivedAt = Value(receivedAt);
  static Insertable<Receipt> custom({
    Expression<String>? receiptId,
    Expression<String>? eventId,
    Expression<String>? consignmentId,
    Expression<int>? consignmentVersion,
    Expression<String>? stationKey,
    Expression<String>? actorId,
    Expression<DateTime>? receivedAt,
    Expression<String>? syncStatus,
    Expression<String>? conflictReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (receiptId != null) 'receipt_id': receiptId,
      if (eventId != null) 'event_id': eventId,
      if (consignmentId != null) 'consignment_id': consignmentId,
      if (consignmentVersion != null) 'consignment_version': consignmentVersion,
      if (stationKey != null) 'station_key': stationKey,
      if (actorId != null) 'actor_id': actorId,
      if (receivedAt != null) 'received_at': receivedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (conflictReason != null) 'conflict_reason': conflictReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptsCompanion copyWith(
      {Value<String>? receiptId,
      Value<String>? eventId,
      Value<String>? consignmentId,
      Value<int>? consignmentVersion,
      Value<String>? stationKey,
      Value<String>? actorId,
      Value<DateTime>? receivedAt,
      Value<String>? syncStatus,
      Value<String?>? conflictReason,
      Value<int>? rowid}) {
    return ReceiptsCompanion(
      receiptId: receiptId ?? this.receiptId,
      eventId: eventId ?? this.eventId,
      consignmentId: consignmentId ?? this.consignmentId,
      consignmentVersion: consignmentVersion ?? this.consignmentVersion,
      stationKey: stationKey ?? this.stationKey,
      actorId: actorId ?? this.actorId,
      receivedAt: receivedAt ?? this.receivedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      conflictReason: conflictReason ?? this.conflictReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (consignmentId.present) {
      map['consignment_id'] = Variable<String>(consignmentId.value);
    }
    if (consignmentVersion.present) {
      map['consignment_version'] = Variable<int>(consignmentVersion.value);
    }
    if (stationKey.present) {
      map['station_key'] = Variable<String>(stationKey.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (conflictReason.present) {
      map['conflict_reason'] = Variable<String>(conflictReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptsCompanion(')
          ..write('receiptId: $receiptId, ')
          ..write('eventId: $eventId, ')
          ..write('consignmentId: $consignmentId, ')
          ..write('consignmentVersion: $consignmentVersion, ')
          ..write('stationKey: $stationKey, ')
          ..write('actorId: $actorId, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('conflictReason: $conflictReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptLinesTable extends ReceiptLines
    with TableInfo<$ReceiptLinesTable, ReceiptLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _receiptIdMeta =
      const VerificationMeta('receiptId');
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
      'receipt_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES receipts (receipt_id)'));
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
      'line_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _acceptedMeta =
      const VerificationMeta('accepted');
  @override
  late final GeneratedColumn<int> accepted = GeneratedColumn<int>(
      'accepted', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rejectedMeta =
      const VerificationMeta('rejected');
  @override
  late final GeneratedColumn<int> rejected = GeneratedColumn<int>(
      'rejected', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [note, receiptId, lineId, accepted, rejected, reason];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_lines';
  @override
  VerificationContext validateIntegrity(Insertable<ReceiptLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('receipt_id')) {
      context.handle(_receiptIdMeta,
          receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta));
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(_lineIdMeta,
          lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta));
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('accepted')) {
      context.handle(_acceptedMeta,
          accepted.isAcceptableOrUnknown(data['accepted']!, _acceptedMeta));
    } else if (isInserting) {
      context.missing(_acceptedMeta);
    }
    if (data.containsKey('rejected')) {
      context.handle(_rejectedMeta,
          rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta));
    } else if (isInserting) {
      context.missing(_rejectedMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {receiptId, lineId};
  @override
  ReceiptLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptLine(
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      receiptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}receipt_id'])!,
      lineId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}line_id'])!,
      accepted: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}accepted'])!,
      rejected: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rejected'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
    );
  }

  @override
  $ReceiptLinesTable createAlias(String alias) {
    return $ReceiptLinesTable(attachedDatabase, alias);
  }
}

class ReceiptLine extends DataClass implements Insertable<ReceiptLine> {
  final String? note;
  final String receiptId;
  final String lineId;

  /// Units taken into stock, and units that arrived but were refused.
  final int accepted;
  final int rejected;

  /// `short`, `damaged`, `wrong_product` or `other` when the count differs
  /// from what was dispatched; never assumed.
  final String? reason;
  const ReceiptLine(
      {this.note,
      required this.receiptId,
      required this.lineId,
      required this.accepted,
      required this.rejected,
      this.reason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['receipt_id'] = Variable<String>(receiptId);
    map['line_id'] = Variable<String>(lineId);
    map['accepted'] = Variable<int>(accepted);
    map['rejected'] = Variable<int>(rejected);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    return map;
  }

  ReceiptLinesCompanion toCompanion(bool nullToAbsent) {
    return ReceiptLinesCompanion(
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      receiptId: Value(receiptId),
      lineId: Value(lineId),
      accepted: Value(accepted),
      rejected: Value(rejected),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
    );
  }

  factory ReceiptLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptLine(
      note: serializer.fromJson<String?>(json['note']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      lineId: serializer.fromJson<String>(json['lineId']),
      accepted: serializer.fromJson<int>(json['accepted']),
      rejected: serializer.fromJson<int>(json['rejected']),
      reason: serializer.fromJson<String?>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'note': serializer.toJson<String?>(note),
      'receiptId': serializer.toJson<String>(receiptId),
      'lineId': serializer.toJson<String>(lineId),
      'accepted': serializer.toJson<int>(accepted),
      'rejected': serializer.toJson<int>(rejected),
      'reason': serializer.toJson<String?>(reason),
    };
  }

  ReceiptLine copyWith(
          {Value<String?> note = const Value.absent(),
          String? receiptId,
          String? lineId,
          int? accepted,
          int? rejected,
          Value<String?> reason = const Value.absent()}) =>
      ReceiptLine(
        note: note.present ? note.value : this.note,
        receiptId: receiptId ?? this.receiptId,
        lineId: lineId ?? this.lineId,
        accepted: accepted ?? this.accepted,
        rejected: rejected ?? this.rejected,
        reason: reason.present ? reason.value : this.reason,
      );
  ReceiptLine copyWithCompanion(ReceiptLinesCompanion data) {
    return ReceiptLine(
      note: data.note.present ? data.note.value : this.note,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      accepted: data.accepted.present ? data.accepted.value : this.accepted,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLine(')
          ..write('note: $note, ')
          ..write('receiptId: $receiptId, ')
          ..write('lineId: $lineId, ')
          ..write('accepted: $accepted, ')
          ..write('rejected: $rejected, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(note, receiptId, lineId, accepted, rejected, reason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptLine &&
          other.note == this.note &&
          other.receiptId == this.receiptId &&
          other.lineId == this.lineId &&
          other.accepted == this.accepted &&
          other.rejected == this.rejected &&
          other.reason == this.reason);
}

class ReceiptLinesCompanion extends UpdateCompanion<ReceiptLine> {
  final Value<String?> note;
  final Value<String> receiptId;
  final Value<String> lineId;
  final Value<int> accepted;
  final Value<int> rejected;
  final Value<String?> reason;
  final Value<int> rowid;
  const ReceiptLinesCompanion({
    this.note = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.accepted = const Value.absent(),
    this.rejected = const Value.absent(),
    this.reason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptLinesCompanion.insert({
    this.note = const Value.absent(),
    required String receiptId,
    required String lineId,
    required int accepted,
    required int rejected,
    this.reason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : receiptId = Value(receiptId),
        lineId = Value(lineId),
        accepted = Value(accepted),
        rejected = Value(rejected);
  static Insertable<ReceiptLine> custom({
    Expression<String>? note,
    Expression<String>? receiptId,
    Expression<String>? lineId,
    Expression<int>? accepted,
    Expression<int>? rejected,
    Expression<String>? reason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (note != null) 'note': note,
      if (receiptId != null) 'receipt_id': receiptId,
      if (lineId != null) 'line_id': lineId,
      if (accepted != null) 'accepted': accepted,
      if (rejected != null) 'rejected': rejected,
      if (reason != null) 'reason': reason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptLinesCompanion copyWith(
      {Value<String?>? note,
      Value<String>? receiptId,
      Value<String>? lineId,
      Value<int>? accepted,
      Value<int>? rejected,
      Value<String?>? reason,
      Value<int>? rowid}) {
    return ReceiptLinesCompanion(
      note: note ?? this.note,
      receiptId: receiptId ?? this.receiptId,
      lineId: lineId ?? this.lineId,
      accepted: accepted ?? this.accepted,
      rejected: rejected ?? this.rejected,
      reason: reason ?? this.reason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (accepted.present) {
      map['accepted'] = Variable<int>(accepted.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<int>(rejected.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLinesCompanion(')
          ..write('note: $note, ')
          ..write('receiptId: $receiptId, ')
          ..write('lineId: $lineId, ')
          ..write('accepted: $accepted, ')
          ..write('rejected: $rejected, ')
          ..write('reason: $reason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DamageReportsTable extends DamageReports
    with TableInfo<$DamageReportsTable, DamageReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DamageReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reportIdMeta =
      const VerificationMeta('reportId');
  @override
  late final GeneratedColumn<String> reportId = GeneratedColumn<String>(
      'report_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stationKeyMeta =
      const VerificationMeta('stationKey');
  @override
  late final GeneratedColumn<String> stationKey = GeneratedColumn<String>(
      'station_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorIdMeta =
      const VerificationMeta('actorId');
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
      'actor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reportedAtMeta =
      const VerificationMeta('reportedAt');
  @override
  late final GeneratedColumn<DateTime> reportedAt = GeneratedColumn<DateTime>(
      'reported_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('saved'));
  static const VerificationMeta _reviewMeta = const VerificationMeta('review');
  @override
  late final GeneratedColumn<String> review = GeneratedColumn<String>(
      'review', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('reported'));
  @override
  List<GeneratedColumn> get $columns => [
        reportId,
        productId,
        productName,
        quantity,
        reason,
        note,
        imagePath,
        stationKey,
        actorId,
        reportedAt,
        syncStatus,
        review
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'damage_reports';
  @override
  VerificationContext validateIntegrity(Insertable<DamageReport> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('report_id')) {
      context.handle(_reportIdMeta,
          reportId.isAcceptableOrUnknown(data['report_id']!, _reportIdMeta));
    } else if (isInserting) {
      context.missing(_reportIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('station_key')) {
      context.handle(
          _stationKeyMeta,
          stationKey.isAcceptableOrUnknown(
              data['station_key']!, _stationKeyMeta));
    } else if (isInserting) {
      context.missing(_stationKeyMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(_actorIdMeta,
          actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta));
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('reported_at')) {
      context.handle(
          _reportedAtMeta,
          reportedAt.isAcceptableOrUnknown(
              data['reported_at']!, _reportedAtMeta));
    } else if (isInserting) {
      context.missing(_reportedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('review')) {
      context.handle(_reviewMeta,
          review.isAcceptableOrUnknown(data['review']!, _reviewMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reportId};
  @override
  DamageReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DamageReport(
      reportId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}report_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      stationKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_key'])!,
      actorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_id'])!,
      reportedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reported_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      review: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}review'])!,
    );
  }

  @override
  $DamageReportsTable createAlias(String alias) {
    return $DamageReportsTable(attachedDatabase, alias);
  }
}

class DamageReport extends DataClass implements Insertable<DamageReport> {
  /// UUID made on the phone; the server records each report once.
  final String reportId;
  final String productId;
  final String productName;
  final int quantity;

  /// `spoiled`, `burnt`, `spilled` or `other`.
  final String reason;
  final String? note;
  final String? imagePath;
  final String stationKey;
  final String actorId;
  final DateTime reportedAt;

  /// `saved` (only on the phone) or `sent`.
  final String syncStatus;

  /// From the server: `reported`, `verified` (a loss) or `rejected`.
  final String review;
  const DamageReport(
      {required this.reportId,
      required this.productId,
      required this.productName,
      required this.quantity,
      required this.reason,
      this.note,
      this.imagePath,
      required this.stationKey,
      required this.actorId,
      required this.reportedAt,
      required this.syncStatus,
      required this.review});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['report_id'] = Variable<String>(reportId);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    map['quantity'] = Variable<int>(quantity);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['station_key'] = Variable<String>(stationKey);
    map['actor_id'] = Variable<String>(actorId);
    map['reported_at'] = Variable<DateTime>(reportedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['review'] = Variable<String>(review);
    return map;
  }

  DamageReportsCompanion toCompanion(bool nullToAbsent) {
    return DamageReportsCompanion(
      reportId: Value(reportId),
      productId: Value(productId),
      productName: Value(productName),
      quantity: Value(quantity),
      reason: Value(reason),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      stationKey: Value(stationKey),
      actorId: Value(actorId),
      reportedAt: Value(reportedAt),
      syncStatus: Value(syncStatus),
      review: Value(review),
    );
  }

  factory DamageReport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DamageReport(
      reportId: serializer.fromJson<String>(json['reportId']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      quantity: serializer.fromJson<int>(json['quantity']),
      reason: serializer.fromJson<String>(json['reason']),
      note: serializer.fromJson<String?>(json['note']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      stationKey: serializer.fromJson<String>(json['stationKey']),
      actorId: serializer.fromJson<String>(json['actorId']),
      reportedAt: serializer.fromJson<DateTime>(json['reportedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      review: serializer.fromJson<String>(json['review']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reportId': serializer.toJson<String>(reportId),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'quantity': serializer.toJson<int>(quantity),
      'reason': serializer.toJson<String>(reason),
      'note': serializer.toJson<String?>(note),
      'imagePath': serializer.toJson<String?>(imagePath),
      'stationKey': serializer.toJson<String>(stationKey),
      'actorId': serializer.toJson<String>(actorId),
      'reportedAt': serializer.toJson<DateTime>(reportedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'review': serializer.toJson<String>(review),
    };
  }

  DamageReport copyWith(
          {String? reportId,
          String? productId,
          String? productName,
          int? quantity,
          String? reason,
          Value<String?> note = const Value.absent(),
          Value<String?> imagePath = const Value.absent(),
          String? stationKey,
          String? actorId,
          DateTime? reportedAt,
          String? syncStatus,
          String? review}) =>
      DamageReport(
        reportId: reportId ?? this.reportId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        reason: reason ?? this.reason,
        note: note.present ? note.value : this.note,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        stationKey: stationKey ?? this.stationKey,
        actorId: actorId ?? this.actorId,
        reportedAt: reportedAt ?? this.reportedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        review: review ?? this.review,
      );
  DamageReport copyWithCompanion(DamageReportsCompanion data) {
    return DamageReport(
      reportId: data.reportId.present ? data.reportId.value : this.reportId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      reason: data.reason.present ? data.reason.value : this.reason,
      note: data.note.present ? data.note.value : this.note,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      stationKey:
          data.stationKey.present ? data.stationKey.value : this.stationKey,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      reportedAt:
          data.reportedAt.present ? data.reportedAt.value : this.reportedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      review: data.review.present ? data.review.value : this.review,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DamageReport(')
          ..write('reportId: $reportId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('imagePath: $imagePath, ')
          ..write('stationKey: $stationKey, ')
          ..write('actorId: $actorId, ')
          ..write('reportedAt: $reportedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('review: $review')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      reportId,
      productId,
      productName,
      quantity,
      reason,
      note,
      imagePath,
      stationKey,
      actorId,
      reportedAt,
      syncStatus,
      review);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DamageReport &&
          other.reportId == this.reportId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.reason == this.reason &&
          other.note == this.note &&
          other.imagePath == this.imagePath &&
          other.stationKey == this.stationKey &&
          other.actorId == this.actorId &&
          other.reportedAt == this.reportedAt &&
          other.syncStatus == this.syncStatus &&
          other.review == this.review);
}

class DamageReportsCompanion extends UpdateCompanion<DamageReport> {
  final Value<String> reportId;
  final Value<String> productId;
  final Value<String> productName;
  final Value<int> quantity;
  final Value<String> reason;
  final Value<String?> note;
  final Value<String?> imagePath;
  final Value<String> stationKey;
  final Value<String> actorId;
  final Value<DateTime> reportedAt;
  final Value<String> syncStatus;
  final Value<String> review;
  final Value<int> rowid;
  const DamageReportsCompanion({
    this.reportId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.stationKey = const Value.absent(),
    this.actorId = const Value.absent(),
    this.reportedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.review = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DamageReportsCompanion.insert({
    required String reportId,
    required String productId,
    required String productName,
    required int quantity,
    required String reason,
    this.note = const Value.absent(),
    this.imagePath = const Value.absent(),
    required String stationKey,
    required String actorId,
    required DateTime reportedAt,
    this.syncStatus = const Value.absent(),
    this.review = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : reportId = Value(reportId),
        productId = Value(productId),
        productName = Value(productName),
        quantity = Value(quantity),
        reason = Value(reason),
        stationKey = Value(stationKey),
        actorId = Value(actorId),
        reportedAt = Value(reportedAt);
  static Insertable<DamageReport> custom({
    Expression<String>? reportId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<int>? quantity,
    Expression<String>? reason,
    Expression<String>? note,
    Expression<String>? imagePath,
    Expression<String>? stationKey,
    Expression<String>? actorId,
    Expression<DateTime>? reportedAt,
    Expression<String>? syncStatus,
    Expression<String>? review,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reportId != null) 'report_id': reportId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (imagePath != null) 'image_path': imagePath,
      if (stationKey != null) 'station_key': stationKey,
      if (actorId != null) 'actor_id': actorId,
      if (reportedAt != null) 'reported_at': reportedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (review != null) 'review': review,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DamageReportsCompanion copyWith(
      {Value<String>? reportId,
      Value<String>? productId,
      Value<String>? productName,
      Value<int>? quantity,
      Value<String>? reason,
      Value<String?>? note,
      Value<String?>? imagePath,
      Value<String>? stationKey,
      Value<String>? actorId,
      Value<DateTime>? reportedAt,
      Value<String>? syncStatus,
      Value<String>? review,
      Value<int>? rowid}) {
    return DamageReportsCompanion(
      reportId: reportId ?? this.reportId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      stationKey: stationKey ?? this.stationKey,
      actorId: actorId ?? this.actorId,
      reportedAt: reportedAt ?? this.reportedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      review: review ?? this.review,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reportId.present) {
      map['report_id'] = Variable<String>(reportId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (stationKey.present) {
      map['station_key'] = Variable<String>(stationKey.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (reportedAt.present) {
      map['reported_at'] = Variable<DateTime>(reportedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (review.present) {
      map['review'] = Variable<String>(review.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DamageReportsCompanion(')
          ..write('reportId: $reportId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('imagePath: $imagePath, ')
          ..write('stationKey: $stationKey, ')
          ..write('actorId: $actorId, ')
          ..write('reportedAt: $reportedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('review: $review, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClosingCountsTable extends ClosingCounts
    with TableInfo<$ClosingCountsTable, ClosingCount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClosingCountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _countIdMeta =
      const VerificationMeta('countId');
  @override
  late final GeneratedColumn<String> countId = GeneratedColumn<String>(
      'count_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _businessDateMeta =
      const VerificationMeta('businessDate');
  @override
  late final GeneratedColumn<String> businessDate = GeneratedColumn<String>(
      'business_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vendorIdMeta =
      const VerificationMeta('vendorId');
  @override
  late final GeneratedColumn<String> vendorId = GeneratedColumn<String>(
      'vendor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stationKeyMeta =
      const VerificationMeta('stationKey');
  @override
  late final GeneratedColumn<String> stationKey = GeneratedColumn<String>(
      'station_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countedAtMeta =
      const VerificationMeta('countedAt');
  @override
  late final GeneratedColumn<DateTime> countedAt = GeneratedColumn<DateTime>(
      'counted_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('saved'));
  static const VerificationMeta _officeStatusMeta =
      const VerificationMeta('officeStatus');
  @override
  late final GeneratedColumn<String> officeStatus = GeneratedColumn<String>(
      'office_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _conflictReasonMeta =
      const VerificationMeta('conflictReason');
  @override
  late final GeneratedColumn<String> conflictReason = GeneratedColumn<String>(
      'conflict_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        countId,
        businessDate,
        vendorId,
        stationKey,
        countedAt,
        syncStatus,
        officeStatus,
        conflictReason
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'closing_counts';
  @override
  VerificationContext validateIntegrity(Insertable<ClosingCount> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('count_id')) {
      context.handle(_countIdMeta,
          countId.isAcceptableOrUnknown(data['count_id']!, _countIdMeta));
    } else if (isInserting) {
      context.missing(_countIdMeta);
    }
    if (data.containsKey('business_date')) {
      context.handle(
          _businessDateMeta,
          businessDate.isAcceptableOrUnknown(
              data['business_date']!, _businessDateMeta));
    } else if (isInserting) {
      context.missing(_businessDateMeta);
    }
    if (data.containsKey('vendor_id')) {
      context.handle(_vendorIdMeta,
          vendorId.isAcceptableOrUnknown(data['vendor_id']!, _vendorIdMeta));
    } else if (isInserting) {
      context.missing(_vendorIdMeta);
    }
    if (data.containsKey('station_key')) {
      context.handle(
          _stationKeyMeta,
          stationKey.isAcceptableOrUnknown(
              data['station_key']!, _stationKeyMeta));
    } else if (isInserting) {
      context.missing(_stationKeyMeta);
    }
    if (data.containsKey('counted_at')) {
      context.handle(_countedAtMeta,
          countedAt.isAcceptableOrUnknown(data['counted_at']!, _countedAtMeta));
    } else if (isInserting) {
      context.missing(_countedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('office_status')) {
      context.handle(
          _officeStatusMeta,
          officeStatus.isAcceptableOrUnknown(
              data['office_status']!, _officeStatusMeta));
    }
    if (data.containsKey('conflict_reason')) {
      context.handle(
          _conflictReasonMeta,
          conflictReason.isAcceptableOrUnknown(
              data['conflict_reason']!, _conflictReasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {countId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {vendorId, stationKey, businessDate},
      ];
  @override
  ClosingCount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClosingCount(
      countId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}count_id'])!,
      businessDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}business_date'])!,
      vendorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vendor_id'])!,
      stationKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_key'])!,
      countedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}counted_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      officeStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}office_status'])!,
      conflictReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}conflict_reason']),
    );
  }

  @override
  $ClosingCountsTable createAlias(String alias) {
    return $ClosingCountsTable(attachedDatabase, alias);
  }
}

class ClosingCount extends DataClass implements Insertable<ClosingCount> {
  final String countId;

  /// The Dar es Salaam business date, `yyyy-mm-dd`.
  final String businessDate;
  final String vendorId;
  final String stationKey;
  final DateTime countedAt;

  /// `saved` (only on the phone) or `sent`.
  final String syncStatus;

  /// From the server: `pending` until staff confirm the count, then
  /// `confirmed`; `conflict` if the server did not record it.
  final String officeStatus;
  final String? conflictReason;
  const ClosingCount(
      {required this.countId,
      required this.businessDate,
      required this.vendorId,
      required this.stationKey,
      required this.countedAt,
      required this.syncStatus,
      required this.officeStatus,
      this.conflictReason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['count_id'] = Variable<String>(countId);
    map['business_date'] = Variable<String>(businessDate);
    map['vendor_id'] = Variable<String>(vendorId);
    map['station_key'] = Variable<String>(stationKey);
    map['counted_at'] = Variable<DateTime>(countedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['office_status'] = Variable<String>(officeStatus);
    if (!nullToAbsent || conflictReason != null) {
      map['conflict_reason'] = Variable<String>(conflictReason);
    }
    return map;
  }

  ClosingCountsCompanion toCompanion(bool nullToAbsent) {
    return ClosingCountsCompanion(
      countId: Value(countId),
      businessDate: Value(businessDate),
      vendorId: Value(vendorId),
      stationKey: Value(stationKey),
      countedAt: Value(countedAt),
      syncStatus: Value(syncStatus),
      officeStatus: Value(officeStatus),
      conflictReason: conflictReason == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictReason),
    );
  }

  factory ClosingCount.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClosingCount(
      countId: serializer.fromJson<String>(json['countId']),
      businessDate: serializer.fromJson<String>(json['businessDate']),
      vendorId: serializer.fromJson<String>(json['vendorId']),
      stationKey: serializer.fromJson<String>(json['stationKey']),
      countedAt: serializer.fromJson<DateTime>(json['countedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      officeStatus: serializer.fromJson<String>(json['officeStatus']),
      conflictReason: serializer.fromJson<String?>(json['conflictReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'countId': serializer.toJson<String>(countId),
      'businessDate': serializer.toJson<String>(businessDate),
      'vendorId': serializer.toJson<String>(vendorId),
      'stationKey': serializer.toJson<String>(stationKey),
      'countedAt': serializer.toJson<DateTime>(countedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'officeStatus': serializer.toJson<String>(officeStatus),
      'conflictReason': serializer.toJson<String?>(conflictReason),
    };
  }

  ClosingCount copyWith(
          {String? countId,
          String? businessDate,
          String? vendorId,
          String? stationKey,
          DateTime? countedAt,
          String? syncStatus,
          String? officeStatus,
          Value<String?> conflictReason = const Value.absent()}) =>
      ClosingCount(
        countId: countId ?? this.countId,
        businessDate: businessDate ?? this.businessDate,
        vendorId: vendorId ?? this.vendorId,
        stationKey: stationKey ?? this.stationKey,
        countedAt: countedAt ?? this.countedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        officeStatus: officeStatus ?? this.officeStatus,
        conflictReason:
            conflictReason.present ? conflictReason.value : this.conflictReason,
      );
  ClosingCount copyWithCompanion(ClosingCountsCompanion data) {
    return ClosingCount(
      countId: data.countId.present ? data.countId.value : this.countId,
      businessDate: data.businessDate.present
          ? data.businessDate.value
          : this.businessDate,
      vendorId: data.vendorId.present ? data.vendorId.value : this.vendorId,
      stationKey:
          data.stationKey.present ? data.stationKey.value : this.stationKey,
      countedAt: data.countedAt.present ? data.countedAt.value : this.countedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      officeStatus: data.officeStatus.present
          ? data.officeStatus.value
          : this.officeStatus,
      conflictReason: data.conflictReason.present
          ? data.conflictReason.value
          : this.conflictReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClosingCount(')
          ..write('countId: $countId, ')
          ..write('businessDate: $businessDate, ')
          ..write('vendorId: $vendorId, ')
          ..write('stationKey: $stationKey, ')
          ..write('countedAt: $countedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('officeStatus: $officeStatus, ')
          ..write('conflictReason: $conflictReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(countId, businessDate, vendorId, stationKey,
      countedAt, syncStatus, officeStatus, conflictReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClosingCount &&
          other.countId == this.countId &&
          other.businessDate == this.businessDate &&
          other.vendorId == this.vendorId &&
          other.stationKey == this.stationKey &&
          other.countedAt == this.countedAt &&
          other.syncStatus == this.syncStatus &&
          other.officeStatus == this.officeStatus &&
          other.conflictReason == this.conflictReason);
}

class ClosingCountsCompanion extends UpdateCompanion<ClosingCount> {
  final Value<String> countId;
  final Value<String> businessDate;
  final Value<String> vendorId;
  final Value<String> stationKey;
  final Value<DateTime> countedAt;
  final Value<String> syncStatus;
  final Value<String> officeStatus;
  final Value<String?> conflictReason;
  final Value<int> rowid;
  const ClosingCountsCompanion({
    this.countId = const Value.absent(),
    this.businessDate = const Value.absent(),
    this.vendorId = const Value.absent(),
    this.stationKey = const Value.absent(),
    this.countedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.officeStatus = const Value.absent(),
    this.conflictReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClosingCountsCompanion.insert({
    required String countId,
    required String businessDate,
    required String vendorId,
    required String stationKey,
    required DateTime countedAt,
    this.syncStatus = const Value.absent(),
    this.officeStatus = const Value.absent(),
    this.conflictReason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : countId = Value(countId),
        businessDate = Value(businessDate),
        vendorId = Value(vendorId),
        stationKey = Value(stationKey),
        countedAt = Value(countedAt);
  static Insertable<ClosingCount> custom({
    Expression<String>? countId,
    Expression<String>? businessDate,
    Expression<String>? vendorId,
    Expression<String>? stationKey,
    Expression<DateTime>? countedAt,
    Expression<String>? syncStatus,
    Expression<String>? officeStatus,
    Expression<String>? conflictReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (countId != null) 'count_id': countId,
      if (businessDate != null) 'business_date': businessDate,
      if (vendorId != null) 'vendor_id': vendorId,
      if (stationKey != null) 'station_key': stationKey,
      if (countedAt != null) 'counted_at': countedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (officeStatus != null) 'office_status': officeStatus,
      if (conflictReason != null) 'conflict_reason': conflictReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClosingCountsCompanion copyWith(
      {Value<String>? countId,
      Value<String>? businessDate,
      Value<String>? vendorId,
      Value<String>? stationKey,
      Value<DateTime>? countedAt,
      Value<String>? syncStatus,
      Value<String>? officeStatus,
      Value<String?>? conflictReason,
      Value<int>? rowid}) {
    return ClosingCountsCompanion(
      countId: countId ?? this.countId,
      businessDate: businessDate ?? this.businessDate,
      vendorId: vendorId ?? this.vendorId,
      stationKey: stationKey ?? this.stationKey,
      countedAt: countedAt ?? this.countedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      officeStatus: officeStatus ?? this.officeStatus,
      conflictReason: conflictReason ?? this.conflictReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (countId.present) {
      map['count_id'] = Variable<String>(countId.value);
    }
    if (businessDate.present) {
      map['business_date'] = Variable<String>(businessDate.value);
    }
    if (vendorId.present) {
      map['vendor_id'] = Variable<String>(vendorId.value);
    }
    if (stationKey.present) {
      map['station_key'] = Variable<String>(stationKey.value);
    }
    if (countedAt.present) {
      map['counted_at'] = Variable<DateTime>(countedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (officeStatus.present) {
      map['office_status'] = Variable<String>(officeStatus.value);
    }
    if (conflictReason.present) {
      map['conflict_reason'] = Variable<String>(conflictReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClosingCountsCompanion(')
          ..write('countId: $countId, ')
          ..write('businessDate: $businessDate, ')
          ..write('vendorId: $vendorId, ')
          ..write('stationKey: $stationKey, ')
          ..write('countedAt: $countedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('officeStatus: $officeStatus, ')
          ..write('conflictReason: $conflictReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClosingCountLinesTable extends ClosingCountLines
    with TableInfo<$ClosingCountLinesTable, ClosingCountLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClosingCountLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _countIdMeta =
      const VerificationMeta('countId');
  @override
  late final GeneratedColumn<String> countId = GeneratedColumn<String>(
      'count_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES closing_counts (count_id)'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordedMeta =
      const VerificationMeta('recorded');
  @override
  late final GeneratedColumn<int> recorded = GeneratedColumn<int>(
      'recorded', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _countedMeta =
      const VerificationMeta('counted');
  @override
  late final GeneratedColumn<int> counted = GeneratedColumn<int>(
      'counted', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [reason, note, countId, productId, productName, recorded, counted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'closing_count_lines';
  @override
  VerificationContext validateIntegrity(Insertable<ClosingCountLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('count_id')) {
      context.handle(_countIdMeta,
          countId.isAcceptableOrUnknown(data['count_id']!, _countIdMeta));
    } else if (isInserting) {
      context.missing(_countIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('recorded')) {
      context.handle(_recordedMeta,
          recorded.isAcceptableOrUnknown(data['recorded']!, _recordedMeta));
    }
    if (data.containsKey('counted')) {
      context.handle(_countedMeta,
          counted.isAcceptableOrUnknown(data['counted']!, _countedMeta));
    } else if (isInserting) {
      context.missing(_countedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {countId, productId};
  @override
  ClosingCountLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClosingCountLine(
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      countId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}count_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      recorded: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}recorded']),
      counted: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}counted'])!,
    );
  }

  @override
  $ClosingCountLinesTable createAlias(String alias) {
    return $ClosingCountLinesTable(attachedDatabase, alias);
  }
}

class ClosingCountLine extends DataClass
    implements Insertable<ClosingCountLine> {
  final String? reason;
  final String? note;
  final String countId;
  final String productId;
  final String productName;

  /// What the phone's records showed at the time (for staff), if tracked.
  final int? recorded;
  final int counted;
  const ClosingCountLine(
      {this.reason,
      this.note,
      required this.countId,
      required this.productId,
      required this.productName,
      this.recorded,
      required this.counted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['count_id'] = Variable<String>(countId);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    if (!nullToAbsent || recorded != null) {
      map['recorded'] = Variable<int>(recorded);
    }
    map['counted'] = Variable<int>(counted);
    return map;
  }

  ClosingCountLinesCompanion toCompanion(bool nullToAbsent) {
    return ClosingCountLinesCompanion(
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      countId: Value(countId),
      productId: Value(productId),
      productName: Value(productName),
      recorded: recorded == null && nullToAbsent
          ? const Value.absent()
          : Value(recorded),
      counted: Value(counted),
    );
  }

  factory ClosingCountLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClosingCountLine(
      reason: serializer.fromJson<String?>(json['reason']),
      note: serializer.fromJson<String?>(json['note']),
      countId: serializer.fromJson<String>(json['countId']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      recorded: serializer.fromJson<int?>(json['recorded']),
      counted: serializer.fromJson<int>(json['counted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reason': serializer.toJson<String?>(reason),
      'note': serializer.toJson<String?>(note),
      'countId': serializer.toJson<String>(countId),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'recorded': serializer.toJson<int?>(recorded),
      'counted': serializer.toJson<int>(counted),
    };
  }

  ClosingCountLine copyWith(
          {Value<String?> reason = const Value.absent(),
          Value<String?> note = const Value.absent(),
          String? countId,
          String? productId,
          String? productName,
          Value<int?> recorded = const Value.absent(),
          int? counted}) =>
      ClosingCountLine(
        reason: reason.present ? reason.value : this.reason,
        note: note.present ? note.value : this.note,
        countId: countId ?? this.countId,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        recorded: recorded.present ? recorded.value : this.recorded,
        counted: counted ?? this.counted,
      );
  ClosingCountLine copyWithCompanion(ClosingCountLinesCompanion data) {
    return ClosingCountLine(
      reason: data.reason.present ? data.reason.value : this.reason,
      note: data.note.present ? data.note.value : this.note,
      countId: data.countId.present ? data.countId.value : this.countId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      recorded: data.recorded.present ? data.recorded.value : this.recorded,
      counted: data.counted.present ? data.counted.value : this.counted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClosingCountLine(')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('countId: $countId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('recorded: $recorded, ')
          ..write('counted: $counted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      reason, note, countId, productId, productName, recorded, counted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClosingCountLine &&
          other.reason == this.reason &&
          other.note == this.note &&
          other.countId == this.countId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.recorded == this.recorded &&
          other.counted == this.counted);
}

class ClosingCountLinesCompanion extends UpdateCompanion<ClosingCountLine> {
  final Value<String?> reason;
  final Value<String?> note;
  final Value<String> countId;
  final Value<String> productId;
  final Value<String> productName;
  final Value<int?> recorded;
  final Value<int> counted;
  final Value<int> rowid;
  const ClosingCountLinesCompanion({
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.countId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.recorded = const Value.absent(),
    this.counted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClosingCountLinesCompanion.insert({
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    required String countId,
    required String productId,
    required String productName,
    this.recorded = const Value.absent(),
    required int counted,
    this.rowid = const Value.absent(),
  })  : countId = Value(countId),
        productId = Value(productId),
        productName = Value(productName),
        counted = Value(counted);
  static Insertable<ClosingCountLine> custom({
    Expression<String>? reason,
    Expression<String>? note,
    Expression<String>? countId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<int>? recorded,
    Expression<int>? counted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (countId != null) 'count_id': countId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (recorded != null) 'recorded': recorded,
      if (counted != null) 'counted': counted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClosingCountLinesCompanion copyWith(
      {Value<String?>? reason,
      Value<String?>? note,
      Value<String>? countId,
      Value<String>? productId,
      Value<String>? productName,
      Value<int?>? recorded,
      Value<int>? counted,
      Value<int>? rowid}) {
    return ClosingCountLinesCompanion(
      reason: reason ?? this.reason,
      note: note ?? this.note,
      countId: countId ?? this.countId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      recorded: recorded ?? this.recorded,
      counted: counted ?? this.counted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (countId.present) {
      map['count_id'] = Variable<String>(countId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (recorded.present) {
      map['recorded'] = Variable<int>(recorded.value);
    }
    if (counted.present) {
      map['counted'] = Variable<int>(counted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClosingCountLinesCompanion(')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('countId: $countId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('recorded: $recorded, ')
          ..write('counted: $counted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
      'op_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _opTypeMeta = const VerificationMeta('opType');
  @override
  late final GeneratedColumn<String> opType = GeneratedColumn<String>(
      'op_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vendorIdMeta =
      const VerificationMeta('vendorId');
  @override
  late final GeneratedColumn<String> vendorId = GeneratedColumn<String>(
      'vendor_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stationKeyMeta =
      const VerificationMeta('stationKey');
  @override
  late final GeneratedColumn<String> stationKey = GeneratedColumn<String>(
      'station_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _businessDateMeta =
      const VerificationMeta('businessDate');
  @override
  late final GeneratedColumn<String> businessDate = GeneratedColumn<String>(
      'business_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('saved'));
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resultReasonMeta =
      const VerificationMeta('resultReason');
  @override
  late final GeneratedColumn<String> resultReason = GeneratedColumn<String>(
      'result_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        opId,
        opType,
        vendorId,
        stationKey,
        businessDate,
        payload,
        createdAt,
        status,
        attempts,
        lastAttemptAt,
        nextAttemptAt,
        lastError,
        resultReason,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('op_id')) {
      context.handle(
          _opIdMeta, opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta));
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('op_type')) {
      context.handle(_opTypeMeta,
          opType.isAcceptableOrUnknown(data['op_type']!, _opTypeMeta));
    } else if (isInserting) {
      context.missing(_opTypeMeta);
    }
    if (data.containsKey('vendor_id')) {
      context.handle(_vendorIdMeta,
          vendorId.isAcceptableOrUnknown(data['vendor_id']!, _vendorIdMeta));
    } else if (isInserting) {
      context.missing(_vendorIdMeta);
    }
    if (data.containsKey('station_key')) {
      context.handle(
          _stationKeyMeta,
          stationKey.isAcceptableOrUnknown(
              data['station_key']!, _stationKeyMeta));
    } else if (isInserting) {
      context.missing(_stationKeyMeta);
    }
    if (data.containsKey('business_date')) {
      context.handle(
          _businessDateMeta,
          businessDate.isAcceptableOrUnknown(
              data['business_date']!, _businessDateMeta));
    } else if (isInserting) {
      context.missing(_businessDateMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('result_reason')) {
      context.handle(
          _resultReasonMeta,
          resultReason.isAcceptableOrUnknown(
              data['result_reason']!, _resultReasonMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {opId};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      opId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}op_id'])!,
      opType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}op_type'])!,
      vendorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vendor_id'])!,
      stationKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}station_key'])!,
      businessDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}business_date'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      resultReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_reason']),
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String opId;

  /// `sale`, `sale_void`, `receipt`, `damage_report` or `closing_count`.
  final String opType;
  final String vendorId;
  final String stationKey;

  /// Business date of the operation, `yyyy-mm-dd` (Dar es Salaam).
  final String businessDate;

  /// JSON body matching the server contract for [opType].
  final String payload;
  final DateTime createdAt;

  /// `saved` (never tried), `waiting` (will retry), `synchronizing`,
  /// `synchronized`, `conflict` (staff review) or `failed` (refused).
  final String status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime? nextAttemptAt;

  /// Technical cause of the last failed attempt, e.g. `offline`.
  final String? lastError;

  /// The server's reason for a conflict or refusal.
  final String? resultReason;
  final DateTime? syncedAt;
  const OutboxData(
      {required this.opId,
      required this.opType,
      required this.vendorId,
      required this.stationKey,
      required this.businessDate,
      required this.payload,
      required this.createdAt,
      required this.status,
      required this.attempts,
      this.lastAttemptAt,
      this.nextAttemptAt,
      this.lastError,
      this.resultReason,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['op_id'] = Variable<String>(opId);
    map['op_type'] = Variable<String>(opType);
    map['vendor_id'] = Variable<String>(vendorId);
    map['station_key'] = Variable<String>(stationKey);
    map['business_date'] = Variable<String>(businessDate);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || resultReason != null) {
      map['result_reason'] = Variable<String>(resultReason);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      opId: Value(opId),
      opType: Value(opType),
      vendorId: Value(vendorId),
      stationKey: Value(stationKey),
      businessDate: Value(businessDate),
      payload: Value(payload),
      createdAt: Value(createdAt),
      status: Value(status),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      resultReason: resultReason == null && nullToAbsent
          ? const Value.absent()
          : Value(resultReason),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory OutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      opId: serializer.fromJson<String>(json['opId']),
      opType: serializer.fromJson<String>(json['opType']),
      vendorId: serializer.fromJson<String>(json['vendorId']),
      stationKey: serializer.fromJson<String>(json['stationKey']),
      businessDate: serializer.fromJson<String>(json['businessDate']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      resultReason: serializer.fromJson<String?>(json['resultReason']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'opId': serializer.toJson<String>(opId),
      'opType': serializer.toJson<String>(opType),
      'vendorId': serializer.toJson<String>(vendorId),
      'stationKey': serializer.toJson<String>(stationKey),
      'businessDate': serializer.toJson<String>(businessDate),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'resultReason': serializer.toJson<String?>(resultReason),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  OutboxData copyWith(
          {String? opId,
          String? opType,
          String? vendorId,
          String? stationKey,
          String? businessDate,
          String? payload,
          DateTime? createdAt,
          String? status,
          int? attempts,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          Value<DateTime?> nextAttemptAt = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          Value<String?> resultReason = const Value.absent(),
          Value<DateTime?> syncedAt = const Value.absent()}) =>
      OutboxData(
        opId: opId ?? this.opId,
        opType: opType ?? this.opType,
        vendorId: vendorId ?? this.vendorId,
        stationKey: stationKey ?? this.stationKey,
        businessDate: businessDate ?? this.businessDate,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        resultReason:
            resultReason.present ? resultReason.value : this.resultReason,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      opId: data.opId.present ? data.opId.value : this.opId,
      opType: data.opType.present ? data.opType.value : this.opType,
      vendorId: data.vendorId.present ? data.vendorId.value : this.vendorId,
      stationKey:
          data.stationKey.present ? data.stationKey.value : this.stationKey,
      businessDate: data.businessDate.present
          ? data.businessDate.value
          : this.businessDate,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      resultReason: data.resultReason.present
          ? data.resultReason.value
          : this.resultReason,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('opId: $opId, ')
          ..write('opType: $opType, ')
          ..write('vendorId: $vendorId, ')
          ..write('stationKey: $stationKey, ')
          ..write('businessDate: $businessDate, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('resultReason: $resultReason, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      opId,
      opType,
      vendorId,
      stationKey,
      businessDate,
      payload,
      createdAt,
      status,
      attempts,
      lastAttemptAt,
      nextAttemptAt,
      lastError,
      resultReason,
      syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.opId == this.opId &&
          other.opType == this.opType &&
          other.vendorId == this.vendorId &&
          other.stationKey == this.stationKey &&
          other.businessDate == this.businessDate &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.resultReason == this.resultReason &&
          other.syncedAt == this.syncedAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> opId;
  final Value<String> opType;
  final Value<String> vendorId;
  final Value<String> stationKey;
  final Value<String> businessDate;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> attempts;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<String?> resultReason;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.opId = const Value.absent(),
    this.opType = const Value.absent(),
    this.vendorId = const Value.absent(),
    this.stationKey = const Value.absent(),
    this.businessDate = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.resultReason = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String opId,
    required String opType,
    required String vendorId,
    required String stationKey,
    required String businessDate,
    required String payload,
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.resultReason = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : opId = Value(opId),
        opType = Value(opType),
        vendorId = Value(vendorId),
        stationKey = Value(stationKey),
        businessDate = Value(businessDate),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? opId,
    Expression<String>? opType,
    Expression<String>? vendorId,
    Expression<String>? stationKey,
    Expression<String>? businessDate,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<String>? resultReason,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (opId != null) 'op_id': opId,
      if (opType != null) 'op_type': opType,
      if (vendorId != null) 'vendor_id': vendorId,
      if (stationKey != null) 'station_key': stationKey,
      if (businessDate != null) 'business_date': businessDate,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (resultReason != null) 'result_reason': resultReason,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith(
      {Value<String>? opId,
      Value<String>? opType,
      Value<String>? vendorId,
      Value<String>? stationKey,
      Value<String>? businessDate,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<String>? status,
      Value<int>? attempts,
      Value<DateTime?>? lastAttemptAt,
      Value<DateTime?>? nextAttemptAt,
      Value<String?>? lastError,
      Value<String?>? resultReason,
      Value<DateTime?>? syncedAt,
      Value<int>? rowid}) {
    return OutboxCompanion(
      opId: opId ?? this.opId,
      opType: opType ?? this.opType,
      vendorId: vendorId ?? this.vendorId,
      stationKey: stationKey ?? this.stationKey,
      businessDate: businessDate ?? this.businessDate,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      resultReason: resultReason ?? this.resultReason,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (opType.present) {
      map['op_type'] = Variable<String>(opType.value);
    }
    if (vendorId.present) {
      map['vendor_id'] = Variable<String>(vendorId.value);
    }
    if (stationKey.present) {
      map['station_key'] = Variable<String>(stationKey.value);
    }
    if (businessDate.present) {
      map['business_date'] = Variable<String>(businessDate.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (resultReason.present) {
      map['result_reason'] = Variable<String>(resultReason.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('opId: $opId, ')
          ..write('opType: $opType, ')
          ..write('vendorId: $vendorId, ')
          ..write('stationKey: $stationKey, ')
          ..write('businessDate: $businessDate, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('resultReason: $resultReason, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncLogTable extends SyncLog with TableInfo<$SyncLogTable, SyncLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
      'at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _outcomeMeta =
      const VerificationMeta('outcome');
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
      'outcome', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sentMeta = const VerificationMeta('sent');
  @override
  late final GeneratedColumn<int> sent = GeneratedColumn<int>(
      'sent', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _acceptedMeta =
      const VerificationMeta('accepted');
  @override
  late final GeneratedColumn<int> accepted = GeneratedColumn<int>(
      'accepted', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _conflictsMeta =
      const VerificationMeta('conflicts');
  @override
  late final GeneratedColumn<int> conflicts = GeneratedColumn<int>(
      'conflicts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rejectedMeta =
      const VerificationMeta('rejected');
  @override
  late final GeneratedColumn<int> rejected = GeneratedColumn<int>(
      'rejected', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
      'detail', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, at, outcome, sent, accepted, conflicts, rejected, detail];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_log';
  @override
  VerificationContext validateIntegrity(Insertable<SyncLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(_outcomeMeta,
          outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta));
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('sent')) {
      context.handle(
          _sentMeta, sent.isAcceptableOrUnknown(data['sent']!, _sentMeta));
    }
    if (data.containsKey('accepted')) {
      context.handle(_acceptedMeta,
          accepted.isAcceptableOrUnknown(data['accepted']!, _acceptedMeta));
    }
    if (data.containsKey('conflicts')) {
      context.handle(_conflictsMeta,
          conflicts.isAcceptableOrUnknown(data['conflicts']!, _conflictsMeta));
    }
    if (data.containsKey('rejected')) {
      context.handle(_rejectedMeta,
          rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta));
    }
    if (data.containsKey('detail')) {
      context.handle(_detailMeta,
          detail.isAcceptableOrUnknown(data['detail']!, _detailMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLogData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      at: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}at'])!,
      outcome: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outcome'])!,
      sent: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sent'])!,
      accepted: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}accepted'])!,
      conflicts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}conflicts'])!,
      rejected: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rejected'])!,
      detail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}detail']),
    );
  }

  @override
  $SyncLogTable createAlias(String alias) {
    return $SyncLogTable(attachedDatabase, alias);
  }
}

class SyncLogData extends DataClass implements Insertable<SyncLogData> {
  final int id;
  final DateTime at;

  /// `ok`, `offline`, `not_configured`, `session_expired` or `error`.
  final String outcome;
  final int sent;
  final int accepted;
  final int conflicts;
  final int rejected;

  /// Error type name only, for diagnosis.
  final String? detail;
  const SyncLogData(
      {required this.id,
      required this.at,
      required this.outcome,
      required this.sent,
      required this.accepted,
      required this.conflicts,
      required this.rejected,
      this.detail});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<DateTime>(at);
    map['outcome'] = Variable<String>(outcome);
    map['sent'] = Variable<int>(sent);
    map['accepted'] = Variable<int>(accepted);
    map['conflicts'] = Variable<int>(conflicts);
    map['rejected'] = Variable<int>(rejected);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  SyncLogCompanion toCompanion(bool nullToAbsent) {
    return SyncLogCompanion(
      id: Value(id),
      at: Value(at),
      outcome: Value(outcome),
      sent: Value(sent),
      accepted: Value(accepted),
      conflicts: Value(conflicts),
      rejected: Value(rejected),
      detail:
          detail == null && nullToAbsent ? const Value.absent() : Value(detail),
    );
  }

  factory SyncLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLogData(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      outcome: serializer.fromJson<String>(json['outcome']),
      sent: serializer.fromJson<int>(json['sent']),
      accepted: serializer.fromJson<int>(json['accepted']),
      conflicts: serializer.fromJson<int>(json['conflicts']),
      rejected: serializer.fromJson<int>(json['rejected']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'outcome': serializer.toJson<String>(outcome),
      'sent': serializer.toJson<int>(sent),
      'accepted': serializer.toJson<int>(accepted),
      'conflicts': serializer.toJson<int>(conflicts),
      'rejected': serializer.toJson<int>(rejected),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  SyncLogData copyWith(
          {int? id,
          DateTime? at,
          String? outcome,
          int? sent,
          int? accepted,
          int? conflicts,
          int? rejected,
          Value<String?> detail = const Value.absent()}) =>
      SyncLogData(
        id: id ?? this.id,
        at: at ?? this.at,
        outcome: outcome ?? this.outcome,
        sent: sent ?? this.sent,
        accepted: accepted ?? this.accepted,
        conflicts: conflicts ?? this.conflicts,
        rejected: rejected ?? this.rejected,
        detail: detail.present ? detail.value : this.detail,
      );
  SyncLogData copyWithCompanion(SyncLogCompanion data) {
    return SyncLogData(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      sent: data.sent.present ? data.sent.value : this.sent,
      accepted: data.accepted.present ? data.accepted.value : this.accepted,
      conflicts: data.conflicts.present ? data.conflicts.value : this.conflicts,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogData(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('outcome: $outcome, ')
          ..write('sent: $sent, ')
          ..write('accepted: $accepted, ')
          ..write('conflicts: $conflicts, ')
          ..write('rejected: $rejected, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, at, outcome, sent, accepted, conflicts, rejected, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLogData &&
          other.id == this.id &&
          other.at == this.at &&
          other.outcome == this.outcome &&
          other.sent == this.sent &&
          other.accepted == this.accepted &&
          other.conflicts == this.conflicts &&
          other.rejected == this.rejected &&
          other.detail == this.detail);
}

class SyncLogCompanion extends UpdateCompanion<SyncLogData> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<String> outcome;
  final Value<int> sent;
  final Value<int> accepted;
  final Value<int> conflicts;
  final Value<int> rejected;
  final Value<String?> detail;
  const SyncLogCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.outcome = const Value.absent(),
    this.sent = const Value.absent(),
    this.accepted = const Value.absent(),
    this.conflicts = const Value.absent(),
    this.rejected = const Value.absent(),
    this.detail = const Value.absent(),
  });
  SyncLogCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    required String outcome,
    this.sent = const Value.absent(),
    this.accepted = const Value.absent(),
    this.conflicts = const Value.absent(),
    this.rejected = const Value.absent(),
    this.detail = const Value.absent(),
  })  : at = Value(at),
        outcome = Value(outcome);
  static Insertable<SyncLogData> custom({
    Expression<int>? id,
    Expression<DateTime>? at,
    Expression<String>? outcome,
    Expression<int>? sent,
    Expression<int>? accepted,
    Expression<int>? conflicts,
    Expression<int>? rejected,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (outcome != null) 'outcome': outcome,
      if (sent != null) 'sent': sent,
      if (accepted != null) 'accepted': accepted,
      if (conflicts != null) 'conflicts': conflicts,
      if (rejected != null) 'rejected': rejected,
      if (detail != null) 'detail': detail,
    });
  }

  SyncLogCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? at,
      Value<String>? outcome,
      Value<int>? sent,
      Value<int>? accepted,
      Value<int>? conflicts,
      Value<int>? rejected,
      Value<String?>? detail}) {
    return SyncLogCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      outcome: outcome ?? this.outcome,
      sent: sent ?? this.sent,
      accepted: accepted ?? this.accepted,
      conflicts: conflicts ?? this.conflicts,
      rejected: rejected ?? this.rejected,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (sent.present) {
      map['sent'] = Variable<int>(sent.value);
    }
    if (accepted.present) {
      map['accepted'] = Variable<int>(accepted.value);
    }
    if (conflicts.present) {
      map['conflicts'] = Variable<int>(conflicts.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<int>(rejected.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLogCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('outcome: $outcome, ')
          ..write('sent: $sent, ')
          ..write('accepted: $accepted, ')
          ..write('conflicts: $conflicts, ')
          ..write('rejected: $rejected, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CatalogProductsTable catalogProducts =
      $CatalogProductsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleLinesTable saleLines = $SaleLinesTable(this);
  late final $SaleVoidsTable saleVoids = $SaleVoidsTable(this);
  late final $DeliveriesTable deliveries = $DeliveriesTable(this);
  late final $DeliveryLinesTable deliveryLines = $DeliveryLinesTable(this);
  late final $ReceiptsTable receipts = $ReceiptsTable(this);
  late final $ReceiptLinesTable receiptLines = $ReceiptLinesTable(this);
  late final $DamageReportsTable damageReports = $DamageReportsTable(this);
  late final $ClosingCountsTable closingCounts = $ClosingCountsTable(this);
  late final $ClosingCountLinesTable closingCountLines =
      $ClosingCountLinesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncLogTable syncLog = $SyncLogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        catalogProducts,
        settings,
        sales,
        saleLines,
        saleVoids,
        deliveries,
        deliveryLines,
        receipts,
        receiptLines,
        damageReports,
        closingCounts,
        closingCountLines,
        outbox,
        syncLog
      ];
}

typedef $$CatalogProductsTableCreateCompanionBuilder = CatalogProductsCompanion
    Function({
  required String id,
  required String name,
  Value<int?> price,
  Value<String?> priceVersion,
  Value<String> category,
  Value<String?> imageKey,
  Value<int?> available,
  Value<String?> held,
  Value<String?> cutFrom,
  Value<int?> cutCount,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$CatalogProductsTableUpdateCompanionBuilder = CatalogProductsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<int?> price,
  Value<String?> priceVersion,
  Value<String> category,
  Value<String?> imageKey,
  Value<int?> available,
  Value<String?> held,
  Value<String?> cutFrom,
  Value<int?> cutCount,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$CatalogProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogProductsTable> {
  $$CatalogProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priceVersion => $composableBuilder(
      column: $table.priceVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageKey => $composableBuilder(
      column: $table.imageKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get available => $composableBuilder(
      column: $table.available, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get held => $composableBuilder(
      column: $table.held, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cutFrom => $composableBuilder(
      column: $table.cutFrom, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cutCount => $composableBuilder(
      column: $table.cutCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$CatalogProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogProductsTable> {
  $$CatalogProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priceVersion => $composableBuilder(
      column: $table.priceVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageKey => $composableBuilder(
      column: $table.imageKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get available => $composableBuilder(
      column: $table.available, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get held => $composableBuilder(
      column: $table.held, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cutFrom => $composableBuilder(
      column: $table.cutFrom, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cutCount => $composableBuilder(
      column: $table.cutCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$CatalogProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogProductsTable> {
  $$CatalogProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get priceVersion => $composableBuilder(
      column: $table.priceVersion, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get imageKey =>
      $composableBuilder(column: $table.imageKey, builder: (column) => column);

  GeneratedColumn<int> get available =>
      $composableBuilder(column: $table.available, builder: (column) => column);

  GeneratedColumn<String> get held =>
      $composableBuilder(column: $table.held, builder: (column) => column);

  GeneratedColumn<String> get cutFrom =>
      $composableBuilder(column: $table.cutFrom, builder: (column) => column);

  GeneratedColumn<int> get cutCount =>
      $composableBuilder(column: $table.cutCount, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$CatalogProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CatalogProductsTable,
    CatalogProduct,
    $$CatalogProductsTableFilterComposer,
    $$CatalogProductsTableOrderingComposer,
    $$CatalogProductsTableAnnotationComposer,
    $$CatalogProductsTableCreateCompanionBuilder,
    $$CatalogProductsTableUpdateCompanionBuilder,
    (
      CatalogProduct,
      BaseReferences<_$AppDatabase, $CatalogProductsTable, CatalogProduct>
    ),
    CatalogProduct,
    PrefetchHooks Function()> {
  $$CatalogProductsTableTableManager(
      _$AppDatabase db, $CatalogProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int?> price = const Value.absent(),
            Value<String?> priceVersion = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String?> imageKey = const Value.absent(),
            Value<int?> available = const Value.absent(),
            Value<String?> held = const Value.absent(),
            Value<String?> cutFrom = const Value.absent(),
            Value<int?> cutCount = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CatalogProductsCompanion(
            id: id,
            name: name,
            price: price,
            priceVersion: priceVersion,
            category: category,
            imageKey: imageKey,
            available: available,
            held: held,
            cutFrom: cutFrom,
            cutCount: cutCount,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<int?> price = const Value.absent(),
            Value<String?> priceVersion = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String?> imageKey = const Value.absent(),
            Value<int?> available = const Value.absent(),
            Value<String?> held = const Value.absent(),
            Value<String?> cutFrom = const Value.absent(),
            Value<int?> cutCount = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CatalogProductsCompanion.insert(
            id: id,
            name: name,
            price: price,
            priceVersion: priceVersion,
            category: category,
            imageKey: imageKey,
            available: available,
            held: held,
            cutFrom: cutFrom,
            cutCount: cutCount,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CatalogProductsTable, CatalogProduct>(table),
                    BaseReferences<_$AppDatabase, $CatalogProductsTable,
                        CatalogProduct>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CatalogProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CatalogProductsTable,
    CatalogProduct,
    $$CatalogProductsTableFilterComposer,
    $$CatalogProductsTableOrderingComposer,
    $$CatalogProductsTableAnnotationComposer,
    $$CatalogProductsTableCreateCompanionBuilder,
    $$CatalogProductsTableUpdateCompanionBuilder,
    (
      CatalogProduct,
      BaseReferences<_$AppDatabase, $CatalogProductsTable, CatalogProduct>
    ),
    CatalogProduct,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SettingsTable, Setting>(table),
                    BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  required String clientId,
  required String vendorId,
  required DateTime recordedAt,
  required String paymentMethod,
  required int total,
  Value<String?> creditCustomerId,
  Value<String?> creditCustomerName,
  Value<String> syncStatus,
  Value<String> verification,
  Value<int> rowid,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<String> clientId,
  Value<String> vendorId,
  Value<DateTime> recordedAt,
  Value<String> paymentMethod,
  Value<int> total,
  Value<String?> creditCustomerId,
  Value<String?> creditCustomerName,
  Value<String> syncStatus,
  Value<String> verification,
  Value<int> rowid,
});

final class $$SalesTableReferences
    extends BaseReferences<_$AppDatabase, $SalesTable, Sale> {
  $$SalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SaleLinesTable, List<SaleLine>>
      _saleLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.saleLines,
              aliasName: 'sales__client_id__sale_lines__sale_client_id');

  $$SaleLinesTableProcessedTableManager get saleLinesRefs {
    final manager = $$SaleLinesTableTableManager($_db, $_db.saleLines).filter(
        (f) => f.saleClientId.clientId
            .sqlEquals($_itemColumn<String>('client_id')!));

    final cache = $_typedResult.readTableOrNull(_saleLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SaleVoidsTable, List<SaleVoid>>
      _saleVoidsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.saleVoids,
              aliasName: 'sales__client_id__sale_voids__sale_client_id');

  $$SaleVoidsTableProcessedTableManager get saleVoidsRefs {
    final manager = $$SaleVoidsTableTableManager($_db, $_db.saleVoids).filter(
        (f) => f.saleClientId.clientId
            .sqlEquals($_itemColumn<String>('client_id')!));

    final cache = $_typedResult.readTableOrNull(_saleVoidsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vendorId => $composableBuilder(
      column: $table.vendorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get total => $composableBuilder(
      column: $table.total, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get creditCustomerId => $composableBuilder(
      column: $table.creditCustomerId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get creditCustomerName => $composableBuilder(
      column: $table.creditCustomerName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get verification => $composableBuilder(
      column: $table.verification, builder: (column) => ColumnFilters(column));

  Expression<bool> saleLinesRefs(
      Expression<bool> Function($$SaleLinesTableFilterComposer f) f) {
    final $$SaleLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.saleLines,
        getReferencedColumn: (t) => t.saleClientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleLinesTableFilterComposer(
              $db: $db,
              $table: $db.saleLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> saleVoidsRefs(
      Expression<bool> Function($$SaleVoidsTableFilterComposer f) f) {
    final $$SaleVoidsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.saleVoids,
        getReferencedColumn: (t) => t.saleClientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleVoidsTableFilterComposer(
              $db: $db,
              $table: $db.saleVoids,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vendorId => $composableBuilder(
      column: $table.vendorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get total => $composableBuilder(
      column: $table.total, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get creditCustomerId => $composableBuilder(
      column: $table.creditCustomerId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get creditCustomerName => $composableBuilder(
      column: $table.creditCustomerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get verification => $composableBuilder(
      column: $table.verification,
      builder: (column) => ColumnOrderings(column));
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get vendorId =>
      $composableBuilder(column: $table.vendorId, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get creditCustomerId => $composableBuilder(
      column: $table.creditCustomerId, builder: (column) => column);

  GeneratedColumn<String> get creditCustomerName => $composableBuilder(
      column: $table.creditCustomerName, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get verification => $composableBuilder(
      column: $table.verification, builder: (column) => column);

  Expression<T> saleLinesRefs<T extends Object>(
      Expression<T> Function($$SaleLinesTableAnnotationComposer a) f) {
    final $$SaleLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.saleLines,
        getReferencedColumn: (t) => t.saleClientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.saleLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> saleVoidsRefs<T extends Object>(
      Expression<T> Function($$SaleVoidsTableAnnotationComposer a) f) {
    final $$SaleVoidsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.clientId,
        referencedTable: $db.saleVoids,
        getReferencedColumn: (t) => t.saleClientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SaleVoidsTableAnnotationComposer(
              $db: $db,
              $table: $db.saleVoids,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SalesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, $$SalesTableReferences),
    Sale,
    PrefetchHooks Function({bool saleLinesRefs, bool saleVoidsRefs})> {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientId = const Value.absent(),
            Value<String> vendorId = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
            Value<String> paymentMethod = const Value.absent(),
            Value<int> total = const Value.absent(),
            Value<String?> creditCustomerId = const Value.absent(),
            Value<String?> creditCustomerName = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String> verification = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesCompanion(
            clientId: clientId,
            vendorId: vendorId,
            recordedAt: recordedAt,
            paymentMethod: paymentMethod,
            total: total,
            creditCustomerId: creditCustomerId,
            creditCustomerName: creditCustomerName,
            syncStatus: syncStatus,
            verification: verification,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientId,
            required String vendorId,
            required DateTime recordedAt,
            required String paymentMethod,
            required int total,
            Value<String?> creditCustomerId = const Value.absent(),
            Value<String?> creditCustomerName = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String> verification = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesCompanion.insert(
            clientId: clientId,
            vendorId: vendorId,
            recordedAt: recordedAt,
            paymentMethod: paymentMethod,
            total: total,
            creditCustomerId: creditCustomerId,
            creditCustomerName: creditCustomerName,
            syncStatus: syncStatus,
            verification: verification,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SalesTable, Sale>(table),
                    $$SalesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {saleLinesRefs = false, saleVoidsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (saleLinesRefs) db.saleLines,
                if (saleVoidsRefs) db.saleVoids
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (saleLinesRefs)
                    await $_getPrefetchedData<Sale, $SalesTable, SaleLine>(
                        currentTable: table,
                        referencedTable:
                            $$SalesTableReferences._saleLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SalesTableReferences(db, table, p0).saleLinesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.saleClientId == item.clientId),
                        typedResults: items),
                  if (saleVoidsRefs)
                    await $_getPrefetchedData<Sale, $SalesTable, SaleVoid>(
                        currentTable: table,
                        referencedTable:
                            $$SalesTableReferences._saleVoidsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SalesTableReferences(db, table, p0).saleVoidsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.saleClientId == item.clientId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SalesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, $$SalesTableReferences),
    Sale,
    PrefetchHooks Function({bool saleLinesRefs, bool saleVoidsRefs})>;
typedef $$SaleLinesTableCreateCompanionBuilder = SaleLinesCompanion Function({
  Value<int> id,
  required String saleClientId,
  required String productId,
  required String productName,
  required int quantity,
  required int unitPrice,
  Value<String?> priceVersion,
  required int lineTotal,
  Value<bool> exceedsRecordedStock,
});
typedef $$SaleLinesTableUpdateCompanionBuilder = SaleLinesCompanion Function({
  Value<int> id,
  Value<String> saleClientId,
  Value<String> productId,
  Value<String> productName,
  Value<int> quantity,
  Value<int> unitPrice,
  Value<String?> priceVersion,
  Value<int> lineTotal,
  Value<bool> exceedsRecordedStock,
});

final class $$SaleLinesTableReferences
    extends BaseReferences<_$AppDatabase, $SaleLinesTable, SaleLine> {
  $$SaleLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SalesTable _saleClientIdTable(_$AppDatabase db) =>
      db.sales.createAlias('sale_lines__sale_client_id__sales__client_id');

  $$SalesTableProcessedTableManager get saleClientId {
    final $_column = $_itemColumn<String>('sale_client_id')!;

    final manager = $$SalesTableTableManager($_db, $_db.sales)
        .filter((f) => f.clientId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleClientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SaleLinesTableFilterComposer
    extends Composer<_$AppDatabase, $SaleLinesTable> {
  $$SaleLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priceVersion => $composableBuilder(
      column: $table.priceVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lineTotal => $composableBuilder(
      column: $table.lineTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get exceedsRecordedStock => $composableBuilder(
      column: $table.exceedsRecordedStock,
      builder: (column) => ColumnFilters(column));

  $$SalesTableFilterComposer get saleClientId {
    final $$SalesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleClientId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableFilterComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $SaleLinesTable> {
  $$SaleLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priceVersion => $composableBuilder(
      column: $table.priceVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lineTotal => $composableBuilder(
      column: $table.lineTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get exceedsRecordedStock => $composableBuilder(
      column: $table.exceedsRecordedStock,
      builder: (column) => ColumnOrderings(column));

  $$SalesTableOrderingComposer get saleClientId {
    final $$SalesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleClientId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableOrderingComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SaleLinesTable> {
  $$SaleLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<String> get priceVersion => $composableBuilder(
      column: $table.priceVersion, builder: (column) => column);

  GeneratedColumn<int> get lineTotal =>
      $composableBuilder(column: $table.lineTotal, builder: (column) => column);

  GeneratedColumn<bool> get exceedsRecordedStock => $composableBuilder(
      column: $table.exceedsRecordedStock, builder: (column) => column);

  $$SalesTableAnnotationComposer get saleClientId {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleClientId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableAnnotationComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SaleLinesTable,
    SaleLine,
    $$SaleLinesTableFilterComposer,
    $$SaleLinesTableOrderingComposer,
    $$SaleLinesTableAnnotationComposer,
    $$SaleLinesTableCreateCompanionBuilder,
    $$SaleLinesTableUpdateCompanionBuilder,
    (SaleLine, $$SaleLinesTableReferences),
    SaleLine,
    PrefetchHooks Function({bool saleClientId})> {
  $$SaleLinesTableTableManager(_$AppDatabase db, $SaleLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> saleClientId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<int> unitPrice = const Value.absent(),
            Value<String?> priceVersion = const Value.absent(),
            Value<int> lineTotal = const Value.absent(),
            Value<bool> exceedsRecordedStock = const Value.absent(),
          }) =>
              SaleLinesCompanion(
            id: id,
            saleClientId: saleClientId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            priceVersion: priceVersion,
            lineTotal: lineTotal,
            exceedsRecordedStock: exceedsRecordedStock,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String saleClientId,
            required String productId,
            required String productName,
            required int quantity,
            required int unitPrice,
            Value<String?> priceVersion = const Value.absent(),
            required int lineTotal,
            Value<bool> exceedsRecordedStock = const Value.absent(),
          }) =>
              SaleLinesCompanion.insert(
            id: id,
            saleClientId: saleClientId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            priceVersion: priceVersion,
            lineTotal: lineTotal,
            exceedsRecordedStock: exceedsRecordedStock,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SaleLinesTable, SaleLine>(table),
                    $$SaleLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({saleClientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (saleClientId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.saleClientId,
                    referencedTable:
                        $$SaleLinesTableReferences._saleClientIdTable(db),
                    referencedColumn: $$SaleLinesTableReferences
                        ._saleClientIdTable(db)
                        .clientId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SaleLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SaleLinesTable,
    SaleLine,
    $$SaleLinesTableFilterComposer,
    $$SaleLinesTableOrderingComposer,
    $$SaleLinesTableAnnotationComposer,
    $$SaleLinesTableCreateCompanionBuilder,
    $$SaleLinesTableUpdateCompanionBuilder,
    (SaleLine, $$SaleLinesTableReferences),
    SaleLine,
    PrefetchHooks Function({bool saleClientId})>;
typedef $$SaleVoidsTableCreateCompanionBuilder = SaleVoidsCompanion Function({
  Value<String?> note,
  required String voidId,
  required String saleClientId,
  required String reason,
  required String actorId,
  required DateTime requestedAt,
  Value<String> syncStatus,
  Value<String?> rejectionReason,
  Value<int> rowid,
});
typedef $$SaleVoidsTableUpdateCompanionBuilder = SaleVoidsCompanion Function({
  Value<String?> note,
  Value<String> voidId,
  Value<String> saleClientId,
  Value<String> reason,
  Value<String> actorId,
  Value<DateTime> requestedAt,
  Value<String> syncStatus,
  Value<String?> rejectionReason,
  Value<int> rowid,
});

final class $$SaleVoidsTableReferences
    extends BaseReferences<_$AppDatabase, $SaleVoidsTable, SaleVoid> {
  $$SaleVoidsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SalesTable _saleClientIdTable(_$AppDatabase db) =>
      db.sales.createAlias('sale_voids__sale_client_id__sales__client_id');

  $$SalesTableProcessedTableManager get saleClientId {
    final $_column = $_itemColumn<String>('sale_client_id')!;

    final manager = $$SalesTableTableManager($_db, $_db.sales)
        .filter((f) => f.clientId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleClientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SaleVoidsTableFilterComposer
    extends Composer<_$AppDatabase, $SaleVoidsTable> {
  $$SaleVoidsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get voidId => $composableBuilder(
      column: $table.voidId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get requestedAt => $composableBuilder(
      column: $table.requestedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rejectionReason => $composableBuilder(
      column: $table.rejectionReason,
      builder: (column) => ColumnFilters(column));

  $$SalesTableFilterComposer get saleClientId {
    final $$SalesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleClientId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableFilterComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleVoidsTableOrderingComposer
    extends Composer<_$AppDatabase, $SaleVoidsTable> {
  $$SaleVoidsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get voidId => $composableBuilder(
      column: $table.voidId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get requestedAt => $composableBuilder(
      column: $table.requestedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rejectionReason => $composableBuilder(
      column: $table.rejectionReason,
      builder: (column) => ColumnOrderings(column));

  $$SalesTableOrderingComposer get saleClientId {
    final $$SalesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleClientId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableOrderingComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleVoidsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SaleVoidsTable> {
  $$SaleVoidsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get voidId =>
      $composableBuilder(column: $table.voidId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get requestedAt => $composableBuilder(
      column: $table.requestedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get rejectionReason => $composableBuilder(
      column: $table.rejectionReason, builder: (column) => column);

  $$SalesTableAnnotationComposer get saleClientId {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.saleClientId,
        referencedTable: $db.sales,
        getReferencedColumn: (t) => t.clientId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SalesTableAnnotationComposer(
              $db: $db,
              $table: $db.sales,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SaleVoidsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SaleVoidsTable,
    SaleVoid,
    $$SaleVoidsTableFilterComposer,
    $$SaleVoidsTableOrderingComposer,
    $$SaleVoidsTableAnnotationComposer,
    $$SaleVoidsTableCreateCompanionBuilder,
    $$SaleVoidsTableUpdateCompanionBuilder,
    (SaleVoid, $$SaleVoidsTableReferences),
    SaleVoid,
    PrefetchHooks Function({bool saleClientId})> {
  $$SaleVoidsTableTableManager(_$AppDatabase db, $SaleVoidsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleVoidsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleVoidsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleVoidsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String?> note = const Value.absent(),
            Value<String> voidId = const Value.absent(),
            Value<String> saleClientId = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String> actorId = const Value.absent(),
            Value<DateTime> requestedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String?> rejectionReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SaleVoidsCompanion(
            note: note,
            voidId: voidId,
            saleClientId: saleClientId,
            reason: reason,
            actorId: actorId,
            requestedAt: requestedAt,
            syncStatus: syncStatus,
            rejectionReason: rejectionReason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String?> note = const Value.absent(),
            required String voidId,
            required String saleClientId,
            required String reason,
            required String actorId,
            required DateTime requestedAt,
            Value<String> syncStatus = const Value.absent(),
            Value<String?> rejectionReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SaleVoidsCompanion.insert(
            note: note,
            voidId: voidId,
            saleClientId: saleClientId,
            reason: reason,
            actorId: actorId,
            requestedAt: requestedAt,
            syncStatus: syncStatus,
            rejectionReason: rejectionReason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SaleVoidsTable, SaleVoid>(table),
                    $$SaleVoidsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({saleClientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (saleClientId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.saleClientId,
                    referencedTable:
                        $$SaleVoidsTableReferences._saleClientIdTable(db),
                    referencedColumn: $$SaleVoidsTableReferences
                        ._saleClientIdTable(db)
                        .clientId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SaleVoidsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SaleVoidsTable,
    SaleVoid,
    $$SaleVoidsTableFilterComposer,
    $$SaleVoidsTableOrderingComposer,
    $$SaleVoidsTableAnnotationComposer,
    $$SaleVoidsTableCreateCompanionBuilder,
    $$SaleVoidsTableUpdateCompanionBuilder,
    (SaleVoid, $$SaleVoidsTableReferences),
    SaleVoid,
    PrefetchHooks Function({bool saleClientId})>;
typedef $$DeliveriesTableCreateCompanionBuilder = DeliveriesCompanion Function({
  required String consignmentId,
  required int version,
  required String reference,
  required String sender,
  required String stationKey,
  required String stationName,
  required DateTime dispatchedAt,
  Value<int> rowid,
});
typedef $$DeliveriesTableUpdateCompanionBuilder = DeliveriesCompanion Function({
  Value<String> consignmentId,
  Value<int> version,
  Value<String> reference,
  Value<String> sender,
  Value<String> stationKey,
  Value<String> stationName,
  Value<DateTime> dispatchedAt,
  Value<int> rowid,
});

class $$DeliveriesTableFilterComposer
    extends Composer<_$AppDatabase, $DeliveriesTable> {
  $$DeliveriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sender => $composableBuilder(
      column: $table.sender, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stationName => $composableBuilder(
      column: $table.stationName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dispatchedAt => $composableBuilder(
      column: $table.dispatchedAt, builder: (column) => ColumnFilters(column));
}

class $$DeliveriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeliveriesTable> {
  $$DeliveriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sender => $composableBuilder(
      column: $table.sender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stationName => $composableBuilder(
      column: $table.stationName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dispatchedAt => $composableBuilder(
      column: $table.dispatchedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$DeliveriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeliveriesTable> {
  $$DeliveriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => column);

  GeneratedColumn<String> get stationName => $composableBuilder(
      column: $table.stationName, builder: (column) => column);

  GeneratedColumn<DateTime> get dispatchedAt => $composableBuilder(
      column: $table.dispatchedAt, builder: (column) => column);
}

class $$DeliveriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeliveriesTable,
    Delivery,
    $$DeliveriesTableFilterComposer,
    $$DeliveriesTableOrderingComposer,
    $$DeliveriesTableAnnotationComposer,
    $$DeliveriesTableCreateCompanionBuilder,
    $$DeliveriesTableUpdateCompanionBuilder,
    (Delivery, BaseReferences<_$AppDatabase, $DeliveriesTable, Delivery>),
    Delivery,
    PrefetchHooks Function()> {
  $$DeliveriesTableTableManager(_$AppDatabase db, $DeliveriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> consignmentId = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> reference = const Value.absent(),
            Value<String> sender = const Value.absent(),
            Value<String> stationKey = const Value.absent(),
            Value<String> stationName = const Value.absent(),
            Value<DateTime> dispatchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeliveriesCompanion(
            consignmentId: consignmentId,
            version: version,
            reference: reference,
            sender: sender,
            stationKey: stationKey,
            stationName: stationName,
            dispatchedAt: dispatchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String consignmentId,
            required int version,
            required String reference,
            required String sender,
            required String stationKey,
            required String stationName,
            required DateTime dispatchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DeliveriesCompanion.insert(
            consignmentId: consignmentId,
            version: version,
            reference: reference,
            sender: sender,
            stationKey: stationKey,
            stationName: stationName,
            dispatchedAt: dispatchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DeliveriesTable, Delivery>(table),
                    BaseReferences<_$AppDatabase, $DeliveriesTable, Delivery>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeliveriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeliveriesTable,
    Delivery,
    $$DeliveriesTableFilterComposer,
    $$DeliveriesTableOrderingComposer,
    $$DeliveriesTableAnnotationComposer,
    $$DeliveriesTableCreateCompanionBuilder,
    $$DeliveriesTableUpdateCompanionBuilder,
    (Delivery, BaseReferences<_$AppDatabase, $DeliveriesTable, Delivery>),
    Delivery,
    PrefetchHooks Function()>;
typedef $$DeliveryLinesTableCreateCompanionBuilder = DeliveryLinesCompanion
    Function({
  required String consignmentId,
  required String lineId,
  required String productId,
  required String productName,
  required int quantity,
  Value<String?> imageKey,
  Value<int> rowid,
});
typedef $$DeliveryLinesTableUpdateCompanionBuilder = DeliveryLinesCompanion
    Function({
  Value<String> consignmentId,
  Value<String> lineId,
  Value<String> productId,
  Value<String> productName,
  Value<int> quantity,
  Value<String?> imageKey,
  Value<int> rowid,
});

class $$DeliveryLinesTableFilterComposer
    extends Composer<_$AppDatabase, $DeliveryLinesTable> {
  $$DeliveryLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lineId => $composableBuilder(
      column: $table.lineId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageKey => $composableBuilder(
      column: $table.imageKey, builder: (column) => ColumnFilters(column));
}

class $$DeliveryLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeliveryLinesTable> {
  $$DeliveryLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lineId => $composableBuilder(
      column: $table.lineId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageKey => $composableBuilder(
      column: $table.imageKey, builder: (column) => ColumnOrderings(column));
}

class $$DeliveryLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeliveryLinesTable> {
  $$DeliveryLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get imageKey =>
      $composableBuilder(column: $table.imageKey, builder: (column) => column);
}

class $$DeliveryLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DeliveryLinesTable,
    DeliveryLine,
    $$DeliveryLinesTableFilterComposer,
    $$DeliveryLinesTableOrderingComposer,
    $$DeliveryLinesTableAnnotationComposer,
    $$DeliveryLinesTableCreateCompanionBuilder,
    $$DeliveryLinesTableUpdateCompanionBuilder,
    (
      DeliveryLine,
      BaseReferences<_$AppDatabase, $DeliveryLinesTable, DeliveryLine>
    ),
    DeliveryLine,
    PrefetchHooks Function()> {
  $$DeliveryLinesTableTableManager(_$AppDatabase db, $DeliveryLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveryLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveryLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveryLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> consignmentId = const Value.absent(),
            Value<String> lineId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<String?> imageKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeliveryLinesCompanion(
            consignmentId: consignmentId,
            lineId: lineId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            imageKey: imageKey,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String consignmentId,
            required String lineId,
            required String productId,
            required String productName,
            required int quantity,
            Value<String?> imageKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DeliveryLinesCompanion.insert(
            consignmentId: consignmentId,
            lineId: lineId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            imageKey: imageKey,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DeliveryLinesTable, DeliveryLine>(table),
                    BaseReferences<_$AppDatabase, $DeliveryLinesTable,
                        DeliveryLine>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DeliveryLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DeliveryLinesTable,
    DeliveryLine,
    $$DeliveryLinesTableFilterComposer,
    $$DeliveryLinesTableOrderingComposer,
    $$DeliveryLinesTableAnnotationComposer,
    $$DeliveryLinesTableCreateCompanionBuilder,
    $$DeliveryLinesTableUpdateCompanionBuilder,
    (
      DeliveryLine,
      BaseReferences<_$AppDatabase, $DeliveryLinesTable, DeliveryLine>
    ),
    DeliveryLine,
    PrefetchHooks Function()>;
typedef $$ReceiptsTableCreateCompanionBuilder = ReceiptsCompanion Function({
  required String receiptId,
  required String eventId,
  required String consignmentId,
  required int consignmentVersion,
  required String stationKey,
  required String actorId,
  required DateTime receivedAt,
  Value<String> syncStatus,
  Value<String?> conflictReason,
  Value<int> rowid,
});
typedef $$ReceiptsTableUpdateCompanionBuilder = ReceiptsCompanion Function({
  Value<String> receiptId,
  Value<String> eventId,
  Value<String> consignmentId,
  Value<int> consignmentVersion,
  Value<String> stationKey,
  Value<String> actorId,
  Value<DateTime> receivedAt,
  Value<String> syncStatus,
  Value<String?> conflictReason,
  Value<int> rowid,
});

final class $$ReceiptsTableReferences
    extends BaseReferences<_$AppDatabase, $ReceiptsTable, Receipt> {
  $$ReceiptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReceiptLinesTable, List<ReceiptLine>>
      _receiptLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.receiptLines,
              aliasName: 'receipts__receipt_id__receipt_lines__receipt_id');

  $$ReceiptLinesTableProcessedTableManager get receiptLinesRefs {
    final manager = $$ReceiptLinesTableTableManager($_db, $_db.receiptLines)
        .filter((f) => f.receiptId.receiptId
            .sqlEquals($_itemColumn<String>('receipt_id')!));

    final cache = $_typedResult.readTableOrNull(_receiptLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get receiptId => $composableBuilder(
      column: $table.receiptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get consignmentVersion => $composableBuilder(
      column: $table.consignmentVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conflictReason => $composableBuilder(
      column: $table.conflictReason,
      builder: (column) => ColumnFilters(column));

  Expression<bool> receiptLinesRefs(
      Expression<bool> Function($$ReceiptLinesTableFilterComposer f) f) {
    final $$ReceiptLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.receiptId,
        referencedTable: $db.receiptLines,
        getReferencedColumn: (t) => t.receiptId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReceiptLinesTableFilterComposer(
              $db: $db,
              $table: $db.receiptLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get receiptId => $composableBuilder(
      column: $table.receiptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get consignmentVersion => $composableBuilder(
      column: $table.consignmentVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conflictReason => $composableBuilder(
      column: $table.conflictReason,
      builder: (column) => ColumnOrderings(column));
}

class $$ReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get receiptId =>
      $composableBuilder(column: $table.receiptId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get consignmentId => $composableBuilder(
      column: $table.consignmentId, builder: (column) => column);

  GeneratedColumn<int> get consignmentVersion => $composableBuilder(
      column: $table.consignmentVersion, builder: (column) => column);

  GeneratedColumn<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get conflictReason => $composableBuilder(
      column: $table.conflictReason, builder: (column) => column);

  Expression<T> receiptLinesRefs<T extends Object>(
      Expression<T> Function($$ReceiptLinesTableAnnotationComposer a) f) {
    final $$ReceiptLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.receiptId,
        referencedTable: $db.receiptLines,
        getReferencedColumn: (t) => t.receiptId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReceiptLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.receiptLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ReceiptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReceiptsTable,
    Receipt,
    $$ReceiptsTableFilterComposer,
    $$ReceiptsTableOrderingComposer,
    $$ReceiptsTableAnnotationComposer,
    $$ReceiptsTableCreateCompanionBuilder,
    $$ReceiptsTableUpdateCompanionBuilder,
    (Receipt, $$ReceiptsTableReferences),
    Receipt,
    PrefetchHooks Function({bool receiptLinesRefs})> {
  $$ReceiptsTableTableManager(_$AppDatabase db, $ReceiptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> receiptId = const Value.absent(),
            Value<String> eventId = const Value.absent(),
            Value<String> consignmentId = const Value.absent(),
            Value<int> consignmentVersion = const Value.absent(),
            Value<String> stationKey = const Value.absent(),
            Value<String> actorId = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String?> conflictReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReceiptsCompanion(
            receiptId: receiptId,
            eventId: eventId,
            consignmentId: consignmentId,
            consignmentVersion: consignmentVersion,
            stationKey: stationKey,
            actorId: actorId,
            receivedAt: receivedAt,
            syncStatus: syncStatus,
            conflictReason: conflictReason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String receiptId,
            required String eventId,
            required String consignmentId,
            required int consignmentVersion,
            required String stationKey,
            required String actorId,
            required DateTime receivedAt,
            Value<String> syncStatus = const Value.absent(),
            Value<String?> conflictReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReceiptsCompanion.insert(
            receiptId: receiptId,
            eventId: eventId,
            consignmentId: consignmentId,
            consignmentVersion: consignmentVersion,
            stationKey: stationKey,
            actorId: actorId,
            receivedAt: receivedAt,
            syncStatus: syncStatus,
            conflictReason: conflictReason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ReceiptsTable, Receipt>(table),
                    $$ReceiptsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({receiptLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (receiptLinesRefs) db.receiptLines],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (receiptLinesRefs)
                    await $_getPrefetchedData<Receipt, $ReceiptsTable,
                            ReceiptLine>(
                        currentTable: table,
                        referencedTable: $$ReceiptsTableReferences
                            ._receiptLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ReceiptsTableReferences(db, table, p0)
                                .receiptLinesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.receiptId == item.receiptId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ReceiptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReceiptsTable,
    Receipt,
    $$ReceiptsTableFilterComposer,
    $$ReceiptsTableOrderingComposer,
    $$ReceiptsTableAnnotationComposer,
    $$ReceiptsTableCreateCompanionBuilder,
    $$ReceiptsTableUpdateCompanionBuilder,
    (Receipt, $$ReceiptsTableReferences),
    Receipt,
    PrefetchHooks Function({bool receiptLinesRefs})>;
typedef $$ReceiptLinesTableCreateCompanionBuilder = ReceiptLinesCompanion
    Function({
  Value<String?> note,
  required String receiptId,
  required String lineId,
  required int accepted,
  required int rejected,
  Value<String?> reason,
  Value<int> rowid,
});
typedef $$ReceiptLinesTableUpdateCompanionBuilder = ReceiptLinesCompanion
    Function({
  Value<String?> note,
  Value<String> receiptId,
  Value<String> lineId,
  Value<int> accepted,
  Value<int> rejected,
  Value<String?> reason,
  Value<int> rowid,
});

final class $$ReceiptLinesTableReferences
    extends BaseReferences<_$AppDatabase, $ReceiptLinesTable, ReceiptLine> {
  $$ReceiptLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ReceiptsTable _receiptIdTable(_$AppDatabase db) => db.receipts
      .createAlias('receipt_lines__receipt_id__receipts__receipt_id');

  $$ReceiptsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<String>('receipt_id')!;

    final manager = $$ReceiptsTableTableManager($_db, $_db.receipts)
        .filter((f) => f.receiptId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReceiptLinesTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptLinesTable> {
  $$ReceiptLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lineId => $composableBuilder(
      column: $table.lineId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accepted => $composableBuilder(
      column: $table.accepted, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rejected => $composableBuilder(
      column: $table.rejected, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  $$ReceiptsTableFilterComposer get receiptId {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.receiptId,
        referencedTable: $db.receipts,
        getReferencedColumn: (t) => t.receiptId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReceiptsTableFilterComposer(
              $db: $db,
              $table: $db.receipts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReceiptLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptLinesTable> {
  $$ReceiptLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lineId => $composableBuilder(
      column: $table.lineId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accepted => $composableBuilder(
      column: $table.accepted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rejected => $composableBuilder(
      column: $table.rejected, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  $$ReceiptsTableOrderingComposer get receiptId {
    final $$ReceiptsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.receiptId,
        referencedTable: $db.receipts,
        getReferencedColumn: (t) => t.receiptId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReceiptsTableOrderingComposer(
              $db: $db,
              $table: $db.receipts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReceiptLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptLinesTable> {
  $$ReceiptLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<int> get accepted =>
      $composableBuilder(column: $table.accepted, builder: (column) => column);

  GeneratedColumn<int> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  $$ReceiptsTableAnnotationComposer get receiptId {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.receiptId,
        referencedTable: $db.receipts,
        getReferencedColumn: (t) => t.receiptId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReceiptsTableAnnotationComposer(
              $db: $db,
              $table: $db.receipts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReceiptLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReceiptLinesTable,
    ReceiptLine,
    $$ReceiptLinesTableFilterComposer,
    $$ReceiptLinesTableOrderingComposer,
    $$ReceiptLinesTableAnnotationComposer,
    $$ReceiptLinesTableCreateCompanionBuilder,
    $$ReceiptLinesTableUpdateCompanionBuilder,
    (ReceiptLine, $$ReceiptLinesTableReferences),
    ReceiptLine,
    PrefetchHooks Function({bool receiptId})> {
  $$ReceiptLinesTableTableManager(_$AppDatabase db, $ReceiptLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String?> note = const Value.absent(),
            Value<String> receiptId = const Value.absent(),
            Value<String> lineId = const Value.absent(),
            Value<int> accepted = const Value.absent(),
            Value<int> rejected = const Value.absent(),
            Value<String?> reason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReceiptLinesCompanion(
            note: note,
            receiptId: receiptId,
            lineId: lineId,
            accepted: accepted,
            rejected: rejected,
            reason: reason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String?> note = const Value.absent(),
            required String receiptId,
            required String lineId,
            required int accepted,
            required int rejected,
            Value<String?> reason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReceiptLinesCompanion.insert(
            note: note,
            receiptId: receiptId,
            lineId: lineId,
            accepted: accepted,
            rejected: rejected,
            reason: reason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ReceiptLinesTable, ReceiptLine>(table),
                    $$ReceiptLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({receiptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (receiptId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.receiptId,
                    referencedTable:
                        $$ReceiptLinesTableReferences._receiptIdTable(db),
                    referencedColumn: $$ReceiptLinesTableReferences
                        ._receiptIdTable(db)
                        .receiptId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReceiptLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReceiptLinesTable,
    ReceiptLine,
    $$ReceiptLinesTableFilterComposer,
    $$ReceiptLinesTableOrderingComposer,
    $$ReceiptLinesTableAnnotationComposer,
    $$ReceiptLinesTableCreateCompanionBuilder,
    $$ReceiptLinesTableUpdateCompanionBuilder,
    (ReceiptLine, $$ReceiptLinesTableReferences),
    ReceiptLine,
    PrefetchHooks Function({bool receiptId})>;
typedef $$DamageReportsTableCreateCompanionBuilder = DamageReportsCompanion
    Function({
  required String reportId,
  required String productId,
  required String productName,
  required int quantity,
  required String reason,
  Value<String?> note,
  Value<String?> imagePath,
  required String stationKey,
  required String actorId,
  required DateTime reportedAt,
  Value<String> syncStatus,
  Value<String> review,
  Value<int> rowid,
});
typedef $$DamageReportsTableUpdateCompanionBuilder = DamageReportsCompanion
    Function({
  Value<String> reportId,
  Value<String> productId,
  Value<String> productName,
  Value<int> quantity,
  Value<String> reason,
  Value<String?> note,
  Value<String?> imagePath,
  Value<String> stationKey,
  Value<String> actorId,
  Value<DateTime> reportedAt,
  Value<String> syncStatus,
  Value<String> review,
  Value<int> rowid,
});

class $$DamageReportsTableFilterComposer
    extends Composer<_$AppDatabase, $DamageReportsTable> {
  $$DamageReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reportId => $composableBuilder(
      column: $table.reportId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reportedAt => $composableBuilder(
      column: $table.reportedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get review => $composableBuilder(
      column: $table.review, builder: (column) => ColumnFilters(column));
}

class $$DamageReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $DamageReportsTable> {
  $$DamageReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reportId => $composableBuilder(
      column: $table.reportId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reportedAt => $composableBuilder(
      column: $table.reportedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get review => $composableBuilder(
      column: $table.review, builder: (column) => ColumnOrderings(column));
}

class $$DamageReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DamageReportsTable> {
  $$DamageReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reportId =>
      $composableBuilder(column: $table.reportId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get reportedAt => $composableBuilder(
      column: $table.reportedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get review =>
      $composableBuilder(column: $table.review, builder: (column) => column);
}

class $$DamageReportsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DamageReportsTable,
    DamageReport,
    $$DamageReportsTableFilterComposer,
    $$DamageReportsTableOrderingComposer,
    $$DamageReportsTableAnnotationComposer,
    $$DamageReportsTableCreateCompanionBuilder,
    $$DamageReportsTableUpdateCompanionBuilder,
    (
      DamageReport,
      BaseReferences<_$AppDatabase, $DamageReportsTable, DamageReport>
    ),
    DamageReport,
    PrefetchHooks Function()> {
  $$DamageReportsTableTableManager(_$AppDatabase db, $DamageReportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DamageReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DamageReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DamageReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> reportId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<String> stationKey = const Value.absent(),
            Value<String> actorId = const Value.absent(),
            Value<DateTime> reportedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String> review = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DamageReportsCompanion(
            reportId: reportId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            reason: reason,
            note: note,
            imagePath: imagePath,
            stationKey: stationKey,
            actorId: actorId,
            reportedAt: reportedAt,
            syncStatus: syncStatus,
            review: review,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String reportId,
            required String productId,
            required String productName,
            required int quantity,
            required String reason,
            Value<String?> note = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            required String stationKey,
            required String actorId,
            required DateTime reportedAt,
            Value<String> syncStatus = const Value.absent(),
            Value<String> review = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DamageReportsCompanion.insert(
            reportId: reportId,
            productId: productId,
            productName: productName,
            quantity: quantity,
            reason: reason,
            note: note,
            imagePath: imagePath,
            stationKey: stationKey,
            actorId: actorId,
            reportedAt: reportedAt,
            syncStatus: syncStatus,
            review: review,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$DamageReportsTable, DamageReport>(table),
                    BaseReferences<_$AppDatabase, $DamageReportsTable,
                        DamageReport>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DamageReportsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DamageReportsTable,
    DamageReport,
    $$DamageReportsTableFilterComposer,
    $$DamageReportsTableOrderingComposer,
    $$DamageReportsTableAnnotationComposer,
    $$DamageReportsTableCreateCompanionBuilder,
    $$DamageReportsTableUpdateCompanionBuilder,
    (
      DamageReport,
      BaseReferences<_$AppDatabase, $DamageReportsTable, DamageReport>
    ),
    DamageReport,
    PrefetchHooks Function()>;
typedef $$ClosingCountsTableCreateCompanionBuilder = ClosingCountsCompanion
    Function({
  required String countId,
  required String businessDate,
  required String vendorId,
  required String stationKey,
  required DateTime countedAt,
  Value<String> syncStatus,
  Value<String> officeStatus,
  Value<String?> conflictReason,
  Value<int> rowid,
});
typedef $$ClosingCountsTableUpdateCompanionBuilder = ClosingCountsCompanion
    Function({
  Value<String> countId,
  Value<String> businessDate,
  Value<String> vendorId,
  Value<String> stationKey,
  Value<DateTime> countedAt,
  Value<String> syncStatus,
  Value<String> officeStatus,
  Value<String?> conflictReason,
  Value<int> rowid,
});

final class $$ClosingCountsTableReferences
    extends BaseReferences<_$AppDatabase, $ClosingCountsTable, ClosingCount> {
  $$ClosingCountsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ClosingCountLinesTable, List<ClosingCountLine>>
      _closingCountLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.closingCountLines,
              aliasName:
                  'closing_counts__count_id__closing_count_lines__count_id');

  $$ClosingCountLinesTableProcessedTableManager get closingCountLinesRefs {
    final manager =
        $$ClosingCountLinesTableTableManager($_db, $_db.closingCountLines)
            .filter((f) =>
                f.countId.countId.sqlEquals($_itemColumn<String>('count_id')!));

    final cache =
        $_typedResult.readTableOrNull(_closingCountLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ClosingCountsTableFilterComposer
    extends Composer<_$AppDatabase, $ClosingCountsTable> {
  $$ClosingCountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get countId => $composableBuilder(
      column: $table.countId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get businessDate => $composableBuilder(
      column: $table.businessDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vendorId => $composableBuilder(
      column: $table.vendorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get countedAt => $composableBuilder(
      column: $table.countedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get officeStatus => $composableBuilder(
      column: $table.officeStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conflictReason => $composableBuilder(
      column: $table.conflictReason,
      builder: (column) => ColumnFilters(column));

  Expression<bool> closingCountLinesRefs(
      Expression<bool> Function($$ClosingCountLinesTableFilterComposer f) f) {
    final $$ClosingCountLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.countId,
        referencedTable: $db.closingCountLines,
        getReferencedColumn: (t) => t.countId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClosingCountLinesTableFilterComposer(
              $db: $db,
              $table: $db.closingCountLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ClosingCountsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClosingCountsTable> {
  $$ClosingCountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get countId => $composableBuilder(
      column: $table.countId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get businessDate => $composableBuilder(
      column: $table.businessDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vendorId => $composableBuilder(
      column: $table.vendorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get countedAt => $composableBuilder(
      column: $table.countedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get officeStatus => $composableBuilder(
      column: $table.officeStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conflictReason => $composableBuilder(
      column: $table.conflictReason,
      builder: (column) => ColumnOrderings(column));
}

class $$ClosingCountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClosingCountsTable> {
  $$ClosingCountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get countId =>
      $composableBuilder(column: $table.countId, builder: (column) => column);

  GeneratedColumn<String> get businessDate => $composableBuilder(
      column: $table.businessDate, builder: (column) => column);

  GeneratedColumn<String> get vendorId =>
      $composableBuilder(column: $table.vendorId, builder: (column) => column);

  GeneratedColumn<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => column);

  GeneratedColumn<DateTime> get countedAt =>
      $composableBuilder(column: $table.countedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get officeStatus => $composableBuilder(
      column: $table.officeStatus, builder: (column) => column);

  GeneratedColumn<String> get conflictReason => $composableBuilder(
      column: $table.conflictReason, builder: (column) => column);

  Expression<T> closingCountLinesRefs<T extends Object>(
      Expression<T> Function($$ClosingCountLinesTableAnnotationComposer a) f) {
    final $$ClosingCountLinesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.countId,
            referencedTable: $db.closingCountLines,
            getReferencedColumn: (t) => t.countId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ClosingCountLinesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.closingCountLines,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ClosingCountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClosingCountsTable,
    ClosingCount,
    $$ClosingCountsTableFilterComposer,
    $$ClosingCountsTableOrderingComposer,
    $$ClosingCountsTableAnnotationComposer,
    $$ClosingCountsTableCreateCompanionBuilder,
    $$ClosingCountsTableUpdateCompanionBuilder,
    (ClosingCount, $$ClosingCountsTableReferences),
    ClosingCount,
    PrefetchHooks Function({bool closingCountLinesRefs})> {
  $$ClosingCountsTableTableManager(_$AppDatabase db, $ClosingCountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClosingCountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClosingCountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClosingCountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> countId = const Value.absent(),
            Value<String> businessDate = const Value.absent(),
            Value<String> vendorId = const Value.absent(),
            Value<String> stationKey = const Value.absent(),
            Value<DateTime> countedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String> officeStatus = const Value.absent(),
            Value<String?> conflictReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClosingCountsCompanion(
            countId: countId,
            businessDate: businessDate,
            vendorId: vendorId,
            stationKey: stationKey,
            countedAt: countedAt,
            syncStatus: syncStatus,
            officeStatus: officeStatus,
            conflictReason: conflictReason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String countId,
            required String businessDate,
            required String vendorId,
            required String stationKey,
            required DateTime countedAt,
            Value<String> syncStatus = const Value.absent(),
            Value<String> officeStatus = const Value.absent(),
            Value<String?> conflictReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClosingCountsCompanion.insert(
            countId: countId,
            businessDate: businessDate,
            vendorId: vendorId,
            stationKey: stationKey,
            countedAt: countedAt,
            syncStatus: syncStatus,
            officeStatus: officeStatus,
            conflictReason: conflictReason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ClosingCountsTable, ClosingCount>(table),
                    $$ClosingCountsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({closingCountLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (closingCountLinesRefs) db.closingCountLines
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (closingCountLinesRefs)
                    await $_getPrefetchedData<ClosingCount, $ClosingCountsTable,
                            ClosingCountLine>(
                        currentTable: table,
                        referencedTable: $$ClosingCountsTableReferences
                            ._closingCountLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ClosingCountsTableReferences(db, table, p0)
                                .closingCountLinesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.countId == item.countId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ClosingCountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClosingCountsTable,
    ClosingCount,
    $$ClosingCountsTableFilterComposer,
    $$ClosingCountsTableOrderingComposer,
    $$ClosingCountsTableAnnotationComposer,
    $$ClosingCountsTableCreateCompanionBuilder,
    $$ClosingCountsTableUpdateCompanionBuilder,
    (ClosingCount, $$ClosingCountsTableReferences),
    ClosingCount,
    PrefetchHooks Function({bool closingCountLinesRefs})>;
typedef $$ClosingCountLinesTableCreateCompanionBuilder
    = ClosingCountLinesCompanion Function({
  Value<String?> reason,
  Value<String?> note,
  required String countId,
  required String productId,
  required String productName,
  Value<int?> recorded,
  required int counted,
  Value<int> rowid,
});
typedef $$ClosingCountLinesTableUpdateCompanionBuilder
    = ClosingCountLinesCompanion Function({
  Value<String?> reason,
  Value<String?> note,
  Value<String> countId,
  Value<String> productId,
  Value<String> productName,
  Value<int?> recorded,
  Value<int> counted,
  Value<int> rowid,
});

final class $$ClosingCountLinesTableReferences extends BaseReferences<
    _$AppDatabase, $ClosingCountLinesTable, ClosingCountLine> {
  $$ClosingCountLinesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ClosingCountsTable _countIdTable(_$AppDatabase db) => db.closingCounts
      .createAlias('closing_count_lines__count_id__closing_counts__count_id');

  $$ClosingCountsTableProcessedTableManager get countId {
    final $_column = $_itemColumn<String>('count_id')!;

    final manager = $$ClosingCountsTableTableManager($_db, $_db.closingCounts)
        .filter((f) => f.countId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_countIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ClosingCountLinesTableFilterComposer
    extends Composer<_$AppDatabase, $ClosingCountLinesTable> {
  $$ClosingCountLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recorded => $composableBuilder(
      column: $table.recorded, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get counted => $composableBuilder(
      column: $table.counted, builder: (column) => ColumnFilters(column));

  $$ClosingCountsTableFilterComposer get countId {
    final $$ClosingCountsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.countId,
        referencedTable: $db.closingCounts,
        getReferencedColumn: (t) => t.countId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClosingCountsTableFilterComposer(
              $db: $db,
              $table: $db.closingCounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ClosingCountLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClosingCountLinesTable> {
  $$ClosingCountLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recorded => $composableBuilder(
      column: $table.recorded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get counted => $composableBuilder(
      column: $table.counted, builder: (column) => ColumnOrderings(column));

  $$ClosingCountsTableOrderingComposer get countId {
    final $$ClosingCountsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.countId,
        referencedTable: $db.closingCounts,
        getReferencedColumn: (t) => t.countId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClosingCountsTableOrderingComposer(
              $db: $db,
              $table: $db.closingCounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ClosingCountLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClosingCountLinesTable> {
  $$ClosingCountLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<int> get recorded =>
      $composableBuilder(column: $table.recorded, builder: (column) => column);

  GeneratedColumn<int> get counted =>
      $composableBuilder(column: $table.counted, builder: (column) => column);

  $$ClosingCountsTableAnnotationComposer get countId {
    final $$ClosingCountsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.countId,
        referencedTable: $db.closingCounts,
        getReferencedColumn: (t) => t.countId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ClosingCountsTableAnnotationComposer(
              $db: $db,
              $table: $db.closingCounts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ClosingCountLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClosingCountLinesTable,
    ClosingCountLine,
    $$ClosingCountLinesTableFilterComposer,
    $$ClosingCountLinesTableOrderingComposer,
    $$ClosingCountLinesTableAnnotationComposer,
    $$ClosingCountLinesTableCreateCompanionBuilder,
    $$ClosingCountLinesTableUpdateCompanionBuilder,
    (ClosingCountLine, $$ClosingCountLinesTableReferences),
    ClosingCountLine,
    PrefetchHooks Function({bool countId})> {
  $$ClosingCountLinesTableTableManager(
      _$AppDatabase db, $ClosingCountLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClosingCountLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClosingCountLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClosingCountLinesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String?> reason = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<String> countId = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<int?> recorded = const Value.absent(),
            Value<int> counted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ClosingCountLinesCompanion(
            reason: reason,
            note: note,
            countId: countId,
            productId: productId,
            productName: productName,
            recorded: recorded,
            counted: counted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String?> reason = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required String countId,
            required String productId,
            required String productName,
            Value<int?> recorded = const Value.absent(),
            required int counted,
            Value<int> rowid = const Value.absent(),
          }) =>
              ClosingCountLinesCompanion.insert(
            reason: reason,
            note: note,
            countId: countId,
            productId: productId,
            productName: productName,
            recorded: recorded,
            counted: counted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ClosingCountLinesTable, ClosingCountLine>(
                        table),
                    $$ClosingCountLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({countId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (countId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.countId,
                    referencedTable:
                        $$ClosingCountLinesTableReferences._countIdTable(db),
                    referencedColumn: $$ClosingCountLinesTableReferences
                        ._countIdTable(db)
                        .countId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ClosingCountLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClosingCountLinesTable,
    ClosingCountLine,
    $$ClosingCountLinesTableFilterComposer,
    $$ClosingCountLinesTableOrderingComposer,
    $$ClosingCountLinesTableAnnotationComposer,
    $$ClosingCountLinesTableCreateCompanionBuilder,
    $$ClosingCountLinesTableUpdateCompanionBuilder,
    (ClosingCountLine, $$ClosingCountLinesTableReferences),
    ClosingCountLine,
    PrefetchHooks Function({bool countId})>;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String opId,
  required String opType,
  required String vendorId,
  required String stationKey,
  required String businessDate,
  required String payload,
  required DateTime createdAt,
  Value<String> status,
  Value<int> attempts,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> nextAttemptAt,
  Value<String?> lastError,
  Value<String?> resultReason,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> opId,
  Value<String> opType,
  Value<String> vendorId,
  Value<String> stationKey,
  Value<String> businessDate,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> attempts,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> nextAttemptAt,
  Value<String?> lastError,
  Value<String?> resultReason,
  Value<DateTime?> syncedAt,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get opId => $composableBuilder(
      column: $table.opId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opType => $composableBuilder(
      column: $table.opType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vendorId => $composableBuilder(
      column: $table.vendorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get businessDate => $composableBuilder(
      column: $table.businessDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultReason => $composableBuilder(
      column: $table.resultReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get opId => $composableBuilder(
      column: $table.opId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opType => $composableBuilder(
      column: $table.opType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vendorId => $composableBuilder(
      column: $table.vendorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get businessDate => $composableBuilder(
      column: $table.businessDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultReason => $composableBuilder(
      column: $table.resultReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get opType =>
      $composableBuilder(column: $table.opType, builder: (column) => column);

  GeneratedColumn<String> get vendorId =>
      $composableBuilder(column: $table.vendorId, builder: (column) => column);

  GeneratedColumn<String> get stationKey => $composableBuilder(
      column: $table.stationKey, builder: (column) => column);

  GeneratedColumn<String> get businessDate => $composableBuilder(
      column: $table.businessDate, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get resultReason => $composableBuilder(
      column: $table.resultReason, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> opId = const Value.absent(),
            Value<String> opType = const Value.absent(),
            Value<String> vendorId = const Value.absent(),
            Value<String> stationKey = const Value.absent(),
            Value<String> businessDate = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String?> resultReason = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion(
            opId: opId,
            opType: opType,
            vendorId: vendorId,
            stationKey: stationKey,
            businessDate: businessDate,
            payload: payload,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            resultReason: resultReason,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String opId,
            required String opType,
            required String vendorId,
            required String stationKey,
            required String businessDate,
            required String payload,
            required DateTime createdAt,
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String?> resultReason = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            opId: opId,
            opType: opType,
            vendorId: vendorId,
            stationKey: stationKey,
            businessDate: businessDate,
            payload: payload,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            resultReason: resultReason,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxTable, OutboxData>(table),
                    BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxTable,
    OutboxData,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
    OutboxData,
    PrefetchHooks Function()>;
typedef $$SyncLogTableCreateCompanionBuilder = SyncLogCompanion Function({
  Value<int> id,
  required DateTime at,
  required String outcome,
  Value<int> sent,
  Value<int> accepted,
  Value<int> conflicts,
  Value<int> rejected,
  Value<String?> detail,
});
typedef $$SyncLogTableUpdateCompanionBuilder = SyncLogCompanion Function({
  Value<int> id,
  Value<DateTime> at,
  Value<String> outcome,
  Value<int> sent,
  Value<int> accepted,
  Value<int> conflicts,
  Value<int> rejected,
  Value<String?> detail,
});

class $$SyncLogTableFilterComposer
    extends Composer<_$AppDatabase, $SyncLogTable> {
  $$SyncLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sent => $composableBuilder(
      column: $table.sent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accepted => $composableBuilder(
      column: $table.accepted, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get conflicts => $composableBuilder(
      column: $table.conflicts, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rejected => $composableBuilder(
      column: $table.rejected, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detail => $composableBuilder(
      column: $table.detail, builder: (column) => ColumnFilters(column));
}

class $$SyncLogTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncLogTable> {
  $$SyncLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get at => $composableBuilder(
      column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outcome => $composableBuilder(
      column: $table.outcome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sent => $composableBuilder(
      column: $table.sent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accepted => $composableBuilder(
      column: $table.accepted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get conflicts => $composableBuilder(
      column: $table.conflicts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rejected => $composableBuilder(
      column: $table.rejected, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detail => $composableBuilder(
      column: $table.detail, builder: (column) => ColumnOrderings(column));
}

class $$SyncLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncLogTable> {
  $$SyncLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get sent =>
      $composableBuilder(column: $table.sent, builder: (column) => column);

  GeneratedColumn<int> get accepted =>
      $composableBuilder(column: $table.accepted, builder: (column) => column);

  GeneratedColumn<int> get conflicts =>
      $composableBuilder(column: $table.conflicts, builder: (column) => column);

  GeneratedColumn<int> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$SyncLogTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncLogTable,
    SyncLogData,
    $$SyncLogTableFilterComposer,
    $$SyncLogTableOrderingComposer,
    $$SyncLogTableAnnotationComposer,
    $$SyncLogTableCreateCompanionBuilder,
    $$SyncLogTableUpdateCompanionBuilder,
    (SyncLogData, BaseReferences<_$AppDatabase, $SyncLogTable, SyncLogData>),
    SyncLogData,
    PrefetchHooks Function()> {
  $$SyncLogTableTableManager(_$AppDatabase db, $SyncLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> at = const Value.absent(),
            Value<String> outcome = const Value.absent(),
            Value<int> sent = const Value.absent(),
            Value<int> accepted = const Value.absent(),
            Value<int> conflicts = const Value.absent(),
            Value<int> rejected = const Value.absent(),
            Value<String?> detail = const Value.absent(),
          }) =>
              SyncLogCompanion(
            id: id,
            at: at,
            outcome: outcome,
            sent: sent,
            accepted: accepted,
            conflicts: conflicts,
            rejected: rejected,
            detail: detail,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime at,
            required String outcome,
            Value<int> sent = const Value.absent(),
            Value<int> accepted = const Value.absent(),
            Value<int> conflicts = const Value.absent(),
            Value<int> rejected = const Value.absent(),
            Value<String?> detail = const Value.absent(),
          }) =>
              SyncLogCompanion.insert(
            id: id,
            at: at,
            outcome: outcome,
            sent: sent,
            accepted: accepted,
            conflicts: conflicts,
            rejected: rejected,
            detail: detail,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncLogTable, SyncLogData>(table),
                    BaseReferences<_$AppDatabase, $SyncLogTable, SyncLogData>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncLogTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncLogTable,
    SyncLogData,
    $$SyncLogTableFilterComposer,
    $$SyncLogTableOrderingComposer,
    $$SyncLogTableAnnotationComposer,
    $$SyncLogTableCreateCompanionBuilder,
    $$SyncLogTableUpdateCompanionBuilder,
    (SyncLogData, BaseReferences<_$AppDatabase, $SyncLogTable, SyncLogData>),
    SyncLogData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CatalogProductsTableTableManager get catalogProducts =>
      $$CatalogProductsTableTableManager(_db, _db.catalogProducts);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleLinesTableTableManager get saleLines =>
      $$SaleLinesTableTableManager(_db, _db.saleLines);
  $$SaleVoidsTableTableManager get saleVoids =>
      $$SaleVoidsTableTableManager(_db, _db.saleVoids);
  $$DeliveriesTableTableManager get deliveries =>
      $$DeliveriesTableTableManager(_db, _db.deliveries);
  $$DeliveryLinesTableTableManager get deliveryLines =>
      $$DeliveryLinesTableTableManager(_db, _db.deliveryLines);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db, _db.receipts);
  $$ReceiptLinesTableTableManager get receiptLines =>
      $$ReceiptLinesTableTableManager(_db, _db.receiptLines);
  $$DamageReportsTableTableManager get damageReports =>
      $$DamageReportsTableTableManager(_db, _db.damageReports);
  $$ClosingCountsTableTableManager get closingCounts =>
      $$ClosingCountsTableTableManager(_db, _db.closingCounts);
  $$ClosingCountLinesTableTableManager get closingCountLines =>
      $$ClosingCountLinesTableTableManager(_db, _db.closingCountLines);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncLogTableTableManager get syncLog =>
      $$SyncLogTableTableManager(_db, _db.syncLog);
}
