import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/session.dart';
import 'sync_engine.dart';

const backgroundSyncTask = 'mr_nyama_sync';

/// Runs in a background isolate (Android WorkManager, about every 15
/// minutes, only with a network; it survives device restarts). It uses the
/// same session rules as the app: it syncs only when the stored session is
/// signed in and not PIN-locked, and never asks for anything.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, _) async {
    final container = ProviderContainer();
    try {
      final auth = await container.read(sessionProvider.future);
      if (auth is SignedIn) {
        await container.read(syncEngineProvider.notifier).syncNow();
      }
    } catch (error) {
      // Diagnostics only: the error type, never data or credentials.
      debugPrint('background sync: ${error.runtimeType}');
    } finally {
      container.dispose();
    }
    return true;
  });
}

/// Registers the periodic background sync. Keeps an existing registration.
Future<void> registerBackgroundSync() async {
  await Workmanager().initialize(backgroundSyncDispatcher);
  await Workmanager().registerPeriodicTask(
    backgroundSyncTask,
    backgroundSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
