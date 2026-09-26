import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/repository.dart';
import 'components.dart';

const _listing = '@listing|';

// Waits between automatic retries while a screen can't load: soon at first,
// then less often, so a phone back on the network recovers without a tap.
const _autoRetry = [5, 10, 20, 30];

/// Shows [child], or — while any screen data failed to load — one recovery
/// card over it. The card retries in place: the button shows progress until
/// every failed request has answered, and the screen comes back as soon as
/// they succeed. It also retries by itself on a timer and whenever the app
/// returns to the foreground, since the network may be back by then.
class ScreenErrorGate extends ConsumerStatefulWidget {
  final Widget child;
  final EdgeInsets padding;

  /// False on screens that show their own error handling.
  final bool enabled;
  const ScreenErrorGate(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 24),
      this.enabled = true});

  @override
  ConsumerState<ScreenErrorGate> createState() => _ScreenErrorGateState();
}

class _ScreenErrorGateState extends ConsumerState<ScreenErrorGate> {
  // The failure on screen while a retry runs. Reloading clears the recorded
  // failure first, so without it the card would vanish mid-retry.
  Object? _retrying;
  Timer? _timer;
  int _attempt = 0;
  late final AppLifecycleListener _lifecycle =
      AppLifecycleListener(onResume: () => unawaited(_retry()));

  @override
  void initState() {
    super.initState();
    _lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(resourceFailuresProvider).isNotEmpty) _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    final seconds = _autoRetry[min(_attempt, _autoRetry.length - 1)];
    _timer = Timer(Duration(seconds: seconds), () {
      _attempt++;
      unawaited(_retry());
    });
  }

  Future<void> _reload<T>(AutoDisposeFutureProvider<T> provider) async {
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // Recorded again by the provider; the card stays.
    }
  }

  Future<void> _retry() async {
    final failures = ref.read(resourceFailuresProvider);
    if (_retrying != null || !mounted || failures.isEmpty) return;
    _timer?.cancel();
    setState(() => _retrying = failures.values.first);
    final recorded = ref.read(resourceFailuresProvider.notifier);
    final reloads = <Future<void>>[];
    for (final key in failures.keys) {
      if (key.startsWith(_listing)) {
        final provider = listingsProvider(key.substring(_listing.length));
        if (ref.exists(provider)) {
          reloads.add(_reload(provider));
          continue;
        }
      } else if (ref.exists(resourceProvider(key))) {
        reloads.add(_reload(resourceProvider(key)));
        continue;
      }
      // Its screen has closed, so there is nothing left to reload.
      recorded.state = {...recorded.state}..remove(key);
    }
    await Future.wait(reloads)
        .timeout(const Duration(seconds: 45), onTimeout: () => const []);
    if (!mounted) return;
    setState(() => _retrying = null);
    if (ref.read(resourceFailuresProvider).isEmpty) {
      _attempt = 0;
    } else {
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(resourceFailuresProvider, (previous, next) {
      if (_retrying != null) return;
      if (next.isEmpty) {
        _timer?.cancel();
        _attempt = 0;
      } else if (previous == null || previous.isEmpty) {
        _schedule();
      }
    });
    final failures = ref.watch(resourceFailuresProvider);
    final error = failures.values.firstOrNull ?? _retrying;
    final show = widget.enabled && error != null;
    return Stack(fit: StackFit.expand, children: [
      Visibility(visible: !show, maintainState: true, child: widget.child),
      if (show)
        ListView(padding: widget.padding, children: [
          ErrorState(error,
              retrying: _retrying != null, retry: () => unawaited(_retry())),
        ]),
    ]);
  }
}
