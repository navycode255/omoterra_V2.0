// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'domain.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AppUser _$AppUserFromJson(Map<String, dynamic> json) {
  return _AppUser.fromJson(json);
}

/// @nodoc
mixin _$AppUser {
  String get id => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get region => throw _privateConstructorUsedError;
  String get language => throw _privateConstructorUsedError;
  List<String> get roles => throw _privateConstructorUsedError;
  @JsonKey(name: 'buyer_type')
  String? get buyerType => throw _privateConstructorUsedError;

  /// Serializes this AppUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call(
      {String id,
      String phone,
      String name,
      String region,
      String language,
      List<String> roles,
      @JsonKey(name: 'buyer_type') String? buyerType});
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phone = null,
    Object? name = null,
    Object? region = null,
    Object? language = null,
    Object? roles = null,
    Object? buyerType = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      region: null == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String,
      language: null == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String,
      roles: null == roles
          ? _value.roles
          : roles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      buyerType: freezed == buyerType
          ? _value.buyerType
          : buyerType // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUserImplCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$$AppUserImplCopyWith(
          _$AppUserImpl value, $Res Function(_$AppUserImpl) then) =
      __$$AppUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String phone,
      String name,
      String region,
      String language,
      List<String> roles,
      @JsonKey(name: 'buyer_type') String? buyerType});
}

