import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Design tokens of the approved Mr. Nyama design system
/// (`docs/mr_nyama/design/html/`, design-system CSS). Values are copied
/// exactly; change them only when the approved design changes.
///
/// Red, black and white carry the brand. Success, warning and error colours
/// are for status only, never decoration.
class MNColors {
  // Owner-approved black startup reference, 1 November 2026.
  static const startupBlack = Color(0xFF000000);

  // Brand.
  static const red = Color(0xFFE30613);
  static const redPressed = Color(0xFFB8050F);
  static const black = Color(0xFF0F0F0F); // app bar, active chip, stepper
  static const white = Color(0xFFFFFFFF);

  // Owner-approved screen references, 10 October 2026.
  static const dashboardTop = Color(0xFF283646);
  static const dashboardBottom = Color(0xFF17232D);
  static const cardBorder = Color(0xFFEBEDF1);
  static const iconSurface = Color(0xFFF0F1F4);
  static const roseSurface = Color(0xFFFDE8EA);
  static const cardShadow = Color(0x0C17232D);

  // Text.
  static const ink = Color(0xFF141414);
  static const ink2 = Color(0xFF555555);
  static const muted = Color(0xFF737373);
  static const onDarkMuted = Color(0xFFBDBDBD);

  // Surfaces.
  // Light canvas shared by the newly approved screen pattern.
  static const pageBackground = Color(0xFFF4F7FA);
  static const referenceMuted = Color(0xFF5E6377);
  static const referenceLine = Color(0xFFE2E6EF);
  static const referenceAvatar = Color(0xFFE2E4E8);
  static const referenceAlert = Color(0xFFC34D51);
  static const surface = Color(0xFFF4F4F4); // keys, chips, tiles, strips
  static const surfacePressed = Color(0xFFEAEAEA);
  static const disabled = Color(0xFFECECEC);
  static const disabledText = Color(0xFF9E9E9E);
  static const imageBackground = Color(0xFF1A1A1A);
  static const avatar = Color(0xFF2B2B2B);
  static const charcoal = Color(0xFF121010); // Funga Siku background
  static const scrim = Color(0x80000000);
  static const textPressed = Color(0xFFFDECEC);
  static const selection = Color(0x33E30613); // brand red, 20%

  // Tanzania flag, for the +255 phone prefix only.
  static const flagGreen = Color(0xFF1EB53A);
  static const flagYellow = Color(0xFFFCD116);
  static const flagBlack = Color(0xFF000000);
  static const flagBlue = Color(0xFF00A3DD);

  // Login and splash photo overlay (charcoal, from the Funga Siku spec).
  static const overlayTop = Color(0x66121010);
  static const overlayBottom = Color(0xF2121010);

  // Signature B (Funga Siku) colours, from the approved fire spec.
  static const fireUnderglow = Color(0x6BE30613); // brand red at 42%
  static const fireHalo = Color(0x57E30613); // brand red at 34%
  static const charcoalClear = Color(0x00121010);
  static const fireHeadline = Color(0xFFFF2A2F); // "IMEFUNGWA!"
  static const fireTagline = Color(0xFFFF5A4E);
  static const onDarkText = Color(0xFFE6E6E6);
  static const onDarkSkip = Color(0xFFD4D4D4); // "Ruka"
  static const fireGlow = Color(0x75FF7620); // rgba(255,118,32,.46)
  static const fireGlowEdge = Color(0x2EC4300E); // rgba(196,48,14,.18)
  static const fireUnderglowEdge = Color(0x24E30613); // red at 14%
  static const fireHaloEdge = Color(0x1FE30613); // red at 12%
  static const fireHeadlineShadow = Color(0x73E30613); // red at 45%
  static const fireBarGlow = Color(0xCCE30613); // red at 80%

  // Product photo loading ring: the approved flame ramp as a glowing ember.
  static const flameCore = Color(0xFFFFE6A0);
  static const flameOrange = Color(0xFFFF9632);
  static const flameDeep = Color(0xFFAA0A0E);
  static const flameDeepClear = Color(0x00AA0A0E);
  static const spinnerTrackOnDark = Color(0x1FFFFFFF); // white at 12%
  static const spinnerTrack = Color(0x14141414); // ink at 8%

