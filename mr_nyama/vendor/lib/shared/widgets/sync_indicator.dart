import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Delivery to the office only; a sent operation is not staff verification.
enum MNSyncStatus { sent, waiting, sending, attention, unknown }

/// Three confirmed visual states: green cloud/check, animated grey cloud, and
/// soft-red cloud/clock with an outstanding-record count. Review records keep
/// their distinct spoken label and remain outstanding. Unknown counts stay grey.
class MNSyncIndicator extends ConsumerWidget {
  final MNSyncStatus status;
  final bool compact, onDark;
  final int? pendingCount;
  final VoidCallback? onTap;
  const MNSyncIndicator(
      {super.key,
      required this.status,
      this.compact = false,
      this.onDark = false,
      this.pendingCount,
      this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final outstanding =
        status == MNSyncStatus.waiting || status == MNSyncStatus.attention;
    final label = switch (status) {
      MNSyncStatus.sent => strings.syncSent,
      MNSyncStatus.waiting => strings.syncWaiting,
      MNSyncStatus.sending => strings.syncSending,
      MNSyncStatus.attention => strings.syncAttention,
      MNSyncStatus.unknown => strings.syncUnknown,
    };
    final color = outstanding
        ? (onDark ? MNColors.syncPendingOnDark : MNColors.syncPending)
        : status == MNSyncStatus.sent
            ? (onDark ? MNColors.successOnDark : MNColors.success)
            : (onDark ? MNColors.onDarkMuted : MNColors.syncSending);
    final count = outstanding && pendingCount != null && pendingCount! > 0
        ? pendingCount
        : null;
    final countLabel = count == null ? null : strings.syncOutstanding(count);
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      MNSyncGlyph(status: status, color: color),
      if (count != null) ...[
        const SizedBox(width: 6),
        Text('$count', style: MNText.syncCount.copyWith(color: color)),
      ],
      if (!compact) ...[
        const SizedBox(width: 6),
        Flexible(
            child: Text(label, style: MNText.status.copyWith(color: color))),
      ],
    ]);
    Widget content = ExcludeSemantics(child: row);
    if (onTap != null) {
      content = Tooltip(
          message: countLabel == null ? label : '$label. $countLabel',
          excludeFromSemantics: true,
          child: MNPressable(
              onTap: onTap,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      minWidth: MNSize.minTouch, minHeight: MNSize.minTouch),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: content))));
    }
    return Semantics(
        container: true,
        label: label,
        value: countLabel,
        liveRegion: true,
        button: onTap == null ? null : true,
        onTap: onTap,
        child: ExcludeSemantics(child: content));
  }
}

/// Reference cloud stays still; only the small transfer arrows rotate. Reduced
/// motion, paused routes and disposal stop the ticker, while text still says sending.
class MNSyncGlyph extends StatefulWidget {
  final MNSyncStatus status;
  final Color color;
  const MNSyncGlyph({super.key, required this.status, required this.color});
  @override
  State<MNSyncGlyph> createState() => _MNSyncGlyphState();
}

class _MNSyncGlyphState extends State<MNSyncGlyph>
    with SingleTickerProviderStateMixin {
  late final controller =
      AnimationController(vsync: this, duration: MNMotion.spin);
  void updateAnimation() {
    final animate = widget.status == MNSyncStatus.sending &&
        !MNMotion.reduced(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !controller.isAnimating) {
      controller.repeat();
    } else if (!animate) {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateAnimation();
  }

  @override
  void didUpdateWidget(covariant MNSyncGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateAnimation();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget asset(String name, {double size = 24}) =>
      SvgPicture.asset('assets/sync/$name.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
          excludeFromSemantics: true);
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: 24,
      child: widget.status == MNSyncStatus.sent
          ? MNIcon(MNIconData.cloudOk, size: 24, color: widget.color)
          : widget.status == MNSyncStatus.sending
              ? Stack(children: [
                  asset('cloud'),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: RotationTransition(
                          turns: controller, child: asset('arrows', size: 14)))
                ])
              : asset('pending'));
}
