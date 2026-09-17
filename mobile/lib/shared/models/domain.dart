// Freezed forwards constructor annotations to generated fields.
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
part 'domain.freezed.dart';
part 'domain.g.dart';

String decimalString(Object? value) => value.toString();

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String phone,
    @Default('') String name,
    @Default('') String region,
    @Default('en') String language,
    @Default([]) List<String> roles,
    @JsonKey(name: 'buyer_type') String? buyerType,
  }) = _AppUser;
  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}

@freezed
class SupplyListing with _$SupplyListing {
  const factory SupplyListing({
    required String id,
    required String category,
    @JsonKey(name: 'unit_type') required String unitType,
    required String region,
    @Default([]) List<String> photos,
    @Default({}) Map<String, dynamic> specs,
    @JsonKey(name: 'buyer_price_per_unit', fromJson: decimalString)
    required String price,
    @JsonKey(name: 'quantity_available', fromJson: decimalString)
    required String available,
    Map<String, dynamic>? supplier,
  }) = _SupplyListing;
  factory SupplyListing.fromJson(Map<String, dynamic> json) =>
      _$SupplyListingFromJson(json);
}

@freezed
class Reservation with _$Reservation {
  const factory Reservation({
    required String id,
    @JsonKey(name: 'listing_id') required String listingId,
    @JsonKey(fromJson: decimalString) required String quantity,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    required String status,
    @JsonKey(name: 'order_id') String? orderId,
  }) = _Reservation;
  factory Reservation.fromJson(Map<String, dynamic> json) =>
      _$ReservationFromJson(json);
}

@freezed
class BuyerOrder with _$BuyerOrder {
  const factory BuyerOrder({
    required String id,
    @JsonKey(name: 'customer_status') required String status,
    @JsonKey(name: 'payment_status') required String paymentStatus,
    @JsonKey(name: 'payment_method') required String paymentMethod,
    @JsonKey(name: 'total_amount', fromJson: decimalString)
    required String total,
    @JsonKey(name: 'preferred_delivery_date') required String deliveryDate,
    @JsonKey(name: 'delivery_address') required Map<String, dynamic> address,
    @Default([]) List<Map<String, dynamic>> items,
    @Default([]) List<Map<String, dynamic>> activity,
    String? message,
  }) = _BuyerOrder;
  factory BuyerOrder.fromJson(Map<String, dynamic> json) =>
      _$BuyerOrderFromJson(json);
}
