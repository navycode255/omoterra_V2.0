import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/domain.dart';

const storage = FlutterSecureStorage();
const apiUrl = String.fromEnvironment('API_BASE_URL');
String newKey() => const Uuid().v4();

class ApiFailure implements Exception {
  final String message;
  const ApiFailure(this.message);
  @override
  String toString() => message;
}

abstract class OmoterraRepository {
  Future<dynamic> read(String path, [Map<String, dynamic>? query]);
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key});
  Future<List<SupplyListing>> listings(Map<String, dynamic> query);
  Future<String> uploadPhoto(List<int> bytes);
}

class ApiRepository implements OmoterraRepository {
  final Dio dio;
  ApiRepository(this.dio);
  Future<dynamic> _request(String path, String method,
      {dynamic data, Map<String, dynamic>? query, String? key}) async {
    if (apiUrl.isEmpty) {
      throw const ApiFailure(
          'Set API_BASE_URL to connect to Omoterra. No action has been submitted.');
    }
    try {
      final token = await storage.read(key: 'session');
      final response = await dio.request(path,
          data: data,
          queryParameters: query,
          options: Options(method: method, headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            if (key != null) 'Idempotency-Key': key,
          }));
      return response.data;
    } on DioException catch (error) {
      final detail =
          error.response?.data is Map ? error.response?.data['detail'] : null;
      if (error.response?.statusCode == 401) {
        throw const ApiFailure(
            'Your session has expired. Sign in again from Account.');
      }
      if (detail is String) throw ApiFailure(detail);
      if (detail is List && detail.isNotEmpty) {
        throw ApiFailure(detail.map((e) => e['msg'].toString()).join('\n'));
      }
      throw const ApiFailure(
          'We could not reach Omoterra. Check your connection and retry. Your action is not confirmed.');
    }
  }

  @override
  Future<String> uploadPhoto(List<int> bytes) async {
    final response = await _request('/media', 'POST',
        data: FormData.fromMap(
            {'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg')}));
    return response['url'] as String;
  }

  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) =>
      _request(path, 'GET', query: query);
  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
          {String method = 'POST', String? key}) =>
      _request(path, method, data: data, key: key);
  @override
  Future<List<SupplyListing>> listings(Map<String, dynamic> query) async =>
      (await read('/listings', query) as List)
          .map((e) => SupplyListing.fromJson(Map<String, dynamic>.from(e)))
          .toList();
}

/// Read-only fixtures are explicitly opt-in; transactions always fail closed.
class LocalRepository implements OmoterraRepository {
  @override
  Future<String> uploadPhoto(List<int> bytes) async =>
      throw const ApiFailure('Connect the API to upload photos.');
  @override
  Future<List<SupplyListing>> listings(Map<String, dynamic> query) async => [
        const SupplyListing(
            id: 'local-broilers',
            category: 'broilers',
            unitType: 'bird',
            region: 'Dar es Salaam',
            price: '18500',
            available: '180',
            specs: {
              'avg_weight_kg': '1.8–2.2',
              'live_or_dressed': 'live',
              'ready_date': 'On confirmation'
            }),
        const SupplyListing(
            id: 'local-beef',
            category: 'beef',
            unitType: 'kg',
            region: 'Pwani',
            price: '14000',
            available: '75',
            specs: {'cut_type': 'Mixed cuts', 'chilled_or_frozen': 'chilled'}),
      ]
          .where((e) =>
              query['category'] == null || query['category'] == e.category)
          .toList();
  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/config') {
      return {
        'payment_methods': ['pay_on_delivery'],
        'media_upload_enabled': false
      };
    }
    throw const ApiFailure(
        'This preview has no account data. Connect the API to continue.');
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
          {String method = 'POST', String? key}) async =>
      throw const ApiFailure(
          'Preview mode cannot submit transactions. Connect the API to continue.');
}

final repositoryProvider = Provider<OmoterraRepository>((ref) {
  if (const bool.fromEnvironment('LOCAL_PREVIEW')) return LocalRepository();
  return ApiRepository(Dio(BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20))));
});
final resourceProvider = FutureProvider.autoDispose.family<dynamic, String>(
    (ref, path) => ref.watch(repositoryProvider).read(path));
final listingsProvider = FutureProvider.autoDispose
    .family<List<SupplyListing>, String>((ref, category) => ref
        .watch(repositoryProvider)
        .listings({if (category.isNotEmpty) 'category': category}));
