import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/sync/sync_engine.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/features/home/dashboard.dart';
import 'package:mr_nyama_vendor/features/sales/sales_store.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';
import 'helpers.dart';

class FixedSyncEngine extends SyncEngine {
  final bool running;
  FixedSyncEngine(this.running);
  @override
  SyncState build() => SyncState(running: running);
}

void main() {
  for (final (queue, legacy, running, status, count) in [
    (const QueueCounts(0, 0), 0, false, MNSyncStatus.sent, 0),
    (const QueueCounts(3, 0), 3, false, MNSyncStatus.waiting, 3),
    (const QueueCounts(1, 2), 1, false, MNSyncStatus.attention, 3),
    (const QueueCounts(0, 0), 3, false, MNSyncStatus.waiting, 3),
    (const QueueCounts(3, 0), 3, true, MNSyncStatus.sending, 3),
  ]) {
    test('real count selection: $status with $count outstanding', () async {
      final container = ProviderContainer(overrides: [
        queueCountsProvider.overrideWith((ref) => Stream.value(queue)),
        unsentCountProvider.overrideWith((ref) => Stream.value(legacy)),
        syncEngineProvider.overrideWith(() => FixedSyncEngine(running)),
      ]);
      addTearDown(container.dispose);
      container.listen(syncStatusProvider, (_, __) {});
      await container.read(queueCountsProvider.future);
      await container.read(unsentCountProvider.future);
      expect(container.read(syncStatusProvider), status);
      expect(container.read(syncOutstandingCountProvider), count);
    });
  }

  test('loading and failed queue reads never show the all-sent state',
      () async {
    for (final source in [
      const Stream<QueueCounts>.empty(),
      Stream<QueueCounts>.error(StateError('local queue unavailable'))
    ]) {
      final container = ProviderContainer(overrides: [
        queueCountsProvider.overrideWith((ref) => source),
        unsentCountProvider.overrideWith((ref) => Stream.value(0)),
        syncEngineProvider.overrideWith(() => FixedSyncEngine(false)),
      ]);
      container.listen(syncStatusProvider, (_, __) {});
      await container.read(unsentCountProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(syncStatusProvider), MNSyncStatus.unknown);
      container.dispose();
    }
  });

  test('a failed queue stream cannot retain a previously green state',
      () async {
    final queue = StreamController<QueueCounts>();
    final container = ProviderContainer(overrides: [
      queueCountsProvider.overrideWith((ref) => queue.stream),
      unsentCountProvider.overrideWith((ref) => Stream.value(0)),
      syncEngineProvider.overrideWith(() => FixedSyncEngine(false)),
    ]);
    container.listen(syncStatusProvider, (_, __) {});
    queue.add(const QueueCounts(0, 0));
    await container.read(queueCountsProvider.future);
    await container.read(unsentCountProvider.future);
    expect(container.read(syncStatusProvider), MNSyncStatus.sent);
    queue.addError(StateError('queue read failed'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(syncStatusProvider), MNSyncStatus.unknown);
    container.dispose();
    await queue.close();
  });

  testWidgets(
      'unsynced uses the reference cloud, red count and one accessible tap target',
      (tester) async {
    setScreen(tester);
    var tapped = false;
    await tester.pumpWidget(wrap(MNSyncIndicator(
        status: MNSyncStatus.waiting,
        pendingCount: 3,
        compact: true,
        onTap: () => tapped = true)));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(tester.widget<MNSyncGlyph>(find.byType(MNSyncGlyph)).color,
        MNColors.syncPending);
    expect(tester.getSize(find.byType(MNSyncIndicator)).height,
        greaterThanOrEqualTo(48));
    final semantics = tester.getSemantics(find.byType(MNSyncIndicator));
    expect(semantics.value, contains('3'));
    await tester.tap(find.byType(MNSyncIndicator));
    expect(tapped, isTrue);
  });

  testWidgets('only the syncing arrows animate, and reduced motion stops them',
      (tester) async {
    setScreen(tester);
    await tester.pumpWidget(wrap(
        const MNSyncIndicator(status: MNSyncStatus.sending, compact: true)));
    await tester.pump();
    final before = tester
        .widget<RotationTransition>(find.descendant(
            of: find.byType(MNSyncGlyph),
            matching: find.byType(RotationTransition)))
        .turns
        .value;
    await tester.pump(const Duration(milliseconds: 200));
    final after = tester
        .widget<RotationTransition>(find.descendant(
            of: find.byType(MNSyncGlyph),
            matching: find.byType(RotationTransition)))
        .turns
        .value;
    expect(after, isNot(before));
    expect(tester.widget<MNSyncGlyph>(find.byType(MNSyncGlyph)).color,
        MNColors.syncSending);
    setScreen(tester, reducedMotion: true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RotationTransition>(find.descendant(
                of: find.byType(MNSyncGlyph),
                matching: find.byType(RotationTransition)))
            .turns
            .value,
        0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('sync state preview uses real widgets on light and dark surfaces',
      (tester) async {
    setScreen(tester, size: const Size(400, 320), reducedMotion: true);
    await tester.pumpWidget(wrap(Scaffold(
        body: RepaintBoundary(
            key: const Key('sync-preview'),
            child: Column(children: [
              for (final dark in [false, true])
                ColoredBox(
                    color: dark ? MNColors.black : MNColors.white,
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(children: [
                          for (final status in [
                            MNSyncStatus.sent,
                            MNSyncStatus.sending,
                            MNSyncStatus.waiting
                          ])
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: MNSyncIndicator(
                                        status: status,
                                        pendingCount: 3,
                                        onDark: dark))),
                        ]))),
            ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('sync-preview')));
    final rendered =
        (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    final bytes = await tester
        .runAsync(() => rendered.toByteData(format: ui.ImageByteFormat.png));
    await tester.runAsync(() async {
      final folder = Directory('../../output/vendor-sync-previews');
      await folder.create(recursive: true);
      await File('${folder.path}/sync-states.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
    rendered.dispose();
  });
}
