import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/pressable.dart';
import 'sale_success_mark.dart';
import 'sales_store.dart';

/// Floating Kikapu sheets (reference approved 22 October 2026): a white
/// card with a grabber, rounded on all corners, over a dimmed scrim.
Future<T?> showKikapuSheet<T>(BuildContext context,
        {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: MNColors.scrim,
      backgroundColor: Colors.transparent,
      elevation: 0,
      sheetAnimationStyle: mnSheetAnimation(context),
      builder: (context) => _KikapuSheetFrame(child: builder(context)),
    );

class _KikapuSheetFrame extends StatelessWidget {
  final Widget child;
  const _KikapuSheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context);
    final bottom = inset.bottom > 8 ? inset.bottom : 8.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, inset.top + 8, 8, bottom),
      child: Material(
        color: MNColors.white,
        borderRadius: BorderRadius.circular(MNRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: MNColors.kikapuGrabber,
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 13),
              child,
            ]),
          ),
        ),
      ),
    );
  }
}

/// A 70 px soft circle holding a status glyph.
class _StatusCircle extends StatelessWidget {
  final Color color;
  final Widget child;
  const _StatusCircle({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: child));
}

class _SheetHeading extends StatelessWidget {
  final String title;
  final String body;
  final double bodyInset;
  const _SheetHeading(
      {required this.title, required this.body, this.bodyInset = 0});

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 6),
        Semantics(
            header: true,
            child: Text(title,
                textAlign: TextAlign.center, style: MNText.kikapuSheetTitle)),
        const SizedBox(height: 7),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: bodyInset),
          child: Text(body,
              textAlign: TextAlign.center, style: MNText.kikapuSheetBody),
        ),
      ]);
}

enum KikapuButtonStyle { primary, grey, text }

/// The sheets' 52 px buttons: red, grey, or red text only.
class KikapuSheetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final KikapuButtonStyle style;
  const KikapuSheetButton(this.label,
      {super.key,
      required this.onPressed,
      this.style = KikapuButtonStyle.primary});

  @override
  Widget build(BuildContext context) {
    final (fill, pressed, text) = switch (style) {
      KikapuButtonStyle.primary => (
          MNColors.red,
          MNColors.redPressed,
          MNColors.white
        ),
      KikapuButtonStyle.grey => (
          MNColors.kikapuSecondary,
          MNColors.surfacePressed,
          MNColors.kikapuSecondaryText
        ),
      KikapuButtonStyle.text => (
          Colors.transparent,
          MNColors.textPressed,
          MNColors.red
        ),
    };
    return MNPressable(
      onTap: onPressed,
      color: fill,
      pressedColor: pressed,
      borderRadius: BorderRadius.circular(MNRadius.medium),
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MNSize.minTouch),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ExcludeSemantics(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: style == KikapuButtonStyle.grey
                      ? MNText.kikapuSheetButton.copyWith(color: text)
                      : MNText.kikapuSheetButton.copyWith(color: text)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Futa bidhaa zote?": true when the vendor confirms.
Future<bool> showClearCartSheet(BuildContext context, Strings strings) async =>
    await showKikapuSheet<bool>(context,
        builder: (context) => Column(children: [
              const _StatusCircle(
                  color: MNColors.kikapuRedSurface,
                  child: MNIcon(MNIconData.trash,
                      size: 32, strokeWidth: 1.7, color: MNColors.red)),
              _SheetHeading(
                  title: strings.clearAllTitle, body: strings.clearCartBody),
              const SizedBox(height: 22),
              KikapuSheetButton(strings.cancel,
                  style: KikapuButtonStyle.grey,
                  onPressed: () => Navigator.pop(context, false)),
              const SizedBox(height: 6),
              KikapuSheetButton(strings.clearCart,
                  style: KikapuButtonStyle.text,
                  onPressed: () => Navigator.pop(context, true)),
            ])) ==
    true;

/// "Imeshindikana kuhifadhi": true for "Jaribu tena".
Future<bool> showSaveFailedSheet(BuildContext context, Strings strings) async =>
    await showKikapuSheet<bool>(context,
        builder: (context) => Column(children: [
              const _StatusCircle(
                  color: MNColors.kikapuRedSurface,
                  child: MNIcon(MNIconData.error,
                      size: 36, strokeWidth: 1.6, color: MNColors.red)),
              _SheetHeading(
                  title: strings.saveErrorTitle,
                  body: strings.saleSaveFailedBody,
                  bodyInset: 40),
              const SizedBox(height: 16),
              KikapuSheetButton(strings.retry,
                  onPressed: () => Navigator.pop(context, true)),
              const SizedBox(height: 6),
              KikapuSheetButton(strings.cancel,
                  style: KikapuButtonStyle.grey,
                  onPressed: () => Navigator.pop(context, false)),
            ])) ==
    true;

/// The saved sale's status, live from the phone's database.
final kikapuSaleStatusProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, clientId) =>
        ref.watch(salesStoreProvider).watchSaleStatus(clientId));

/// Shown right after the sale is saved on the phone. It says "saved on the
/// phone, waiting for the network" until the server accepts the sale, then
/// switches in place to "sent to the office", where the sale-success
/// signature (flame → check) plays and settles.
Future<void> showSaleResultSheet(BuildContext context, String clientId) =>
    showKikapuSheet<void>(context,
        builder: (context) => SaleResultSheet(clientId: clientId));

class SaleResultSheet extends ConsumerWidget {
  final String clientId;
  const SaleResultSheet({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final status = ref.watch(kikapuSaleStatusProvider(clientId)).valueOrNull;
    final sent = status == 'sent';
    const cloud = MNIcon(MNIconData.cloud,
        size: 42, strokeWidth: 1.5, color: MNColors.ink);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(children: [
        AnimatedSwitcher(
          duration: MNMotion.of(context, MNMotion.small),
          child: sent
              ? SaleSuccessMark(
                  key: ValueKey('sent-$clientId'),
                  playId: clientId,
                  size: 70,
                  circleColor: MNColors.kikapuSuccessSurface,
                  checkColor: MNColors.kikapuSuccess,
                  checkScale: .82,
                  checkStroke: 3)
              : const _StatusCircle(
                  key: ValueKey('pending'),
                  color: MNColors.kikapuPendingSurface,
                  child: MNIcon(MNIconData.clock,
                      size: 36,
                      strokeWidth: 1.6,
                      color: MNColors.kikapuPending)),
        ),
        _SheetHeading(
            title:
                sent ? strings.saleSavedTitle : strings.saleSavedOnPhoneTitle,
            body:
                sent ? strings.saleSentToOffice : strings.saleSendsWhenOnline),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(
                width: 42,
                height: 42,
                child: Stack(clipBehavior: Clip.none, children: [
                  cloud,
                  if (sent)
                    const Positioned(
                        left: 15,
                        top: 21,
                        child: MNIcon(MNIconData.check,
                            size: 18,
                            strokeWidth: 2.6,
                            color: MNColors.kikapuSuccess)),
                ])),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        sent
                            ? strings.saleSyncedTitle
                            : strings.saleWaitingNetwork,
                        style: MNText.kikapuRowTitle),
                    const SizedBox(height: 4),
                    Text(
                        sent ? strings.saleSyncedBody : strings.saleSafeOnPhone,
                        style: MNText.kikapuRowBody),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        KikapuSheetButton(strings.okay,
            onPressed: () => Navigator.of(context).pop()),
      ]),
    );
  }
}