/// @nodoc
class __$$AppUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$AppUserImpl>
    implements _$$AppUserImplCopyWith<$Res> {
  __$$AppUserImplCopyWithImpl(
      _$AppUserImpl _value, $Res Function(_$AppUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phone = null,
    Object? name = null,
    Object? region = null,
    Object? language = null,
    Object? roles = null,
    Object? buyerType = freezed,
  }) {
    return _then(_$AppUserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      region: null == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String,
      language: null == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String,
      roles: null == roles
          ? _value._roles
          : roles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      buyerType: freezed == buyerType
          ? _value.buyerType
          : buyerType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppUserImpl implements _AppUser {
  const _$AppUserImpl(
      {required this.id,
      required this.phone,
      this.name = '',
      this.region = '',
      this.language = 'en',
      final List<String> roles = const [],
      @JsonKey(name: 'buyer_type') this.buyerType})
      : _roles = roles;

  factory _$AppUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUserImplFromJson(json);

  @override
  final String id;
  @override
  final String phone;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String region;
  @override
  @JsonKey()
  final String language;
  final List<String> _roles;
  @override
  @JsonKey()
  List<String> get roles {
    if (_roles is EqualUnmodifiableListView) return _roles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_roles);
  }

  @override
  @JsonKey(name: 'buyer_type')
  final String? buyerType;

  @override
  String toString() {
    return 'AppUser(id: $id, phone: $phone, name: $name, region: $region, language: $language, roles: $roles, buyerType: $buyerType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.language, language) ||
                other.language == language) &&
            const DeepCollectionEquality().equals(other._roles, _roles) &&
            (identical(other.buyerType, buyerType) ||
                other.buyerType == buyerType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, phone, name, region,
      language, const DeepCollectionEquality().hash(_roles), buyerType);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      __$$AppUserImplCopyWithImpl<_$AppUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUserImplToJson(
      this,
    );
  }
}

abstract class _AppUser implements AppUser {
  const factory _AppUser(
      {required final String id,
      required final String phone,
      final String name,
      final String region,
      final String language,
      final List<String> roles,
      @JsonKey(name: 'buyer_type') final String? buyerType}) = _$AppUserImpl;

  factory _AppUser.fromJson(Map<String, dynamic> json) = _$AppUserImpl.fromJson;

  @override
  String get id;
  @override
  String get phone;
  @override
  String get name;
  @override
  String get region;
  @override
  String get language;
  @override
  List<String> get roles;
  @override
  @JsonKey(name: 'buyer_type')
  String? get buyerType;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SupplyListing _$SupplyListingFromJson(Map<String, dynamic> json) {
  return _SupplyListing.fromJson(json);
}

/// @nodoc
mixin _$SupplyListing {
  String get id => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(name: 'unit_type')
  String get unitType => throw _privateConstructorUsedError;
  String get region => throw _privateConstructorUsedError;
  List<String> get photos => throw _privateConstructorUsedError;
  Map<String, dynamic> get specs => throw _privateConstructorUsedError;
  @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
  String get price => throw _privateConstructorUsedError;
  @JsonKey(name: 'quantity_available', fromJson: decimalString)
  String get available => throw _privateConstructorUsedError;
  Map<String, dynamic>? get supplier => throw _privateConstructorUsedError;

  /// Serializes this SupplyListing to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SupplyListing
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupplyListingCopyWith<SupplyListing> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplyListingCopyWith<$Res> {
  factory $SupplyListingCopyWith(
          SupplyListing value, $Res Function(SupplyListing) then) =
      _$SupplyListingCopyWithImpl<$Res, SupplyListing>;
  @useResult
  $Res call(
      {String id,
      String category,
      @JsonKey(name: 'unit_type') String unitType,
      String region,
      List<String> photos,
      Map<String, dynamic> specs,
      @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
      String price,
      @JsonKey(name: 'quantity_available', fromJson: decimalString)
      String available,
      Map<String, dynamic>? supplier});
}

/// @nodoc
class _$SupplyListingCopyWithImpl<$Res, $Val extends SupplyListing>
    implements $SupplyListingCopyWith<$Res> {
  _$SupplyListingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupplyListing
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? category = null,
    Object? unitType = null,
    Object? region = null,
    Object? photos = null,
    Object? specs = null,
    Object? price = null,
    Object? available = null,
    Object? supplier = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      unitType: null == unitType
          ? _value.unitType
          : unitType // ignore: cast_nullable_to_non_nullable
              as String,
      region: null == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String,
      photos: null == photos
          ? _value.photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<String>,
      specs: null == specs
          ? _value.specs
          : specs // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as String,
      available: null == available
          ? _value.available
          : available // ignore: cast_nullable_to_non_nullable
              as String,
      supplier: freezed == supplier
          ? _value.supplier
          : supplier // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SupplyListingImplCopyWith<$Res>
    implements $SupplyListingCopyWith<$Res> {
  factory _$$SupplyListingImplCopyWith(
          _$SupplyListingImpl value, $Res Function(_$SupplyListingImpl) then) =
      __$$SupplyListingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String category,
      @JsonKey(name: 'unit_type') String unitType,
      String region,
      List<String> photos,
      Map<String, dynamic> specs,
      @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
      String price,
      @JsonKey(name: 'quantity_available', fromJson: decimalString)
      String available,
      Map<String, dynamic>? supplier});
}

/// @nodoc
class __$$SupplyListingImplCopyWithImpl<$Res>
    extends _$SupplyListingCopyWithImpl<$Res, _$SupplyListingImpl>
    implements _$$SupplyListingImplCopyWith<$Res> {
  __$$SupplyListingImplCopyWithImpl(
      _$SupplyListingImpl _value, $Res Function(_$SupplyListingImpl) _then)
      : super(_value, _then);

  /// Create a copy of SupplyListing
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? category = null,
    Object? unitType = null,
    Object? region = null,
    Object? photos = null,
    Object? specs = null,
    Object? price = null,
    Object? available = null,
    Object? supplier = freezed,
  }) {
    return _then(_$SupplyListingImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      unitType: null == unitType
          ? _value.unitType
          : unitType // ignore: cast_nullable_to_non_nullable
              as String,
      region: null == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String,
      photos: null == photos
          ? _value._photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<String>,
      specs: null == specs
          ? _value._specs
          : specs // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as String,
      available: null == available
          ? _value.available
          : available // ignore: cast_nullable_to_non_nullable
              as String,
      supplier: freezed == supplier
          ? _value._supplier
          : supplier // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SupplyListingImpl implements _SupplyListing {
  const _$SupplyListingImpl(
      {required this.id,
      required this.category,
      @JsonKey(name: 'unit_type') required this.unitType,
      required this.region,
      final List<String> photos = const [],
      final Map<String, dynamic> specs = const {},
      @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
      required this.price,
      @JsonKey(name: 'quantity_available', fromJson: decimalString)
      required this.available,
      final Map<String, dynamic>? supplier})
      : _photos = photos,
        _specs = specs,
        _supplier = supplier;

  factory _$SupplyListingImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupplyListingImplFromJson(json);

  @override
  final String id;
  @override
  final String category;
  @override
  @JsonKey(name: 'unit_type')
  final String unitType;
  @override
  final String region;
  final List<String> _photos;
  @override
  @JsonKey()
  List<String> get photos {
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_photos);
  }

  final Map<String, dynamic> _specs;
  @override
  @JsonKey()
  Map<String, dynamic> get specs {
    if (_specs is EqualUnmodifiableMapView) return _specs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_specs);
  }

  @override
  @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
  final String price;
  @override
  @JsonKey(name: 'quantity_available', fromJson: decimalString)
  final String available;
  final Map<String, dynamic>? _supplier;
  @override
  Map<String, dynamic>? get supplier {
    final value = _supplier;
    if (value == null) return null;
    if (_supplier is EqualUnmodifiableMapView) return _supplier;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'SupplyListing(id: $id, category: $category, unitType: $unitType, region: $region, photos: $photos, specs: $specs, price: $price, available: $available, supplier: $supplier)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplyListingImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.unitType, unitType) ||
                other.unitType == unitType) &&
            (identical(other.region, region) || other.region == region) &&
            const DeepCollectionEquality().equals(other._photos, _photos) &&
            const DeepCollectionEquality().equals(other._specs, _specs) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.available, available) ||
                other.available == available) &&
            const DeepCollectionEquality().equals(other._supplier, _supplier));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      category,
      unitType,
      region,
      const DeepCollectionEquality().hash(_photos),
      const DeepCollectionEquality().hash(_specs),
      price,
      available,
      const DeepCollectionEquality().hash(_supplier));

  /// Create a copy of SupplyListing
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplyListingImplCopyWith<_$SupplyListingImpl> get copyWith =>
      __$$SupplyListingImplCopyWithImpl<_$SupplyListingImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SupplyListingImplToJson(
      this,
    );
  }
}

