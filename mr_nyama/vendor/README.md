# Mr. Nyama vendor app

Android app for Mr. Nyama street vendors. Rules: [`../AGENTS.md`](../AGENTS.md). Plan and audits: [`docs/mr_nyama/implementation/`](../../docs/mr_nyama/implementation/).

Status: design system, navigation, sign-in, dashboard, sales, history, receiving, damage, Funga Siku and offline sync (Phases 2.2–2.9), connected to the Mr. Nyama API (`mr_nyama/backend`) through `HttpVendorRepository` (Phase 3.12). The API address is a build-time value with no default: without `MN_API_URL` every server call fails closed ("not available"). Release builds accept only an `https://` address. Local database: drift (`lib/core/data/`; run `dart run build_runner build` after schema changes).

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=MN_API_URL=http://192.168.x.x:8765   # against a local API (debug only)
flutter run                                   # no API: sign-in reports "not available"
flutter run --dart-define=MN_SHOWCASE=true    # development component showcase
flutter run --dart-define=MN_PREVIEW=true     # sign-in and dashboard with sample data
```

For a signed release, run the VS Code task **Build and verify signed Mr. Nyama release APK** or run `bash android/build_signed_release.sh` from this directory in a local terminal. It prompts for the keystore and key passwords with terminal echo disabled, writes them to the Git-ignored `android/key.properties` file with owner-only permissions, builds an obfuscated APK with R8 code/resource shrinking, and verifies its identity and signature. Dart symbols and the R8 mapping are stored outside the repository in a version- and APK-hash-specific directory under `/home/navy/android-signing/mr-nyama/symbols/`, with owner-only permissions. Preserve that directory and include it in the owner's encrypted backup process; without the exact symbols and mapping, obfuscated crash reports cannot be symbolicated. The keystore remains outside this repository. A release build fails rather than falling back to the debug key.

The release application ID is `com.transmark.mrnyama`, approved for the Mr. Nyama product package. This identity is different from the earlier `com.transmark.mrnyama.vendor` package, so Android treats the new package as a separate app rather than an update. The first release-signed APK also cannot update an existing debug-signed installation. Do not remove the earlier app or distribute/install the new one until every affected phone has synced its records.

Preview phones (digits after +255): 712 345 678 (PIN 2580), 700 000 001 (activation code 123456), 700 000 002 (suspended).

The showcase and preview (`lib/dev/`) use isolated sample data, marked "SAMPULI". They exist only in debug and profile builds started with their flag; release builds compile them out.

## Layout

- `lib/core/theme/` — design tokens (`tokens.dart`), motion system (`motion.dart`), generated icons (`icon_data.dart`), Material theme. Values are copied from the approved design export and checked against it by `test/theme_test.dart`.
- `lib/core/routing/` — GoRouter: `StatefulShellRoute` for Nyumbani | Mauzo | Bidhaa (state kept per tab), secondary routes above it.
- `lib/core/l10n/strings.dart` — all copy, Swahili first. `test/l10n_guard_test.dart` blocks literals in screens.
- `lib/shared/widgets/` — design-system components.
- `lib/features/` — screens by destination.
- `lib/dev/` — showcase and sample data only.

## Notes

- Manrope is a variable font (weight 200–800, default 200). Text styles set the `wght` axis; use `MNText.withWeight` to change a weight.
- The official logo is not in the repository: see `assets/brand/README.md`. `MNLogo` renders an empty space until it is added.
- Application ID `com.transmark.mrnyama` is the approved package identity.
