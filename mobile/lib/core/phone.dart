/// A Tanzanian mobile number as the API expects it (+2557XXXXXXXX or
/// +2556XXXXXXXX), from however it was typed: 0712 345 678, 712345678,
/// 255712345678 or +255 712 345 678. Null when it isn't one.
String? tanzanianMobile(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('255')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return RegExp(r'^[67]\d{8}$').hasMatch(digits) ? '+255$digits' : null;
}
