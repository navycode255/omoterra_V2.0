import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/vendor_repository.dart'
    show AuthFailure, AuthFailureKind;
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'icon.dart';
import 'stock_illustration.dart';

/// `.hero` with `.inkbig`: a 96 px grey circle with an icon, or an [image], a
/// heading and an optional line of text and action. Scrolls rather than
/// clipping on short screens or large text.
class MNEmptyState extends StatelessWidget {
  final MNIconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color circle;
  final Color iconColor;

  /// A screen's own illustration from `assets/errors/`, drawn at [imageWidth]
  /// or the available width if that is less.
  final String? image;
  final double imageWidth;

  const MNEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.message,
      this.action,
      this.circle = MNColors.surface,
      this.iconColor = MNColors.ink,
      this.image,
      this.imageWidth = 220});

  Widget _picture(BuildContext context, double maxWidth) {
    final width = (maxWidth - MNSpace.x6 * 2).clamp(0.0, imageWidth);
    return Image.asset(image!,
        width: width,
        fit: BoxFit.contain,
        cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final content = Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: MNSpace.x6, vertical: MNSpace.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (image != null)
                  _picture(context, constraints.maxWidth)
                else if (icon == MNIconData.box)
                  const MNStockIllustration()
                else
                  Container(
                    width: MNSize.hero,
                    height: MNSize.hero,
                    decoration:
                        BoxDecoration(color: circle, shape: BoxShape.circle),
                    child:
                        Center(child: MNIcon(icon, size: 48, color: iconColor)),
                  ),
                SizedBox(height: image != null ? MNSpace.x4 : MNSpace.x5),
                Semantics(
                  header: true,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: image == null
                          ? MNText.resolve(context, MNText.heading)
                          : MNText.resolve(
                              context,
                              MNText.withWeight(
                                  MNText.heading
                                      .copyWith(fontSize: 23, height: 1.2),
                                  FontWeight.w700))),
                ),
                if (message != null) ...[
                  const SizedBox(height: MNSpace.x2),
                  Text(message!,
                      textAlign: TextAlign.center,
                      style: MNText.resolve(context, MNText.body)
                          .copyWith(color: MNColors.ink2)),
                ],
                if (action != null) ...[
                  const SizedBox(height: MNSpace.x5),
                  action!,
                ],
              ],
            ),
          );
          // Inside a page's own scroll, a second one would take the swipe that
          // refreshes the page.
          if (!constraints.hasBoundedHeight) return content;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: content),
            ),
          );
        },
      );
}

/// Pull-to-refresh that also retries what failed inside it: an [MNErrorState]
/// below it joins in, so a swipe works even where the page itself has nothing
/// of its own to refresh. A failed refresh stays on the provider it came from.
class MNRefreshArea extends StatefulWidget {
  final Future<void> Function()? onRefresh;
  final Widget child;
  final Color? color;
  const MNRefreshArea(
      {super.key, this.onRefresh, required this.child, this.color});

  @override
  State<MNRefreshArea> createState() => _MNRefreshAreaState();
}

class _MNRefreshAreaState extends State<MNRefreshArea> {
  final _errors = _FailedParts();

  @override
  void dispose() {
    _errors.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _errors.retry();
    try {
      await widget.onRefresh?.call();
    } catch (_) {
      // The page shows its own error.
    }
  }

  @override
  Widget build(BuildContext context) => _FailedPartsScope(
      parts: _errors,
      child: RefreshIndicator(
          onRefresh: _refresh,
          color: widget.color ?? MNColors.red,
          notificationPredicate: (n) =>
              n.depth == 0 && (widget.onRefresh != null || _errors.any),
          child: widget.child));
}

/// The failed parts of one page, top first. Only the first shows the
/// illustration; one swipe retries them all.
class _FailedParts extends ChangeNotifier {
  final _parts = <_MNErrorStateState>[];
  bool _disposed = false;

  bool get any => _parts.any((p) => p.widget.onRetry != null);
  bool isFirst(_MNErrorStateState part) => _parts.firstOrNull == part;
  void add(_MNErrorStateState part) => _parts.add(part);

