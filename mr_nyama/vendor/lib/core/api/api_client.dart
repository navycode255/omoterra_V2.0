import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../auth/secure_store.dart';
import 'vendor_repository.dart';

/// HTTP plumbing shared by the vendor and office sides of the app: one base
/// URL (`…/api/v1`), one sign-in audience (`/vendor` or `/staff`) and its own
/// tokens in [KeyValueStore] under [keyPrefix].
///
/// The server issues a short access token (15 min) and a refresh token that
/// rotates on every use. [authed] refreshes the access token once per expiry
/// (single flight) and reports [AuthFailureKind.sessionExpired] only when the
/// server refuses the refresh. PINs and codes are never stored or logged.
class ApiClient {
  static const _device = 'api_device_id';

  final Dio _dio;
  final KeyValueStore _store;

  /// `/vendor` or `/staff`: where this audience's `auth/*` routes live.
  final String audience;
  final String keyPrefix;
  Future<bool>? _refreshing;

  ApiClient(
      {required String baseUrl,
      required KeyValueStore store,
      required this.audience,
      required this.keyPrefix,
      Dio? dio})
      : _store = store,
        _dio = dio ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30))) {
    _dio.options.baseUrl =
        baseUrl.endsWith('/') ? '${baseUrl}api/v1' : '$baseUrl/api/v1';
    _dio.options.contentType = Headers.jsonContentType;
    // Every status reaches [fail]: errors carry the server's machine codes.
    _dio.options.validateStatus = (_) => true;
  }

  String get _accessKey => '${keyPrefix}_access_token';
  String get _refreshKey => '${keyPrefix}_refresh_token';

  Future<String> deviceId() async {
    final existing = await _store.read(_device);
    if (existing != null && existing.length >= 8) return existing;
    final id = 'mn-${const Uuid().v4()}';
    await _store.write(_device, id);
    return id;
  }

  Future<bool> get hasSession async => await _store.read(_refreshKey) != null;

  Future<void> saveTokens(Map<String, dynamic> body) async {
    await _store.write(_accessKey, body['access_token'] as String);
    await _store.write(_refreshKey, body['refresh_token'] as String);
  }

  Future<void> clearTokens() async {
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
  }

  /// Sends a request; maps network failures to [AuthFailureKind.offline].
  Future<Response<dynamic>> send(String method, String path,
      {Object? body, String? bearer, String? contentType}) async {
    try {
      return await _dio.request<dynamic>(path,
          data: body,
          options: Options(method: method, contentType: contentType, headers: {
            if (bearer != null) 'Authorization': 'Bearer $bearer',
          }));
    } on DioException catch (error) {
      // No connection at all is "no internet"; anything after that is not.
      throw AuthFailure(AuthFailureKind.offline,
          serviceProblem: error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.badResponse ||
              error.type == DioExceptionType.badCertificate);
    }
  }

  /// The server's machine code for a refusal, if any.
  static String? errorCode(Response<dynamic> r) =>
      r.data is Map ? (r.data as Map)['error'] as String? : null;

  /// Turns a refusal into the [AuthFailure] the screens explain.
  Never fail(Response<dynamic> r) {
    final code = errorCode(r);
    final status = r.statusCode ?? 0;
    switch (code) {
      case 'invalid_credentials':
        throw const AuthFailure(AuthFailureKind.wrongPin);
      case 'too_many_attempts':
        final seconds = (r.data as Map)['retry_after_seconds'] as int?;
        throw AuthFailure(AuthFailureKind.locked,
            retryAfter: seconds == null
                ? null
                : DateTime.now().add(Duration(seconds: seconds)));
      case 'account_unavailable':
        throw const AuthFailure(AuthFailureKind.suspended);
      case 'invalid_code' || 'already_activated' || 'not_activated':
        throw const AuthFailure(AuthFailureKind.invalidCode);
      case 'pin_too_simple' || 'pin_format' || 'pin_mismatch':
        throw const AuthFailure(AuthFailureKind.weakPin);
      case 'invalid_session':
        throw const AuthFailure(AuthFailureKind.sessionExpired);
    }
    if (status == 401) throw const AuthFailure(AuthFailureKind.sessionExpired);
    // Anything else (server error, maintenance, a refused request) is shown
    // as a service problem, never as the phone's internet; queued work stays
    // queued and retries.
    throw const AuthFailure(AuthFailureKind.offline, serviceProblem: true);
  }

  Map<String, dynamic> json(Response<dynamic> r) {
    final status = r.statusCode ?? 0;
    if (status < 200 || status >= 300) fail(r);
    return r.data is Map<String, dynamic>
        ? r.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// Uses the refresh token once for every caller waiting on an expired
  /// access token. False when the server refuses it.
  Future<bool> _refreshTokens() {
    return _refreshing ??= () async {
      try {
        final refresh = await _store.read(_refreshKey);
        if (refresh == null) return false;
        final r = await send('POST', '$audience/auth/refresh', body: {
          'refresh_token': refresh,
          'device_id': await deviceId(),
        });
        if (r.statusCode != 200) {
          if (r.statusCode == 401) await clearTokens();
          if (r.statusCode != 401) fail(r);
          return false;
        }
        await saveTokens(r.data as Map<String, dynamic>);
        return true;
      } finally {
        _refreshing = null;
      }
    }();
  }

  /// An authenticated call: refreshes the access token once if it expired.
  Future<Response<dynamic>> authed(String method, String path,
      {Object? body, String? contentType}) async {
    var access = await _store.read(_accessKey);
    if (access == null) {
      if (!await _refreshTokens()) {
        throw const AuthFailure(AuthFailureKind.sessionExpired);
      }
      access = await _store.read(_accessKey);
    }
    var r = await send(method, path,
        body: body, bearer: access, contentType: contentType);
    if (r.statusCode == 401) {
      if (!await _refreshTokens()) {
        throw const AuthFailure(AuthFailureKind.sessionExpired);
      }
      r = await send(method, path,
          body: body,
          bearer: await _store.read(_accessKey),
          contentType: contentType);
    }
    return r;
  }
}
