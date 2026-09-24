/// Barrel file: the authentication feature used to be one 940+ line
/// screens.dart. It is now split one file per screen (plus number_pad.dart,
/// shared by two of them); this file re-exports all of it so nothing outside
/// the feature has to know about the split.
library;

export 'number_pad.dart';
export 'otp_screen.dart';
export 'phone_screen.dart';
export 'setup_screen.dart';
export 'splash_screen.dart';
export 'welcome_screen.dart';

export 'language_screen.dart';