abstract class _SupplyListing implements SupplyListing {
  const factory _SupplyListing(
      {required final String id,
      required final String category,
      @JsonKey(name: 'unit_type') required final String unitType,
      required final String region,
      final List<String> photos,
      final Map<String, dynamic> specs,
      @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
      required final String price,
      @JsonKey(name: 'quantity_available', fromJson: decimalString)
      required final String available,
      final Map<String, dynamic>? supplier}) = _$SupplyListingImpl;

  factory _SupplyListing.fromJson(Map<String, dynamic> json) =
      _$SupplyListingImpl.fromJson;

  @override
  String get id;
  @override
  String get category;
  @override
  @JsonKey(name: 'unit_type')
  String get unitType;
  @override
  String get region;
  @override
  List<String> get photos;
  @override
  Map<String, dynamic> get specs;
  @override
  @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
  String get price;
  @override
  @JsonKey(name: 'quantity_available', fromJson: decimalString)
  String get available;
  @override
  Map<String, dynamic>? get supplier;

  /// Create a copy of SupplyListing
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplyListingImplCopyWith<_$SupplyListingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Reservation _$ReservationFromJson(Map<String, dynamic> json) {
  return _Reservation.fromJson(json);
}

/// @nodoc
mixin _$Reservation {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'listing_id')
  String get listingId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: decimalString)
  String get quantity => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_id')
  String? get orderId => throw _privateConstructorUsedError;

  /// Serializes this Reservation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Reservation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReservationCopyWith<Reservation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReservationCopyWith<$Res> {
  factory $ReservationCopyWith(
          Reservation value, $Res Function(Reservation) then) =
      _$ReservationCopyWithImpl<$Res, Reservation>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'listing_id') String listingId,
      @JsonKey(fromJson: decimalString) String quantity,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      String status,
      @JsonKey(name: 'order_id') String? orderId});
}

