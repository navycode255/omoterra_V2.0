// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'domain.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      roles:
          (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      buyerType: json['buyer_type'] as String?,
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'name': instance.name,
      'region': instance.region,
      'language': instance.language,
      'roles': instance.roles,
      'buyer_type': instance.buyerType,
    };

_$SupplyListingImpl _$$SupplyListingImplFromJson(Map<String, dynamic> json) =>
    _$SupplyListingImpl(
      id: json['id'] as String,
      category: json['category'] as String,
      unitType: json['unit_type'] as String,
      region: json['region'] as String,
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      video: json['video'] as String?,
      specs: json['specs'] as Map<String, dynamic>? ?? const {},
      price: decimalString(json['buyer_price_per_unit']),
      available: decimalString(json['quantity_available']),
      supplier: json['supplier'] as Map<String, dynamic>?,
      supplierRating: json['supplier_rating'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$SupplyListingImplToJson(_$SupplyListingImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'unit_type': instance.unitType,
      'region': instance.region,
      'photos': instance.photos,
      'video': instance.video,
      'specs': instance.specs,
      'buyer_price_per_unit': instance.price,
      'quantity_available': instance.available,
      'supplier': instance.supplier,
      'supplier_rating': instance.supplierRating,
    };

_$ReservationImpl _$$ReservationImplFromJson(Map<String, dynamic> json) =>
    _$ReservationImpl(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      quantity: decimalString(json['quantity']),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      status: json['status'] as String,
      orderId: json['order_id'] as String?,
    );

Map<String, dynamic> _$$ReservationImplToJson(_$ReservationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'listing_id': instance.listingId,
      'quantity': instance.quantity,
      'expires_at': instance.expiresAt.toIso8601String(),
      'status': instance.status,
      'order_id': instance.orderId,
    };

_$BuyerOrderImpl _$$BuyerOrderImplFromJson(Map<String, dynamic> json) =>
    _$BuyerOrderImpl(
      id: json['id'] as String,
      status: json['customer_status'] as String,
      paymentStatus: json['payment_status'] as String,
      paymentMethod: json['payment_method'] as String,
      total: decimalString(json['total_amount']),
      deliveryDate: json['preferred_delivery_date'] as String,
      address: json['delivery_address'] as Map<String, dynamic>,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      activity: (json['activity'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      message: json['message'] as String?,
      rating: json['rating'] as Map<String, dynamic>?,
      canRate: json['can_rate'] as bool? ?? false,
    );

Map<String, dynamic> _$$BuyerOrderImplToJson(_$BuyerOrderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customer_status': instance.status,
      'payment_status': instance.paymentStatus,
      'payment_method': instance.paymentMethod,
      'total_amount': instance.total,
      'preferred_delivery_date': instance.deliveryDate,
      'delivery_address': instance.address,
      'items': instance.items,
      'activity': instance.activity,
      'message': instance.message,
      'rating': instance.rating,
      'can_rate': instance.canRate,
    };
