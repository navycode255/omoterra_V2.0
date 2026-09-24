import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/shared/widgets/components.dart';

void main() {
  testWidgets('server failures are distinct from supplier review notices',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorState(
          const ApiFailure(
              'Omoterra is temporarily unavailable. Please try again shortly.'),
        ),
      ),
    ));

    expect(find.text('Omoterra is having a short delay'), findsOneWidget);
    expect(find.text('Registration under review'), findsNothing);
  });

  testWidgets('technical failures use friendly copy and a working retry',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorState(
          const ApiFailure('Proxy server returned HTTP 502 at /api/v1/items'),
          retry: () => retried = true,
        ),
      ),
    ));

    expect(find.text('We couldn’t complete that'), findsOneWidget);
    expect(find.textContaining('server'), findsNothing);
    expect(find.textContaining('/api/v1'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
