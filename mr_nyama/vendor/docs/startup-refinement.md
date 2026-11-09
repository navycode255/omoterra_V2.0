# Black branded startup — 1 November 2026

Owner request: black native startup with the original grill artwork, followed by a black branded Flutter screen, then existing sign-in, unlock or role destination. The supplied screenshot is a layout reference; it is not shipped as an asset.

## Implementation

- `assets/brand/icon.png` is the unchanged, transparent official grill artwork. Android uses density-specific resized/padded copies, with the full square inside the Android 12 circular safe area. No background shape is added.
- `assets/brand/logo.png` is the unchanged full logo used in Flutter. Its existing lettering and tagline are preserved; no duplicate text is added.
- The pre-Android-12 launch drawables now have black backgrounds and centered artwork. API 31+ themes explicitly select the dedicated startup icon and black background, avoiding the launcher-icon fallback. Day/night variants agree. Launcher icons and manifest are unchanged.
- The existing Flutter splash is replaced in place: black, responsive full logo, 300 ms opacity fade, no photo or rise animation. Reduced motion shows the settled logo without animated progress.
- The indeterminate red indicator appears after 300 ms only while session restoration remains pending. That timer never blocks navigation. The previous 600 ms session floor and its test overrides are removed.
- The router waits for both vendor and office restoration before choosing the startup destination, then uses existing role/session redirects. No added authentication calls, token/PIN changes, or navigation timers. Ordinary navigation does not replay the splash.
- Splash system bars use black with light icons; the application supplies a light-screen default when the splash leaves. Existing screen-specific overlays retain priority.
- No shared branding or photo assets were deleted: other screens still use them. Required native resources remain.

## Files changed or added

Within `vendor/`:

- `lib/app/app.dart`
- `lib/core/auth/session.dart`
- `lib/core/routing/router.dart`
- `lib/core/theme/motion.dart`
- `lib/core/theme/tokens.dart`
- `lib/features/authentication/splash_screen.dart`
- `test/helpers.dart`
- `test/sync_test.dart`
- `test/splash_test.dart` (new)
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/src/main/res/values-v31/styles.xml` (new)
- `android/app/src/main/res/values-night-v31/styles.xml` (new)
- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/startup_icon.png` (five new resource copies)
- `docs/startup-refinement.md` (this report)

The owner-approved startup deviation is also recorded in `docs/mr_nyama/implementation/mr-nyama-implementation-plan.md` at the repository root.

## Validation

- Modified Dart formatted.
- Final `flutter analyze`: `No issues found! (ran in 24.8s)`.
- Splash widget tests: `00:04 +2: All tests passed!`, covering 320 × 568, genuine pending progress, completion, and reduced motion.
- Full `flutter test --concurrency=4`: `05:39 +1092 ~4 -4: Some tests failed.` Three failures are in `office_stock_production_test.dart`: receipt-mismatch return, later delivery, transit loss. The fourth is the shared theme-policy test. Startup's policy violations were then fixed; the policy recheck now reports only the untouched `lib/features/office/verification_screens.dart` (`fontWeight` outside tokens).
- Final splash/auth/biometrics/office run: `00:13 +58: All tests passed!`.
- Post-fix focused run including splash, auth, biometrics, office, and theme: 66 passed, one failed (the verification-screen policy violation above). No authentication or splash failures.
- Final `flutter build apk --debug`: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` (63.1 s).
- All eight Android resource XML files parse successfully; all five startup icon resources have transparent padding. APK compilation validates Android resource references.
- No Android device is connected (`adb devices` returns an empty list). Hardware cold/warm launch, actual system masking/transition, and real biometric prompts remain unverified. Android controls its native splash timing and masking; the Flutter fade is never guaranteed to finish before initialization completes.
- Gradle reports an existing future Kotlin-plugin compatibility warning for `file_picker`, `firebase_core`, and `workmanager_android`.
