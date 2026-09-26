import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/core/l10n/strings.dart';
import 'package:omoterra/shared/widgets/components.dart';

void main() {
  testWidgets('server failures are distinct from supplier review notices',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorState(
          const ApiFailure(
              'Omoterra is temporarily unavailable. Please try again shortly.',
              FailureKind.unavailable),
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

  // The server writes its reasons in the member's language, so the app
  // chooses the copy from the HTTP status, never from the words.
  testWidgets('a Swahili 404 reason is shown as written, under a gone title',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorState(
            const ApiFailure('Bidhaa hii haipatikani tena.', null, 404)),
      ),
    ));
    expect(find.text('This is no longer available'), findsOneWidget);
    expect(find.text('Bidhaa hii haipatikani tena.'), findsOneWidget);
  });

  testWidgets('an unknown route and a 5xx get friendly copy in Swahili',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('sw'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('sw')],
      home: const Scaffold(
        body: Column(children: [
          ErrorState(ApiFailure('Not Found', null, 404)),
          ErrorState(ApiFailure('Hitilafu', null, 502)),
        ]),
      ),
    ));
    expect(find.text(const Strings('sw').errNotFoundTitle), findsOneWidget);
    expect(find.text(const Strings('sw').errDelayTitle), findsOneWidget);
    expect(find.text('Hitilafu'), findsNothing);
  });
}
