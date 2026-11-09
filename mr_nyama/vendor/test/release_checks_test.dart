import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/client_id.dart';
import 'package:mr_nyama_vendor/core/api/http_vendor_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';

import 'fakes.dart';

/// Answers every request the same way: a status, or a failed connection.
class _Server implements HttpClientAdapter {
  final int? status;
  final DioExceptionType? failure;
  _Server({this.status, this.failure});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(jsonEncode({'error': 'boom'}), status!,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

Future<AuthFailure> _failure(_Server server) async {
  final repo = HttpVendorRepository(
      baseUrl: 'https://api.test',
      store: InMemoryStore(),
      dio: Dio()..httpClientAdapter = server);
  try {
    await repo.signIn(phone: '+255712345678', pin: '2580');
  } on AuthFailure catch (failure) {
    return failure;
  }
  fail('sign-in should have failed');
}

void main() {
  group('RetryId', () {
    test('the same details keep the id, changed details get a new one', () {
      final retry = RetryId();
      final first = retry.forDetails('v1|2026-10-31|2000');
      expect(retry.forDetails('v1|2026-10-31|2000'), first);
      final changed = retry.forDetails('v1|2026-10-31|1500');
      expect(changed, isNot(first));
      expect(retry.forDetails('v1|2026-10-31|2000'), isNot(first));
    });

    test('ids are version 4 UUIDs the server accepts', () {
      expect(
          newClientId(),
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
  });

  group('a server problem is not called "no internet"', () {
    const s = Strings('sw');

    test('no connection says no internet', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
      ]) {
        final failure = await _failure(_Server(failure: type));
        expect(failure.serviceProblem, isFalse, reason: '$type');
        expect(s.failure(failure), s.errOffline);
      }
    });

    test('a server error or a slow answer says the service has a problem',
        () async {
      for (final server in [
        _Server(status: 500),
        _Server(status: 503),
        _Server(failure: DioExceptionType.receiveTimeout),
      ]) {
        final failure = await _failure(server);
        expect(failure.kind, AuthFailureKind.offline);
        expect(failure.serviceProblem, isTrue);
        expect(s.failure(failure), s.errService);
      }
    });
  });
}
