import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/supplier/screens.dart';

class _Due extends LocalRepository {
  List<dynamic> due;
  final writes = <String>[];
  _Due(this.due);
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/stock/due') return due;
    if (path == '/supplier/stock/s1') {
      return {
        'id': 's1',
        'category': 'broilers',
        'unit_type': 'bird',
        'listing_status': 'needs_confirmation',
        'photos': <String>[],
        'specs': <String, dynamic>{},
        'region': 'Pwani',
        'quantity_total': '10',
        'quantity_reserved': '0',
        'quantity_sold': '0',
        'quantity_available': '10',
        'farmer_asking_price_per_unit': '9000',
      };
    }
    return super.read(path, query);
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    writes.add(path);
    due = [];
    return {'confirmed': 2};
  }
}

Widget _app(_Due repository, Widget home) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: omoterraTheme(), home: Scaffold(body: home)));

void main() {
  testWidgets('one tap confirms everything that is due', (tester) async {
    final repository = _Due([
      {'id': 'a'},
      {'id': 'b'}
    ]);
    await tester.pumpWidget(_app(repository, const StockScreen()));
    await tester.pumpAndSettle();
    expect(find.text('2 listings need confirming'), findsOneWidget);
    await tester.tap(find.text('Everything is still available'));
    await tester.pumpAndSettle();
    expect(repository.writes, ['/supplier/stock/confirm-due']);
    expect(find.byKey(const Key('confirm_due_banner')), findsNothing);
  });

  testWidgets('no banner when nothing is due', (tester) async {
    await tester.pumpWidget(_app(_Due([]), const StockScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm_due_banner')), findsNothing);
  });

  testWidgets('opening a reminder asks "still available?" once',
      (tester) async {
    await tester
        .pumpWidget(_app(_Due([]), const StockDetail('s1', askConfirm: true)));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your stock'), findsOneWidget);
    Navigator.of(tester.element(find.text('Confirm your stock'))).pop();
    await tester.pumpAndSettle();
    // A reload of the stock does not ask again.
    await tester.tap(find.byTooltip('Refresh stock'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your stock'), findsNothing);
  });
}