  void remove(_MNErrorStateState part) {
    final wasFirst = isFirst(part);
    _parts.remove(part);
    if (!wasFirst) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  void retry() {
    for (final part in [..._parts]) {
      part.widget.onRetry?.call();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _FailedPartsScope extends InheritedWidget {
  final _FailedParts parts;
  const _FailedPartsScope({required this.parts, required super.child});
  @override
  bool updateShouldNotify(_FailedPartsScope oldWidget) =>
      parts != oldWidget.parts;
}

/// The error screen: an illustration, a calm heading and line of text, and no
/// button, because a swipe down retries [onRetry]. When [error] says the phone
/// could not reach the network it is the no-internet screen, whatever
/// [title] and [message] say.
class MNErrorState extends ConsumerStatefulWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final Object? error;
  const MNErrorState(
      {super.key, this.title, this.message, this.onRetry, this.error});

  /// The pictures' own widths at most; they have transparent space around them.
  static const _imageWidth = 333.0, _networkImageWidth = 300.0;

  bool get _noNetwork {
    final failure = error;
    return failure is AuthFailure &&
        failure.kind == AuthFailureKind.offline &&
        !failure.serviceProblem;
  }

  @override
  ConsumerState<MNErrorState> createState() => _MNErrorStateState();
}

class _MNErrorStateState extends ConsumerState<MNErrorState> {
  _FailedParts? _parts;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parts =
        context.dependOnInheritedWidgetOfExactType<_FailedPartsScope>()?.parts;
    if (parts == _parts) return;
    _parts?.removeListener(_changed);
    _parts?.remove(this);
    _parts = parts;
    parts?.add(this);
    parts?.addListener(_changed);
  }

  @override
  void dispose() {
    _parts?.removeListener(_changed);
    _parts?.remove(this);
    super.dispose();
  }

  Widget _content(BuildContext context, double maxWidth) {
    final strings = ref.watch(stringsProvider);
    final noNetwork = widget._noNetwork;
    final width = (maxWidth - MNSpace.x4 * 2).clamp(0.0,
        noNetwork ? MNErrorState._networkImageWidth : MNErrorState._imageWidth);
    return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: MNSpace.x2, vertical: MNSpace.x4),
        child: Semantics(
            onTap: widget.onRetry,
            onTapHint: widget.onRetry == null ? null : strings.retry,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset(
                  noNetwork
                      ? 'assets/errors/network_state.png'
                      : 'assets/errors/error_state.png',
                  width: width,
                  height: width * 2 / 3,
                  fit: BoxFit.contain,
                  cacheWidth:
                      (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) =>
                      SizedBox(height: width * 2 / 3)),
              SizedBox(height: noNetwork ? MNSpace.x4 : MNSpace.x2),
              Semantics(
                  header: true,
                  child: Text(
                      noNetwork
                          ? strings.noInternetTitle
                          : widget.title ?? strings.errorTitle,
                      textAlign: TextAlign.center,
                      style: MNText.resolve(
                          context,
                          MNText.withWeight(
                              MNText.heading.copyWith(
                                  fontSize: noNetwork ? 22 : 23,
                                  letterSpacing: noNetwork ? -.4 : null,
                                  height: 1.2),
                              FontWeight.w700)))),
              const SizedBox(height: MNSpace.x2),
              Text(
                  noNetwork
                      ? strings.noInternetBody
                      : widget.message ?? strings.errorBody,
                  textAlign: TextAlign.center,
                  style: MNText.resolve(context, MNText.body).copyWith(
                      fontSize: noNetwork ? 14.5 : 15.5,
                      letterSpacing: noNetwork ? -.2 : null,
                      color: MNColors.ink2)),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    // One illustration per page: the others wait on the same swipe.
    if (parts != null && !parts.isFirst(this)) return const SizedBox.shrink();
    final body = LayoutBuilder(builder: (context, c) {
      if (!c.hasBoundedHeight) return _content(context, c.maxWidth);
      // On its own in the page: it brings the scrolling a swipe needs.
      return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(child: _content(context, c.maxWidth))));
    });
    return parts == null && widget.onRetry != null
        ? MNRefreshArea(onRefresh: () async => widget.onRetry!(), child: body)
        : body;
  }
}

/// The one way a screen turns an [AsyncValue] into loading, empty, error or
/// content, so every list behaves the same:
///
/// * data that [isEmpty] says is empty shows [empty], or skeleton rows
///   while [refreshing] (a background fetch may still fill it);
/// * other data goes to [data];
/// * an error shows [MNErrorState] with [onRetry];
/// * anything else (first load) shows [loadingRows] skeleton rows.
///
/// ```dart
/// MNAsyncView(
///   value: ref.watch(productsProvider),
///   isEmpty: (products) => products.isEmpty,
///   empty: (_) => MNEmptyState(icon: MNIconData.bag, title: strings.noProducts),
///   onRetry: () => ref.invalidate(productsProvider),
///   data: (products) => ProductList(products),
/// )
/// ```
class MNAsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final bool Function(T value)? isEmpty;
  final WidgetBuilder? empty;
  final VoidCallback? onRetry;
  final bool refreshing;
  final int loadingRows;

  const MNAsyncView(
      {super.key,
      required this.value,
      required this.data,
      this.isEmpty,
      this.empty,
      this.onRetry,
      this.refreshing = false,
      this.loadingRows = 5});

  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncData(:final value) when isEmpty?.call(value) ?? false => refreshing
            ? MNLoadingState(rows: loadingRows)
            : empty?.call(context) ?? const SizedBox.shrink(),
        AsyncData(:final value) => data(value),
        AsyncError(:final error) =>
          MNErrorState(onRetry: onRetry, error: error),
        _ => MNLoadingState(rows: loadingRows),
      };
}

/// `.sk`: a grey placeholder block that pulses 1 → .55 → 1 over 1.2 s.
class MNSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const MNSkeleton(
      {super.key, this.width, required this.height, this.radius = 6});

  @override
  State<MNSkeleton> createState() => _MNSkeletonState();
}

class _MNSkeletonState extends State<MNSkeleton>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: MNMotion.skeleton);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MNMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // ease-in-out between 1 and .55, back at the end of the cycle.
          final t =
              Curves.easeInOut.transform(1 - (2 * _controller.value - 1).abs());
          return Opacity(opacity: 1 - .45 * t, child: child);
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
              color: MNColors.disabled,
              borderRadius: BorderRadius.circular(widget.radius)),
        ),
      );
}

/// Loading state: [rows] skeleton list rows shaped like `.row`. Announced
/// once as "Inapakia".
class MNLoadingState extends ConsumerWidget {
  final int rows;
  const MNLoadingState({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Semantics(
      label: strings.loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows,
          itemBuilder: (context, i) => Container(
            height: MNSize.row,
            padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
            decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: MNColors.border))),
            child: const Row(children: [
              MNSkeleton(
                  width: MNSize.thumb,
                  height: MNSize.thumb,
                  radius: MNRadius.small),
              SizedBox(width: MNSpace.x3),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                          widthFactor: .6, child: MNSkeleton(height: 14)),
                      SizedBox(height: MNSpace.x2),
                      FractionallySizedBox(
                          widthFactor: .35, child: MNSkeleton(height: 12)),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
