import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';

class _MediaRepository extends LocalRepository {
  final String status;
  final writes = <(String, Map<String, dynamic>, String)>[];
  _MediaRepository(this.status);

  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/stock/s1') {
      return {
        'id': 's1',
        'category': 'broilers',
        'listing_status': status,
        'photos': <String>[],
        'video': '/media/clip',
      };
    }
    return super.read(path, query);
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    writes.add((path, data, method));
    return {'id': 's1'};
  }
}

Future<_MediaRepository> _open(WidgetTester tester, String status) async {
  final repository = _MediaRepository(status);
  await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
          theme: omoterraTheme(), home: const StockMediaScreen('s1'))));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets(
      'supplier removes a video from live stock and is told it goes back to review',
      (tester) async {
    final repository = await _open(tester, 'live');
    expect(find.text('Watch video'), findsOneWidget);
    expect(find.byKey(const Key('media_review_notice')), findsNothing);

    await tester.tap(find.text('Remove video'));
    await tester.pumpAndSettle();
    expect(find.text('Add video'), findsOneWidget);
    expect(find.byKey(const Key('media_review_notice')), findsOneWidget);

    await tester.tap(find.text('Save photos & video'));
    await tester.pumpAndSettle();
    expect(repository.writes.single.$1, '/supplier/stock/s1/media');
    expect(repository.writes.single.$2, {'photos': <String>[], 'video': null});
    expect(repository.writes.single.$3, 'PUT');
  });

  testWidgets('stock still in review changes media without the warning',
      (tester) async {
    await _open(tester, 'pending_review');
    await tester.tap(find.text('Remove video'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media_review_notice')), findsNothing);
  });
}