/// @nodoc
class _$ReservationCopyWithImpl<$Res, $Val extends Reservation>
    implements $ReservationCopyWith<$Res> {
  _$ReservationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Reservation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? listingId = null,
    Object? quantity = null,
    Object? expiresAt = null,
    Object? status = null,
    Object? orderId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      listingId: null == listingId
          ? _value.listingId
          : listingId // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: freezed == orderId
          ? _value.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReservationImplCopyWith<$Res>
    implements $ReservationCopyWith<$Res> {
  factory _$$ReservationImplCopyWith(
          _$ReservationImpl value, $Res Function(_$ReservationImpl) then) =
      __$$ReservationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'listing_id') String listingId,
      @JsonKey(fromJson: decimalString) String quantity,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      String status,
      @JsonKey(name: 'order_id') String? orderId});
}

/// @nodoc
class __$$ReservationImplCopyWithImpl<$Res>
    extends _$ReservationCopyWithImpl<$Res, _$ReservationImpl>
    implements _$$ReservationImplCopyWith<$Res> {
  __$$ReservationImplCopyWithImpl(
      _$ReservationImpl _value, $Res Function(_$ReservationImpl) _then)
      : super(_value, _then);

  /// Create a copy of Reservation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? listingId = null,
    Object? quantity = null,
    Object? expiresAt = null,
    Object? status = null,
    Object? orderId = freezed,
  }) {
    return _then(_$ReservationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      listingId: null == listingId
          ? _value.listingId
          : listingId // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: freezed == orderId
          ? _value.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReservationImpl implements _Reservation {
  const _$ReservationImpl(
      {required this.id,
      @JsonKey(name: 'listing_id') required this.listingId,
      @JsonKey(fromJson: decimalString) required this.quantity,
      @JsonKey(name: 'expires_at') required this.expiresAt,
      required this.status,
      @JsonKey(name: 'order_id') this.orderId});

  factory _$ReservationImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReservationImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'listing_id')
  final String listingId;
  @override
  @JsonKey(fromJson: decimalString)
  final String quantity;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @override
  final String status;
  @override
  @JsonKey(name: 'order_id')
  final String? orderId;

  @override
  String toString() {
    return 'Reservation(id: $id, listingId: $listingId, quantity: $quantity, expiresAt: $expiresAt, status: $status, orderId: $orderId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReservationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.listingId, listingId) ||
                other.listingId == listingId) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.orderId, orderId) || other.orderId == orderId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, listingId, quantity, expiresAt, status, orderId);

  /// Create a copy of Reservation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReservationImplCopyWith<_$ReservationImpl> get copyWith =>
      __$$ReservationImplCopyWithImpl<_$ReservationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReservationImplToJson(
      this,
    );
  }
}

abstract class _Reservation implements Reservation {
  const factory _Reservation(
      {required final String id,
      @JsonKey(name: 'listing_id') required final String listingId,
      @JsonKey(fromJson: decimalString) required final String quantity,
      @JsonKey(name: 'expires_at') required final DateTime expiresAt,
      required final String status,
      @JsonKey(name: 'order_id') final String? orderId}) = _$ReservationImpl;

  factory _Reservation.fromJson(Map<String, dynamic> json) =
      _$ReservationImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'listing_id')
  String get listingId;
  @override
  @JsonKey(fromJson: decimalString)
  String get quantity;
  @override
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt;
  @override
  String get status;
  @override
  @JsonKey(name: 'order_id')
  String? get orderId;

  /// Create a copy of Reservation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReservationImplCopyWith<_$ReservationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BuyerOrder _$BuyerOrderFromJson(Map<String, dynamic> json) {
  return _BuyerOrder.fromJson(json);
}