  // Borders.
  static const border = Color(0xFFE2E2E2);
  static const borderStrong = Color(0xFFC8C8C8);

  // Status.
  // Vendor sync states approved in the pending-sync reference, 22 October 2026.
  static const syncPending = Color(0xFFBC4E52);
  static const syncPendingOnDark = Color(0xFFE89B9E);
  static const syncSending = Color(0xFF6E727D);
  static const success = Color(0xFF12813A);
  static const successOnDark = Color(0xFF4ADE80);
  static const successSurface = Color(0xFFE8F5EC);
  static const warning = Color(0xFFB85C00);
  static const warningSurface = Color(0xFFFFF4E5);
  static const warningOnDark = Color(0xFFFFB46B);
  static const error = Color(0xFFB42318);
  static const errorSurface = Color(0xFFFEF0EE);

  // Kikapu (cart) reference approved 22 October 2026, sampled from
  // docs/mr_nyama/design/screenshots/vendor-cart-approved-2026-10-22.
  static const kikapuBackground = Color(0xFFF6F8FA);
  static const kikapuLine = Color(0xFFECEEF2);
  static const kikapuStepper = Color(0xFFF2F4F6);
  static const kikapuTile = Color(0xFFF2F3F5);
  static const kikapuSelected = Color(0xFFFEF3F3);
  static const kikapuDisabledSurface = Color(0xFFF1F2F5);
  static const kikapuDisabledTile = Color(0xFFEAEBEE);
  static const kikapuDisabledText = Color(0xFF858997);
  static const kikapuCaption = Color(0xFF6E748B);
  static const kikapuRadio = Color(0xFFB7BAC6);
  static const kikapuSwipeDelete = Color(0xFFF4434D);
  static const kikapuSnack = Color(0xFF2C3039);
  static const kikapuGrabber = Color(0xFFD9DDE2);
  static const kikapuSecondary = Color(0xFFEEEFF3);
  static const kikapuSecondaryText = Color(0xFF444D66);
  static const kikapuButtonDisabled = Color(0xFFEAECEF);
  static const kikapuButtonDisabledText = Color(0xFF9598A3);
  static const kikapuRedSurface = Color(0xFFFCECED);
  static const kikapuSuccess = Color(0xFF14A44D);
  static const kikapuSuccessSurface = Color(0xFFE3F7EB);
  static const kikapuPending = Color(0xFFF86A1E);
  static const kikapuPendingSurface = Color(0xFFFDF0E5);
  static const kikapuEmptyIcon = Color(0xFF838896);
  static const kikapuEmptyTitle = Color(0xFF384056);
}

/// Spacing scale used by the design system (px = logical pixels).
class MNSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x7 = 28.0;

  /// Screen side padding.
  static const gutter = x4;
}

class MNRadius {
  static const handle = 2.0;
  static const small = 8.0; // chips, thumbnails, quantity buttons
  static const catalogueCard = 16.0;
  static const medium = 12.0; // buttons, fields, cards, tiles, notes
  static const sheet = 20.0;
  static const pill = 24.0;
}

/// Fixed component sizes from the design system.
class MNSize {
  static const button = 56.0;
  static const textButton = 48.0;
  static const appBar = 56.0;
  static const navBar = 56.0;
  static const iconButton = 48.0;
  static const minTouch = 48.0;
  static const icon = 24.0;
  static const iconSmall = 16.0;
  static const iconMedium = 20.0;
  static const quantity = 48.0;
  static const quantityLarge = 64.0;
  static const key = 64.0;
  static const field = 56.0;
  static const row = 64.0;
  static const menuRow = 56.0;
  static const thumb = 48.0;
  static const thumbLarge = 56.0;
  static const chip = 40.0;
  static const tile = 88.0;
  static const payOption = 72.0;
  static const pinDot = 16.0;
  static const avatar = 40.0;
  static const hero = 96.0;

