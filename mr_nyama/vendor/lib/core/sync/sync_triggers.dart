import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import 'sync_engine.dart';

/// True while the phone has a network. Tests override it.
final connectivityProvider = StreamProvider<bool>((ref) => Connectivity()
    .onConnectivityChanged
    .map((results) => !results.contains(ConnectivityResult.none)));

/// How often the foreground retries due operations; null turns it off
/// (tests). Back-off still applies per operation.
final foregroundSyncIntervalProvider =
    Provider<Duration?>((ref) => const Duration(minutes: 2));

/// Starts sync when an operation is saved, connectivity returns, the
/// vendor signs in (or unlocks) and on a foreground timer. Resume is
/// handled by the app's lifecycle listener. Never shows dialogs.
class SyncTriggers extends ConsumerStatefulWidget {
  final Widget child;
  const SyncTriggers({super.key, required this.child});

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers> {
  Timer? _timer;

  void _request() => ref.read(syncEngineProvider.notifier).requestSync();

  @override
  void initState() {
    super.initState();
    final every = ref.read(foregroundSyncIntervalProvider);
    if (every != null) _timer = Timer.periodic(every, (_) => _request());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _request();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next.valueOrNull is SignedIn && previous?.valueOrNull is! SignedIn) {
        _request();
      }
    });
    // A newly saved operation.
    ref.listen(queueCountsProvider, (previous, next) {
      final before = previous?.valueOrNull?.pending ?? 0;
      if ((next.valueOrNull?.pending ?? 0) > before) _request();
    });
    ref.listen(connectivityProvider, (previous, next) {
      if (next.valueOrNull == true && previous?.valueOrNull != true) {
        _request();
      }
    });
    return widget.child;
  }
}
