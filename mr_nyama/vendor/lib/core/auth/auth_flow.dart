import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Values carried between sign-in screens. Held in memory only and cleared
/// as soon as the flow ends; the first PIN entry lives here only between
/// "Chagua PIN" and "Rudia PIN".
class AuthFlow {
  /// Staff code for a PIN reset rather than first activation.
  final bool reset;
  final String? setupToken;
  final String? newPin;

  /// The confirmation did not match; "Chagua PIN" explains why it is back.
  final bool mismatch;

  /// "Nikumbuke" was ticked on the phone form.
  final bool remember;
  const AuthFlow(
      {this.reset = false,
      this.setupToken,
      this.newPin,
      this.mismatch = false,
      this.remember = false});

  AuthFlow copyWith({String? setupToken, String? newPin, bool? mismatch}) =>
      AuthFlow(
          reset: reset,
          setupToken: setupToken ?? this.setupToken,
          newPin: newPin ?? this.newPin,
          mismatch: mismatch ?? this.mismatch,
          remember: remember);

  /// Forgets the first PIN entry.
  AuthFlow withoutPin({bool mismatch = false}) => AuthFlow(
      reset: reset,
      setupToken: setupToken,
      mismatch: mismatch,
      remember: remember);
}

final authFlowProvider = StateProvider<AuthFlow>((ref) => const AuthFlow());

/// Tanzanian mobile numbers: 9 digits after +255, starting with 6 or 7.
/// Accepts "0712 345 678", "712345678" or "+255 712 345 678".
String? normaliseTanzanianPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('255')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (!RegExp(r'^[67]\d{8}$').hasMatch(digits)) return null;
  return '+255$digits';
}

/// "+255712345678" → "+255 712 345 678".
String displayPhone(String e164) {
  final local = e164.replaceFirst('+255', '');
  if (local.length != 9) return e164;
  return '+255 ${local.substring(0, 3)} ${local.substring(3, 6)} '
      '${local.substring(6)}';
}

/// Rejects PINs that are trivially guessed: one digit repeated, or a
/// straight run up or down.
bool isWeakPin(String pin) {
  if (pin.split('').toSet().length == 1) return true;
  const up = '01234567890', down = '09876543210';
  return up.contains(pin) || down.contains(pin);
}