  /// Product card photo height at the 390 px reference width; cards keep
  /// this aspect ratio on other widths.
  static const productImage = 216.0;
  static const productImageAspect = 173 / 216;
  static const borderWidth = 1.5;
  static const focusBorderWidth = 2.0;
}

/// Manrope type styles from the design system (size / line height, weight).
/// Numbers use tabular figures so totals do not jitter. Change a weight only
/// through [MNText.withWeight].
class MNText {
  static const _family = 'Manrope';

  /// Shared controls follow the active mode; vendor styles remain unchanged.
  static bool isOffice(BuildContext context) => [
        'Inter',
        'CupertinoSystemText',
        'CupertinoSystemDisplay'
      ].contains(Theme.of(context).textTheme.bodyMedium?.fontFamily);
  static TextStyle resolve(BuildContext context, TextStyle style) {
    if (!isOffice(context)) return style;
    final original = style.fontWeight?.value ?? 400;
    final weight =
        original >= 600 ? ((style.fontSize ?? 16) >= 20 ? 700 : 500) : original;
    return style.copyWith(
        fontFamily: OwnerStyle.fontFamily(
            Theme.of(context).platform, style.fontSize ?? 16),
        fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
        fontVariations: [FontVariation('wght', weight.toDouble())]);
  }

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _s(double size, double line, FontWeight weight,
          {Color color = MNColors.ink,
          bool tabular = false,
          double? spacing}) =>
      TextStyle(
          fontFamily: _family,
          fontSize: size,
          height: line / size,
          fontWeight: weight,
          color: color,
          letterSpacing: spacing,
          fontVariations: [FontVariation.weight(weight.value.toDouble())],
          fontFeatures: tabular ? _tabular : null);

  /// [style] at another weight. Manrope is a variable font (200–800, default
  /// 200), so the weight must also be set on its `wght` axis.
  static TextStyle withWeight(TextStyle style, FontWeight weight) =>
      style.copyWith(
          fontWeight: weight,
          fontVariations: [FontVariation.weight(weight.value.toDouble())]);

  /// `.big` — today's total and other headline amounts.
  static final amountLarge =
      _s(34, 40, FontWeight.w800, tabular: true, spacing: -0.34);

  /// `.h1` — screen and sheet headings.
  static final heading = _s(22, 28, FontWeight.w800);

  /// Vendor catalogue follows the light, large-title screen pattern in Manrope.
  static final pageTitle = _s(34, 42, FontWeight.w700, spacing: -.9);
  static final brandTitle = _s(18, 24, FontWeight.w700);
  static final referenceBody = _s(16, 22, FontWeight.w400);
  static final referenceCaption =
      _s(14, 20, FontWeight.w400, color: MNColors.referenceMuted);
  static final referenceSection = _s(20, 26, FontWeight.w700);
  static final referenceQuantity = _s(20, 26, FontWeight.w700, tabular: true);
  static final referenceAmount = _s(48, 52, FontWeight.w700, tabular: true);
  static final referenceCurrency = _s(24, 32, FontWeight.w700);
  static final referencePayment = _s(24, 30, FontWeight.w700, tabular: true);
  static final catalogueName = _s(15, 21, FontWeight.w500);
  static final cataloguePrice = _s(16, 22, FontWeight.w600, tabular: true);

  /// `.bar h1` — app header title.
  static final barTitle = _s(18, 24, FontWeight.w700, color: MNColors.white);

  /// `.btn` — button label.
  static final button = _s(17, 20, FontWeight.w700);

  /// `.btn-t` — text button label.
  static final textButton = _s(16, 20, FontWeight.w700, color: MNColors.red);

  /// `.rt`, `.sec` — row titles and section headings.
  static final title = _s(16, 22, FontWeight.w700);

  /// Filter and date-wheel sheet headings (approved filter reference,
  /// 28 October 2026), next to the close button.
  static final sheetTitle = _s(18, 24, FontWeight.w800);