/// @nodoc
mixin _$BuyerOrder {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_status')
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_status')
  String get paymentStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_method')
  String get paymentMethod => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_amount', fromJson: decimalString)
  String get total => throw _privateConstructorUsedError;
  @JsonKey(name: 'preferred_delivery_date')
  String get deliveryDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_address')
  Map<String, dynamic> get address => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get items => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get activity => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;

  /// Serializes this BuyerOrder to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BuyerOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BuyerOrderCopyWith<BuyerOrder> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BuyerOrderCopyWith<$Res> {
  factory $BuyerOrderCopyWith(
          BuyerOrder value, $Res Function(BuyerOrder) then) =
      _$BuyerOrderCopyWithImpl<$Res, BuyerOrder>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'customer_status') String status,
      @JsonKey(name: 'payment_status') String paymentStatus,
      @JsonKey(name: 'payment_method') String paymentMethod,
      @JsonKey(name: 'total_amount', fromJson: decimalString) String total,
      @JsonKey(name: 'preferred_delivery_date') String deliveryDate,
      @JsonKey(name: 'delivery_address') Map<String, dynamic> address,
      List<Map<String, dynamic>> items,
      List<Map<String, dynamic>> activity,
      String? message});
}

/// @nodoc
class _$BuyerOrderCopyWithImpl<$Res, $Val extends BuyerOrder>
    implements $BuyerOrderCopyWith<$Res> {
  _$BuyerOrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BuyerOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? paymentStatus = null,
    Object? paymentMethod = null,
    Object? total = null,
    Object? deliveryDate = null,
    Object? address = null,
    Object? items = null,
    Object? activity = null,
    Object? message = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      paymentStatus: null == paymentStatus
          ? _value.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as String,
      deliveryDate: null == deliveryDate
          ? _value.deliveryDate
          : deliveryDate // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      activity: null == activity
          ? _value.activity
          : activity // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BuyerOrderImplCopyWith<$Res>
    implements $BuyerOrderCopyWith<$Res> {
  factory _$$BuyerOrderImplCopyWith(
          _$BuyerOrderImpl value, $Res Function(_$BuyerOrderImpl) then) =
      __$$BuyerOrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'customer_status') String status,
      @JsonKey(name: 'payment_status') String paymentStatus,
      @JsonKey(name: 'payment_method') String paymentMethod,
      @JsonKey(name: 'total_amount', fromJson: decimalString) String total,
      @JsonKey(name: 'preferred_delivery_date') String deliveryDate,
      @JsonKey(name: 'delivery_address') Map<String, dynamic> address,
      List<Map<String, dynamic>> items,
      List<Map<String, dynamic>> activity,
      String? message});
}

