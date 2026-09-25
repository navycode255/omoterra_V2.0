import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/features/account/delete_account_screen.dart';

class _RecordingRepository extends LocalRepository {
  final calls = <(String, String)>[];
  Object? failure;
  _RecordingRepository({this.failure});

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    calls.add((path, method));
    if (failure != null) throw failure!;
    if (path == '/auth/logout') return null;
    return null;
  }
}

Widget _host(_RecordingRepository repository) => ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repository)],
    child:
        MaterialApp(theme: omoterraTheme(), home: const DeleteAccountScreen()));

void main() {
  testWidgets('the delete button stays off until DELETE is typed exactly',
      (tester) async {
    await tester.pumpWidget(_host(_RecordingRepository()));
    final button = find.widgetWithText(FilledButton, 'Delete my account');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('delete_confirm_field')), 'please delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('delete_confirm_field')), 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('confirming sends a DELETE to /me and logs out', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(_host(repository));
    await tester.enterText(
        find.byKey(const Key('delete_confirm_field')), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.calls, contains(('/me', 'DELETE')));
    expect(repository.calls, contains(('/auth/logout', 'POST')));
  });

  testWidgets(
      'a server block (open order, pending payout) is shown, not silently retried',
      (tester) async {
    final repository = _RecordingRepository(
        failure: const ApiFailure(
            'You have an order in progress. Wait for it to finish or cancel it before deleting your account.'));
    await tester.pumpWidget(_host(repository));
    await tester.enterText(
        find.byKey(const Key('delete_confirm_field')), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'You have an order in progress. Wait for it to finish or cancel it before deleting your account.'),
        findsOneWidget);
    // The account was not logged out of after a failed deletion.
    expect(repository.calls.where((c) => c.$1 == '/auth/logout'), isEmpty);
  });
}