  /// Date-wheel rows: the centred date, and the dates around it.
  static final wheelSelected = _s(17, 22, FontWeight.w800, tabular: true);
  static final wheel =
      _s(16, 22, FontWeight.w500, color: MNColors.disabledText, tabular: true);

  /// `.body` — body copy.
  static final body = _s(16, 22, FontWeight.w500);

  /// `.rs` — row secondary text.
  static final secondary = _s(14, 20, FontWeight.w500, color: MNColors.ink2);

  /// `.tile` — action tile title (.02em tracking).
  static final tile = _s(15, 18, FontWeight.w800, spacing: .3);

  /// `.mrow` — menu row label.
  static final menu = _s(16, 22, FontWeight.w600);

  /// `.pc-n` — product card name.
  static final productName = _s(15, 20, FontWeight.w700);

  /// `.pc-s`, `.meta` — small muted metadata.
  static final meta =
      _s(13, 16, FontWeight.w600, color: MNColors.muted, tabular: true);

  /// `.lbl`, `.flabel` — field labels.
  static final label = _s(13, 16, FontWeight.w600, color: MNColors.ink2);

  /// `.st` — status lines.
  static final status = _s(13, 16, FontWeight.w600);

  /// Reference sync count beside the cloud, without a badge background.
  static final syncCount = _s(14, 18, FontWeight.w500);

  /// `.amt` — row amounts.
  static final amount = _s(16, 20, FontWeight.w800, tabular: true);

  /// `.price` — prices, in brand red.
  static final price =
      _s(16, 20, FontWeight.w800, color: MNColors.red, tabular: true);

  /// `.nv` — bottom navigation label.
  static final navLabel = _s(12, 16, FontWeight.w700);

  /// `.chip`.
  static final chip = _s(14, 16, FontWeight.w700);

  /// `.qv` / `.qv.L` — quantity values.
  static final quantity = _s(18, 24, FontWeight.w800, tabular: true);
  static final quantityLarge = _s(36, 44, FontWeight.w800, tabular: true);

  /// `.cb` — activation code digits.
  static final code = _s(24, 28, FontWeight.w800, tabular: true);

  /// `.fx-head` — "SIKU IMEFUNGWA!" (800 30/36, .04em).
  static final fireHeadline =
      _s(30, 36, FontWeight.w800, color: MNColors.white, spacing: 1.2);

  /// `.fx-tag` — the tagline under it (800 13/16, .24em).
  static final fireTagline =
      _s(13, 16, FontWeight.w800, color: MNColors.fireTagline, spacing: 3.1);

  /// `.key` — PIN keypad digits.
  static final key = _s(28, 32, FontWeight.w600);

  /// `.toast`, `.note`.
  static final note = _s(15, 20, FontWeight.w600);

  /// `.field input`.
  static final input = _s(17, 22, FontWeight.w600);

  /// Kikapu reference (22 October 2026): sizes and weights matched to the
  /// approved image, set in Manrope.
  static final kikapuTitle = _s(32, 40, FontWeight.w800, spacing: -.6);
  static final kikapuAction =
      _s(15, 20, FontWeight.w500, color: MNColors.referenceMuted);
  static final kikapuName = _s(15, 20, FontWeight.w500);
  static final kikapuQuantity = _s(16, 20, FontWeight.w600, tabular: true);
  static final kikapuLineTotal =
      _s(16.5, 20, FontWeight.w800, tabular: true, spacing: -.2);
  static final kikapuTotal = _s(22.5, 28, FontWeight.w800, spacing: -.3);
  static final kikapuTotalAmount =
      _s(21, 26, FontWeight.w800, tabular: true, spacing: -.3);
  static final kikapuHeading = _s(17, 22, FontWeight.w800);
  static final kikapuHint =
      _s(14.5, 18, FontWeight.w400, color: MNColors.referenceMuted);
  static final kikapuOption = _s(15, 20, FontWeight.w500);
  static final kikapuOptionCaption =
      _s(12.1, 16, FontWeight.w400, color: MNColors.kikapuCaption);
  static final kikapuSnack = _s(15, 20, FontWeight.w500, color: MNColors.white);
  static final kikapuSheetTitle = _s(19, 24, FontWeight.w800, spacing: -.2);
  static final kikapuSheetBody =
      _s(14.5, 18, FontWeight.w400, color: MNColors.referenceMuted);
  static final kikapuSheetButton = _s(17, 22, FontWeight.w700);
  static final kikapuRowTitle = _s(14.3, 19, FontWeight.w500);
  static final kikapuRowBody =
      _s(13.5, 18, FontWeight.w400, color: MNColors.kikapuCaption);
  static final kikapuEmptyTitle =
      _s(19, 24, FontWeight.w700, color: MNColors.kikapuEmptyTitle);
  static final kikapuEmptyBody =
      _s(15.5, 20, FontWeight.w400, color: MNColors.referenceMuted);
}