/// @nodoc
class __$$BuyerOrderImplCopyWithImpl<$Res>
    extends _$BuyerOrderCopyWithImpl<$Res, _$BuyerOrderImpl>
    implements _$$BuyerOrderImplCopyWith<$Res> {
  __$$BuyerOrderImplCopyWithImpl(
      _$BuyerOrderImpl _value, $Res Function(_$BuyerOrderImpl) _then)
      : super(_value, _then);

  /// Create a copy of BuyerOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? paymentStatus = null,
    Object? paymentMethod = null,
    Object? total = null,
    Object? deliveryDate = null,
    Object? address = null,
    Object? items = null,
    Object? activity = null,
    Object? message = freezed,
  }) {
    return _then(_$BuyerOrderImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      paymentStatus: null == paymentStatus
          ? _value.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as String,
      deliveryDate: null == deliveryDate
          ? _value.deliveryDate
          : deliveryDate // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value._address
          : address // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      activity: null == activity
          ? _value._activity
          : activity // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BuyerOrderImpl implements _BuyerOrder {
  const _$BuyerOrderImpl(
      {required this.id,
      @JsonKey(name: 'customer_status') required this.status,
      @JsonKey(name: 'payment_status') required this.paymentStatus,
      @JsonKey(name: 'payment_method') required this.paymentMethod,
      @JsonKey(name: 'total_amount', fromJson: decimalString)
      required this.total,
      @JsonKey(name: 'preferred_delivery_date') required this.deliveryDate,
      @JsonKey(name: 'delivery_address')
      required final Map<String, dynamic> address,
      final List<Map<String, dynamic>> items = const [],
      final List<Map<String, dynamic>> activity = const [],
      this.message})
      : _address = address,
        _items = items,
        _activity = activity;

  factory _$BuyerOrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$BuyerOrderImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'customer_status')
  final String status;
  @override
  @JsonKey(name: 'payment_status')
  final String paymentStatus;
  @override
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @override
  @JsonKey(name: 'total_amount', fromJson: decimalString)
  final String total;
  @override
  @JsonKey(name: 'preferred_delivery_date')
  final String deliveryDate;
  final Map<String, dynamic> _address;
  @override
  @JsonKey(name: 'delivery_address')
  Map<String, dynamic> get address {
    if (_address is EqualUnmodifiableMapView) return _address;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_address);
  }

  final List<Map<String, dynamic>> _items;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  final List<Map<String, dynamic>> _activity;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get activity {
    if (_activity is EqualUnmodifiableListView) return _activity;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activity);
  }

  @override
  final String? message;

  @override
  String toString() {
    return 'BuyerOrder(id: $id, status: $status, paymentStatus: $paymentStatus, paymentMethod: $paymentMethod, total: $total, deliveryDate: $deliveryDate, address: $address, items: $items, activity: $activity, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BuyerOrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.deliveryDate, deliveryDate) ||
                other.deliveryDate == deliveryDate) &&
            const DeepCollectionEquality().equals(other._address, _address) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            const DeepCollectionEquality().equals(other._activity, _activity) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      status,
      paymentStatus,
      paymentMethod,
      total,
      deliveryDate,
      const DeepCollectionEquality().hash(_address),
      const DeepCollectionEquality().hash(_items),
      const DeepCollectionEquality().hash(_activity),
      message);

  /// Create a copy of BuyerOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BuyerOrderImplCopyWith<_$BuyerOrderImpl> get copyWith =>
      __$$BuyerOrderImplCopyWithImpl<_$BuyerOrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BuyerOrderImplToJson(
      this,
    );
  }
}

abstract class _BuyerOrder implements BuyerOrder {
  const factory _BuyerOrder(
      {required final String id,
      @JsonKey(name: 'customer_status') required final String status,
      @JsonKey(name: 'payment_status') required final String paymentStatus,
      @JsonKey(name: 'payment_method') required final String paymentMethod,
      @JsonKey(name: 'total_amount', fromJson: decimalString)
      required final String total,
      @JsonKey(name: 'preferred_delivery_date')
      required final String deliveryDate,
      @JsonKey(name: 'delivery_address')
      required final Map<String, dynamic> address,
      final List<Map<String, dynamic>> items,
      final List<Map<String, dynamic>> activity,
      final String? message}) = _$BuyerOrderImpl;

  factory _BuyerOrder.fromJson(Map<String, dynamic> json) =
      _$BuyerOrderImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'customer_status')
  String get status;
  @override
  @JsonKey(name: 'payment_status')
  String get paymentStatus;
  @override
  @JsonKey(name: 'payment_method')
  String get paymentMethod;
  @override
  @JsonKey(name: 'total_amount', fromJson: decimalString)
  String get total;
  @override
  @JsonKey(name: 'preferred_delivery_date')
  String get deliveryDate;
  @override
  @JsonKey(name: 'delivery_address')
  Map<String, dynamic> get address;
  @override
  List<Map<String, dynamic>> get items;
  @override
  List<Map<String, dynamic>> get activity;
  @override
  String? get message;

  /// Create a copy of BuyerOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BuyerOrderImplCopyWith<_$BuyerOrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
