import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/domain.dart';

const storage = FlutterSecureStorage();
const apiUrl = String.fromEnvironment('API_BASE_URL');

/// Offline design preview, enabled with --dart-define=LOCAL_PREVIEW=true.
/// Reads are fixtures and every transactional write fails closed.
const localPreview = bool.fromEnvironment('LOCAL_PREVIEW');

/// With LOCAL_PREVIEW, start at the phone screen rather than signed in, so the
/// onboarding flow itself can be walked through offline.
const previewOnboarding = bool.fromEnvironment('PREVIEW_ONBOARDING');
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

  /// Uploads a stock video from [path] (or [bytes] where there is no file
  /// system, on web) and returns its `/media/…` URL.
  Future<String> uploadVideo(
      {String? path,
      List<int>? bytes,
      void Function(int sent, int total)? onProgress});
}

class ApiRepository implements OmoterraRepository {
  final Dio dio;
  ApiRepository(this.dio);
  Future<dynamic> _request(String path, String method,
      {dynamic data,
      Map<String, dynamic>? query,
      String? key,
      Duration? receiveTimeout,
      ProgressCallback? onSendProgress}) async {
    if (apiUrl.isEmpty) {
      throw const ApiFailure(
          'Set API_BASE_URL to connect to Omoterra. No action has been submitted.');
    }
    try {
      final token = await storage.read(key: 'session');
      final response = await dio.request(path,
          data: data,
          queryParameters: query,
          onSendProgress: onSendProgress,
          options:
              Options(method: method, receiveTimeout: receiveTimeout, headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            if (key != null) 'Idempotency-Key': key,
          }));
      return response.data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final detail =
          error.response?.data is Map ? error.response?.data['detail'] : null;
      if (statusCode != null && statusCode >= 500) {
        throw const ApiFailure(
            'Omoterra is temporarily unavailable. Please try again shortly.');
      }
      if (statusCode == 401) {
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
  Future<String> uploadVideo(
      {String? path,
      List<int>? bytes,
      void Function(int sent, int total)? onProgress}) async {
    final file = path != null
        ? await MultipartFile.fromFile(path, filename: 'stock-video.mp4')
        : MultipartFile.fromBytes(bytes!, filename: 'stock-video.mp4');
    final response = await _request('/media/video', 'POST',
        data: FormData.fromMap({'file': file}),
        // The server is still writing the file after the last byte is sent.
        receiveTimeout: const Duration(minutes: 2),
        onSendProgress: onProgress);
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

/// Offline design-preview repository, enabled with
/// `--dart-define=LOCAL_PREVIEW=true`. It serves read-only fixtures so every
/// screen can be walked through without running the backend.
///
/// Reads are fake. Writes always fail closed: an order, payment, reservation
/// or stock change can never appear to succeed here, because only the server
/// can decide those. Delete this class once a staging backend exists.
class LocalRepository implements OmoterraRepository {
  static const _unavailable =
      'Preview mode cannot submit transactions. Connect the API to continue.';

  static final _listings = <SupplyListing>[
    const SupplyListing(
        id: 'local-broilers',
        category: 'broilers',
        unitType: 'bird',
        region: 'Kibaha, Pwani',
        price: '11000',
        available: '240',
        specs: {
          'avg_weight_kg': '1.8–2.2',
          'breed_type': 'Broiler',
          'age_weeks': '7',
          'live_or_dressed': 'live',
          'ready_date': 'Today'
        }),
    const SupplyListing(
        id: 'local-chicken',
        category: 'local_chicken',
        unitType: 'bird',
        region: 'Morogoro',
        price: '18000',
        available: '75',
        specs: {
          'avg_weight_kg': '1.2–1.8',
          'breed_type': 'Local',
          'live_or_dressed': 'live',
          'ready_date': 'Tomorrow'
        }),
    const SupplyListing(
        id: 'local-goats',
        category: 'goats',
        unitType: 'animal',
        region: 'Dodoma',
        price: '165000',
        available: '18',
        specs: {
          'weight_range': '25–35 kg',
          'breed': 'Local cross',
          'sex': 'male',
          'ready_date': 'This week'
        }),
    const SupplyListing(
        id: 'local-cattle',
        category: 'cattle',
        unitType: 'animal',
        region: 'Pwani',
        price: '1500000',
        available: '6',
        specs: {
          'weight_range': '250–320 kg',
          'breed': 'Boran cross',
          'sex': 'male',
          'ready_date': 'This week'
        }),
    const SupplyListing(
        id: 'local-eggs',
        category: 'eggs',
        unitType: 'tray',
        region: 'Dar es Salaam',
        price: '9500',
        available: '40',
        specs: {
          'tray_size': '30',
          'egg_size': 'medium',
          'ready_date': 'Today'
        }),
  ];

  static const _supplier = {
    'public_alias': 'Lake Zone Poultry',
    'region': 'Kibaha, Pwani',
    'approval': 'Omoterra Approved',
    'completed_supplies_count': 18,
  };

  Map<String, dynamic> _listingJson(SupplyListing l) => {
        'id': l.id,
        'category': l.category,
        'unit_type': l.unitType,
        'region': l.region,
        'photos': <String>[],
        'specs': l.specs,
        'buyer_price_per_unit': l.price,
        'quantity_available': l.available,
        'supplier': _supplier,
      };

  @override
  Future<String> uploadPhoto(List<int> bytes) async =>
      throw const ApiFailure(_unavailable);

  @override
  Future<String> uploadVideo(
          {String? path,
          List<int>? bytes,
          void Function(int sent, int total)? onProgress}) async =>
      throw const ApiFailure(_unavailable);

  @override
  Future<List<SupplyListing>> listings(Map<String, dynamic> query) async =>
      _listings
          .where((e) =>
              query['category'] == null ||
              '${query['category']}'.isEmpty ||
              query['category'] == e.category)
          .toList();

  @override
  Future<dynamic> read(String path, [Map<String, dynamic>? query]) async {
    if (path == '/supplier/reputation') {
      return {
        'rating': 4.6,
        'ratings': 12,
        'deliveries': 18,
        'quality_passed': 97,
        'minimum_ratings': 3,
        'reviews': [
          {
            'id': 'preview-review-1',
            'stars': 5,
            'comment': 'Healthy birds and collected on time.',
            'created_at': DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
          },
        ],
      };
    }
    if (path == '/notifications') {
      return {
        'unread': 1,
        'items': [
          {
            'id': 'preview-note-1',
            'role': 'buyer',
            'kind': 'order_in_transit',
            'title': 'Order on the way',
            'body': 'Your order has left for delivery.',
            'link': '/orders',
            'read': false,
            'created_at': DateTime.now()
                .subtract(const Duration(minutes: 20))
                .toIso8601String(),
          },
        ],
      };
    }
    if (path == '/config') {
      return {
        'payment_methods': ['pay_on_delivery'],
        'media_upload_enabled': false,
        'otp_length': 6,
        'support_phone': '',
        'terms_text': '',
        'privacy_text': '',
      };
    }
    // A signed-in account so the preview opens past the login wall.
    if (path == '/me') {
      return {
        'id': 'local-user',
        'phone': '+255746484666',
        'name': 'Preview Account',
        'region': 'Dar es Salaam',
        'language': 'en',
        'roles': ['buyer', 'supplier'],
        'buyer_type': 'restaurant',
      };
    }
    if (path == '/listings') {
      return _listings.map(_listingJson).toList();
    }
    if (path.startsWith('/listings/')) {
      final id = path.split('/').last;
      final match = _listings.firstWhere((l) => l.id == id,
          orElse: () => _listings.first);
      return _listingJson(match);
    }
    if (path == '/addresses') {
      return [
        {
          'id': 'local-address',
          'label': 'Restaurant',
          'recipient_name': 'Preview Account',
          'phone': '+255746484666',
          'region': 'Dar es Salaam',
          'district_area': 'Masaki',
          'address_text': '12 Chole Road, Masaki',
        }
      ];
    }
    if (path == '/supplier/profile') {
      return {
        'public_alias': _supplier['public_alias'],
        'alias_approved': true,
        'legal_name': 'Preview Supplier Ltd',
        'internal_pickup_address': 'Preview pickup address',
        'completed_supplies_count': _supplier['completed_supplies_count'],
        'status': 'approved',
      };
    }
    if (path == '/supplier/demand' || path.startsWith('/supplier/demand/')) {
      final today = DateTime.now();
      final rows = [
        for (var i = 0; i < 3; i++)
          {
            'id': 'preview-demand-${i + 1}',
            'category': i == 2 ? 'goats' : 'broilers',
            'unit': i == 2 ? 'animals' : 'birds',
            'form': 'Live',
            'quantity': [500, 200, 300][i],
            'matched': [320, 0, 150][i],
            'weight': ['1.8–2.2', '1.8+', '25–35'][i],
            'region': ['Dar es Salaam', 'Mbezi, Dar es Salaam', 'Kinondoni'][i],
            'needed_by': today
                .add(Duration(days: 6 + i * 2))
                .toIso8601String()
                .split('T')
                .first,
            'repeating': i == 1,
            if (i == 1) 'schedule': 'Every Monday',
            'buyer_type': 'Restaurant / Food Service',
            'notes':
                'Uniform size preferred. Good health and clean birds. Delivery to our location.',
          },
      ];
      if (path == '/supplier/demand') return rows;
      return rows.firstWhere((row) => row['id'] == path.split('/').last,
          orElse: () =>
              throw const ApiFailure('Demand is no longer available.'));
    }
    if (path == '/supplier/batches') {
      final today = DateTime.now();
      return [
        {
          'id': 'preview-batch-broilers',
          'category': 'broilers',
          'initial_quantity': '180',
          'current_quantity': '180',
          'reserved_quantity': '0',
          'available_to_commit': '180',
          'expected_ready_date': today
              .add(const Duration(days: 5))
              .toIso8601String()
              .split('T')
              .first,
          'expected_min_weight_kg': '1.8',
          'expected_max_weight_kg': '2.2',
          'status': 'growing',
          'approved_at': null,
        },
        {
          'id': 'preview-batch-goats',
          'category': 'goats',
          'initial_quantity': '24',
          'current_quantity': '24',
          'reserved_quantity': '0',
          'available_to_commit': '24',
          'expected_ready_date': today
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')
              .first,
          'expected_min_weight_kg': '25',
          'expected_max_weight_kg': '35',
          'status': 'growing',
          'approved_at': null,
        },
      ];
    }
    if (path == '/supplier/stock') {
      return [
        {
          'id': 'local-stock-1',
          'category': 'broilers',
          'unit_type': 'bird',
          'region': 'Kibaha, Pwani',
          'photos': <String>[],
          'specs': const {'avg_weight_kg': '1.9–2.2', 'age_weeks': '7'},
          'farmer_asking_price_per_unit': '9500',
          'quantity_total': '300',
          'quantity_reserved': '100',
          'quantity_sold': '0',
          'quantity_available': '200',
          'listing_status': 'live',
          'confirmation_due_at': null,
        },
        {
          'id': 'local-stock-2',
          'category': 'goats',
          'unit_type': 'animal',
          'region': 'Dodoma',
          'photos': <String>[],
          'specs': const {'weight_range': '25–35 kg'},
          'farmer_asking_price_per_unit': '145000',
          'quantity_total': '25',
          'quantity_reserved': '0',
          'quantity_sold': '0',
          'quantity_available': '25',
          'listing_status': 'pending_review',
          'confirmation_due_at': null,
        },
      ];
    }
    // Lists the app renders as empty rather than failing.
    if (path == '/orders' ||
        path == '/requests' ||
        path == '/supplier/payouts' ||
        path == '/supplier/orders' ||
        path == '/supplier/sales' ||
        path.endsWith('/history')) {
      return <dynamic>[];
    }
    throw const ApiFailure(
        'This screen needs live data. Connect the API to continue.');
  }

  @override
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key}) async {
    // Sign-in and onboarding are allowed to "succeed" offline: they move
    // nothing of value, and without them no screen can be reached at all.
    // Anything that touches stock, money or an order still fails closed.
    if (path == '/me') return read('/me');
    if (path == '/auth/logout') return null;
    if (path == '/auth/otp') {
      return {
        'challenge_id': 'preview-challenge',
        'otp_length': 6,
        'resend_after_seconds': 60,
        // Shown on screen in development, exactly as the real backend does.
        'development_code': '123456',
      };
    }
    if (path == '/auth/verify') {
      return {
        'access_token': 'preview-token',
        'user': await read('/me'),
      };
    }
    throw const ApiFailure(_unavailable);
  }
}

final repositoryProvider = Provider<OmoterraRepository>((ref) {
  if (localPreview) return LocalRepository();
  return ApiRepository(Dio(BaseOptions(
      baseUrl: apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20))));
});
final resourceFailuresProvider =
    StateProvider<Map<String, Object>>((ref) => const {});

final resourceProvider =
    FutureProvider.autoDispose.family<dynamic, String>((ref, path) async {
  final failures = ref.read(resourceFailuresProvider.notifier);
  ref.onDispose(() {
    if (failures.state.containsKey(path)) {
      failures.state = {...failures.state}..remove(path);
    }
  });
  try {
    final value = await ref.watch(repositoryProvider).read(path);
    if (failures.state.containsKey(path)) {
      failures.state = {...failures.state}..remove(path);
    }
    return value;
  } catch (error) {
    failures.state = {...failures.state, path: error};
    rethrow;
  }
});
final listingsProvider = FutureProvider.autoDispose
    .family<List<SupplyListing>, String>((ref, category) async {
  final failureKey = '@listing|$category';
  final failures = ref.read(resourceFailuresProvider.notifier);
  ref.onDispose(() {
    if (failures.state.containsKey(failureKey)) {
      failures.state = {...failures.state}..remove(failureKey);
    }
  });
  try {
    final rows = await ref.watch(repositoryProvider).listings({
      if (category.isNotEmpty) 'category': category,
    });
    if (failures.state.containsKey(failureKey)) {
      failures.state = {...failures.state}..remove(failureKey);
    }
    return rows;
  } catch (error) {
    failures.state = {...failures.state, failureKey: error};
    rethrow;
  }
});