/// Owner-only tokens measured against the three references approved on
/// 22 October 2026. Vendor navigation and tokens remain independent.
class OwnerStyle {
  static const background = Color(0xFFF4F7FA);
  static const vendorsBackground = Color(0xFFF4F5F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF000000);
  static const muted = Color(0xFF59627A);
  static const secondary = Color(0xFF969AA5);
  static const line = Color(0xFFE1E6EF);
  static const red = Color(0xFFE30613);
  static const green = Color(0xFF00BF3D);
  static const navMuted = Color(0xFF454B5E);
  static const priceHint = Color(0xFF777D83);
  static const missingPrice = Color(0xFFD2605E);
  static const avatar = Color(0xFFEEEEEE);
  static const assignAction = Color(0xFFD83131);

  /// The scorecard reference (31 October 2026).
  static const scoreTabs = Color(0xFFE9EEF3);
  static const scoreCircle = Color(0xFFF0F0F2);
  static const scoreBars = Color(0xFF8E94A3);
  static const scoreChip = Color(0xFFEAEBEE);
  static const scoreRed = Color(0xFFE73239);
  static const scoreUpdate = Color(0xFFEEF2F6);
  static const scoreDisabled = Color(0xFFD6D7DB);
  static const scorePanel = Color(0xFFE1E3E7);
  static const scoreFocus = Color(0xFF8FA3D4);
  static const scoreSaved = Color(0xFF46B85C);
  static const scoreNote = Color(0xFFEFF0F2);

  /// The Station reference (30 October 2026).
  static const stationPhotoEmpty = Color(0xFFE7E9EE);
  static const stationPhotoHint = Color(0xFF6F7689);
  static const stationPhotoBusy = Color(0x66FFFFFF);
  static const stationChevron = Color(0xFF7D8292);

  /// The Badilisha PIN reference (30 October 2026).
  static const pinTitle = Color(0xFF14171B);
  static const pinSubtitle = Color(0xFF66707E);
  static const pinLink = Color(0xFF536171);
  static const pinDot = Color(0xFF808B97);
  static const pinLockedKey = Color(0xFFE7EBF0);
  static const pinLockedDigit = Color(0xFFA7AFBA);

  /// Flutter's native San Francisco aliases resolve to the iOS system font.
  /// Web uses bundled Inter even when opened on an Apple device.
  static String fontFamily(TargetPlatform platform, double size) =>
      !kIsWeb && platform == TargetPlatform.iOS
          ? (size >= 20 ? 'CupertinoSystemDisplay' : 'CupertinoSystemText')
          : 'Inter';
  static double scale(BuildContext context) =>
      (MediaQuery.sizeOf(context).width / 390).clamp(.8, 1.65);
  static double px(BuildContext context, double size) => size * scale(context);
  static TextStyle text(BuildContext context, double size,
          {double weight = 400,
          Color color = ink,
          double spacing = -.45,
          double height = 1.2}) =>
      TextStyle(
          fontFamily: fontFamily(Theme.of(context).platform, size),
          fontSize: px(context, size),
          fontVariations: [FontVariation('wght', weight)],
          fontWeight:
              FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
          color: color,
          letterSpacing: px(context, spacing),
          height: height);
}
