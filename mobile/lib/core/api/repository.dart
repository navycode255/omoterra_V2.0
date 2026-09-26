import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/domain.dart';
import '../l10n/strings.dart';

const storage = FlutterSecureStorage();

/// Requests made by a signed-in operator (staff sign-in and registering
/// people), authorised by the operator session rather than a member's.
bool isOperatorPath(String path) =>
    path.startsWith('/mobile-admin') || path.startsWith('/referrals');

/// Where photo pickers upload. Staff registration screens override it so the
/// photos belong to the person being registered, not to the phone's member.
final photoUploadPathProvider = Provider<String>((ref) => '/media');
const apiUrl = String.fromEnvironment('API_BASE_URL');

/// Offline design preview, enabled with --dart-define=LOCAL_PREVIEW=true.
/// Reads are fixtures and every transactional write fails closed.
const localPreview = bool.fromEnvironment('LOCAL_PREVIEW');

/// With LOCAL_PREVIEW, start at the phone screen rather than signed in, so the
/// onboarding flow itself can be walked through offline.
const previewOnboarding = bool.fromEnvironment('PREVIEW_ONBOARDING');
String newKey() => const Uuid().v4();

/// Listings per page of buyer search.
const listingPageSize = 20;

class ListingPage {
  final List<SupplyListing> items;

  /// Null on the last page.
  final String? nextCursor;
  const ListingPage(this.items, [this.nextCursor]);
}

/// Why a request failed on this phone, before the server could answer. The
/// app shows its own translated copy for these; [ApiFailure.message] from
/// the server is already in the member's language (see `Accept-Language`).
enum FailureKind {
  notConfigured,
  unavailable,
  sessionExpired,
  staffSessionExpired,
  offline,
  videoPaused
}

class ApiFailure implements Exception {
  final String message;
  final FailureKind? kind;

  /// The HTTP status the server answered with, when it answered. The app
  /// decides how to present a failure from this and [kind], never from the
  /// wording of [message], which is in the member's language.
  final int? status;
  const ApiFailure(this.message, [this.kind, this.status]);
  @override
  String toString() => message;
}

/// A short-lived link to a photo or video, signed by the server after it
/// checked this member may see it. Links change every time; cache the bytes
/// by media id, never by this URL.
class SignedMedia {
  final String url;
  final DateTime expiresAt;
  const SignedMedia(this.url, this.expiresAt);
  factory SignedMedia.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    // R2 links are absolute; links to media on the API server are paths.
    return SignedMedia(url.startsWith('https://') ? url : '$apiUrl$url',
        DateTime.parse(json['expires_at'] as String));
  }
}

/// Size of each resumable video upload part (the server's PART_SIZE).
const videoPartSize = 5 * 1024 * 1024;

/// A video upload that stopped because the connection stayed down. Upload
/// again with [uploadId] to continue from the last stored part.
class VideoUploadPaused extends ApiFailure {
  final String uploadId;
  const VideoUploadPaused(this.uploadId)
      : super(
            'The connection dropped, so the upload is paused. '
            'Tap Resume when you are back online — finished parts are kept.',
            FailureKind.videoPaused);
}

abstract class OmoterraRepository {
  Future<dynamic> read(String path, [Map<String, dynamic>? query]);
  Future<dynamic> write(String path, Map<String, dynamic> data,
      {String method = 'POST', String? key});
  Future<List<SupplyListing>> listings(Map<String, dynamic> query);

  /// One page of buyer search, newest first. [query] holds the search words
  /// (`q`) and filters; pass the previous page's [ListingPage.nextCursor] as
  /// [cursor] for the next page.
  Future<ListingPage> listingPage(Map<String, dynamic> query,
      {String? cursor, int pageSize = listingPageSize});

  /// Uploads a photo to [path]: `/media` for the signed-in member, or
  /// `/referrals/photos` for someone an operator is registering.
  Future<String> uploadPhoto(List<int> bytes, {String path = '/media'});

  /// Uploads a stock video from [path] (or [bytes] where there is no file
  /// system, on web) and returns its `/media/…` URL.
  Future<String> uploadVideo(
      {String? path,
      List<int>? bytes,
      void Function(int sent, int total)? onProgress});

  /// A signed link to the `/media/…` photo or video at [url], or null when
  /// the server refuses (the member may not see it, or it is gone). Throws
  /// [ApiFailure] when Omoterra can't be reached.
  Future<SignedMedia?> mediaLink(String url);

  /// Uploads a stock video of [size] bytes in [videoPartSize] parts straight
  /// to storage and returns its `/media/…` URL. [read] returns the bytes from
  /// start to end. Each part is retried; if the connection stays down this
  /// throws [VideoUploadPaused], and calling again with its uploadId as
  /// [resumeId] continues from the last stored part.
  Future<String> uploadVideoInParts(
      int size, Future<List<int>> Function(int start, int end) read,
      {String? resumeId,
      void Function(String uploadId)? onStarted,
      void Function(int sent, int total)? onProgress});
}

class ApiRepository implements OmoterraRepository {
  final Dio dio;

  /// The member's language (`en` or `sw`), sent as `Accept-Language` on
  /// every request so the server answers errors in that language.
  final String Function() language;
  ApiRepository(this.dio, {String Function()? language})
      : language = language ?? (() => 'en');
  Future<dynamic> _request(String path, String method,
      {dynamic data,
      Map<String, dynamic>? query,
      String? key,
      Duration? receiveTimeout,
      ProgressCallback? onSendProgress}) async {
    if (dio.options.baseUrl.isEmpty) {
      throw const ApiFailure(
          'Set API_BASE_URL to connect to Omoterra. No action has been submitted.',
          FailureKind.notConfigured);
    }
    try {
      // Staff screens act as the signed-in operator, never as the member
      // who may also be signed in on this phone.
      final operator = isOperatorPath(path);
      final token =
          await storage.read(key: operator ? 'operator_session' : 'session');
      final response = await dio.request(path,
          data: data,
          queryParameters: query,
          onSendProgress: onSendProgress,
          options:
              Options(method: method, receiveTimeout: receiveTimeout, headers: {
            'Accept-Language': language(),
            if (token != null && !operator) 'Authorization': 'Bearer $token',
            if (token != null && operator) 'X-Operator-Session': token,
            if (key != null) 'Idempotency-Key': key,
          }));
      return response.data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final detail =
          error.response?.data is Map ? error.response?.data['detail'] : null;
      if (statusCode != null && statusCode >= 500) {
        throw const ApiFailure(
            'Omoterra is temporarily unavailable. Please try again shortly.',
            FailureKind.unavailable);
      }
      if (statusCode == 401) {
        throw isOperatorPath(path)
            ? const ApiFailure('Your staff sign-in has expired. Sign in again.',
                FailureKind.staffSessionExpired)
            : const ApiFailure(
                'Your session has expired. Sign in again from Account.',
                FailureKind.sessionExpired);
      }
      if (detail is String) throw ApiFailure(detail, null, statusCode);
      if (detail is List && detail.isNotEmpty) {
        throw ApiFailure(detail.map((e) => e['msg'].toString()).join('\n'),
            null, statusCode);
      }
      throw const ApiFailure(
          'We could not reach Omoterra. Check your connection and retry. Your action is not confirmed.',
          FailureKind.offline);
    }
  }

  @override
  Future<String> uploadPhoto(List<int> bytes, {String path = '/media'}) async {
    final response = await _request(path, 'POST',
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

  /// GET [path] as the member; null when the server answers 403 or 404.
  Future<Map<String, dynamic>?> _readOrNull(String path) async {
    if (dio.options.baseUrl.isEmpty) {
      throw const ApiFailure('Set API_BASE_URL to connect to Omoterra.',
          FailureKind.notConfigured);
    }
    final token = await storage.read(key: 'session');
    try {
      final response = await dio.get(path,
          options: Options(headers: {
            'Accept-Language': language(),
            if (token != null) 'Authorization': 'Bearer $token'
          }));
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 403 || status == 404) return null;
      throw const ApiFailure(
          'We could not reach Omoterra. Check your connection and retry.',
          FailureKind.offline);
    }
  }

  @override
  Future<SignedMedia?> mediaLink(String url) async {
    // The server refuses to sign media this member may not see.
    final signed = await _readOrNull(url);
    return signed == null ? null : SignedMedia.fromJson(signed);
  }

  Future<Map<String, dynamic>?> _uploadStatus(String id) async {
    try {
      return await _readOrNull('/media/video/uploads/$id');
    } on ApiFailure {
      throw VideoUploadPaused(id);
    }
  }

  /// Waits between attempts at one part: about a minute in all, so turning
  /// mobile data off and on again doesn't stop the upload.
  static const _partRetryDelays = [2, 4, 8, 16, 30];

  @override
  Future<String> uploadVideoInParts(
      int size, Future<List<int>> Function(int start, int end) read,
      {String? resumeId,
      void Function(String uploadId)? onStarted,
      void Function(int sent, int total)? onProgress}) async {
    // A resumed upload the server no longer has (over a day old) starts over.
    var upload = resumeId == null ? null : await _uploadStatus(resumeId);
    upload ??= Map<String, dynamic>.from(
        await _request('/media/video/uploads', 'POST', data: {'size': size}));
    final id = upload['id'] as String;
    onStarted?.call(id);
    final partSize = upload['part_size'] as int;
    final count = upload['parts'] as int;
    int length(int number) =>
        number < count ? partSize : size - partSize * (count - 1);
    // Parts already stored (a resumed upload) keep their ETags.
    final etags = <int, String>{
      for (final part in (upload['uploaded'] as List? ?? const []))
        if (part['size'] == length(part['number'] as int))
          part['number'] as int: part['etag'] as String
    };
    var sent = etags.keys.fold<int>(0, (total, n) => total + length(n));
    onProgress?.call(sent, size);
    if (upload['completed'] != true) {
      final missing = [
        for (var n = 1; n <= count; n++)
          if (!etags.containsKey(n)) n
      ];
      Map<int, String> links;
      try {
        links = await _partLinks(id, missing);
      } on ApiFailure {
        throw VideoUploadPaused(id);
      }
      for (final number in missing) {
        final start = partSize * (number - 1);
        final bytes = await read(start, start + length(number));
        for (var attempt = 0;; attempt++) {
          try {
            final response = await Dio().put<void>(links[number]!,
                data: Stream.fromIterable([bytes]),
                options: Options(headers: {
                  Headers.contentLengthHeader: bytes.length,
                  Headers.contentTypeHeader: 'application/octet-stream',
                }),
                onSendProgress: (partSent, _) =>
                    onProgress?.call(sent + partSent, size));
            etags[number] = response.headers.value('etag')!;
            sent += bytes.length;
            break;
          } on DioException catch (error) {
            if (attempt >= _partRetryDelays.length) {
              throw VideoUploadPaused(id);
            }
            await Future<void>.delayed(
                Duration(seconds: _partRetryDelays[attempt]));
            // An expired part link: sign the rest again.
            if (error.response?.statusCode == 403) {
              try {
                links = await _partLinks(
                    id, missing.where((n) => !etags.containsKey(n)).toList());
              } on ApiFailure {
                // Still offline; the next attempt fails and waits again.
              }
            }
          }
        }
      }
      try {
        await _request('/media/video/uploads/$id/complete', 'POST', data: {
          'parts': [
            for (final e
                in (etags.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key))))
              {'number': e.key, 'etag': e.value}
          ]
        });
      } on ApiFailure {
        // Completed already (the reply was lost) or a part is missing: the
        // status call on resume tells which.
        throw VideoUploadPaused(id);
      }
    }
    final confirmed = await _request('/media/video/confirm', 'POST',
        data: {'upload_id': id},
        // Storage copies the video into place before answering.
        receiveTimeout: const Duration(minutes: 2));
    return confirmed['url'] as String;
  }

  Future<Map<int, String>> _partLinks(String id, List<int> numbers) async {
    if (numbers.isEmpty) return {};
    final signed = await _request('/media/video/uploads/$id/parts', 'POST',
        data: {'numbers': numbers});
    return {
      for (final part in signed['parts'] as List)
        part['number'] as int: SignedMedia.fromJson(
            {'url': part['url'], 'expires_at': signed['expires_at']}).url
    };
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
  @override
  Future<ListingPage> listingPage(Map<String, dynamic> query,
      {String? cursor, int pageSize = listingPageSize}) async {
    final data = await read('/listings', {
      ...query,
      'page_size': pageSize,
      if (cursor != null) 'cursor': cursor,
    });
    List<SupplyListing> parse(List rows) => rows
        .map((e) => SupplyListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // A server from before paging ignores page_size and sends a plain list:
    // show it as the only page rather than failing the whole feed.
    if (data is List) return ListingPage(parse(data));
    final page = Map<String, dynamic>.from(data as Map);
    return ListingPage(
        (page['items'] as List)
            .map((e) => SupplyListing.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page['next_cursor'] as String?);
  }
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
  Future<String> uploadPhoto(List<int> bytes, {String path = '/media'}) async =>
      throw const ApiFailure(_unavailable);

  @override
  Future<String> uploadVideo(
          {String? path,
          List<int>? bytes,
          void Function(int sent, int total)? onProgress}) async =>
      throw const ApiFailure(_unavailable);

  /// Previews have no private media.
  @override
  Future<SignedMedia?> mediaLink(String url) async => null;

  @override
  Future<String> uploadVideoInParts(
          int size, Future<List<int>> Function(int start, int end) read,
          {String? resumeId,
          void Function(String uploadId)? onStarted,
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

  /// Fixtures only: a rough match on category, region and breed, one page.
  @override
  Future<ListingPage> listingPage(Map<String, dynamic> query,
      {String? cursor, int pageSize = listingPageSize}) async {
    final words = '${query['q'] ?? ''}'.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final region = '${query['region'] ?? ''}'.toLowerCase();
    return ListingPage((await listings(query))
        .where((l) =>
            l.region.toLowerCase().contains(region) &&
            words.every((w) => [
                  l.category.replaceAll('_', ' '),
                  l.region,
                  '${l.specs['breed_type'] ?? l.specs['breed'] ?? ''}'
                ].any((field) => field.toLowerCase().contains(w))))
        .toList());
  }

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
  return ApiRepository(
      Dio(BaseOptions(
          baseUrl: apiUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20))),
      // Read on each request, so switching language applies straight away.
      language: () => ref.read(stringsProvider).code);
});
final resourceFailuresProvider =
    StateProvider<Map<String, Object>>((ref) => const {});

final resourceProvider =
    FutureProvider.autoDispose.family<dynamic, String>((ref, path) async {
  final failures = ref.read(resourceFailuresProvider.notifier);
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
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
    // A request still waiting on the network when its screen closed (or was
    // refreshed) must not record a failure nothing is left to retry.
    if (!disposed) failures.state = {...failures.state, path: error};
    rethrow;
  }
});

/// The first page of buyer search. The family key is the search as a query
/// string (see [listingSearchKey]); later pages load through
/// [OmoterraRepository.listingPage] and reset whenever this is refreshed.
final listingsProvider =
    FutureProvider.autoDispose.family<ListingPage, String>((ref, search) async {
  final failureKey = '@listing|$search';
  final failures = ref.read(resourceFailuresProvider.notifier);
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    if (failures.state.containsKey(failureKey)) {
      failures.state = {...failures.state}..remove(failureKey);
    }
  });
  try {
    final page = await ref
        .watch(repositoryProvider)
        .listingPage(Uri.splitQueryString(search));
    if (failures.state.containsKey(failureKey)) {
      failures.state = {...failures.state}..remove(failureKey);
    }
    return page;
  } catch (error) {
    if (!disposed) failures.state = {...failures.state, failureKey: error};
    rethrow;
  }
});

/// A stable key for [listingsProvider]: the non-empty search values as a
/// query string, so equal searches share one request.
String listingSearchKey(Map<String, String?> values) {
  final entries = values.entries
      .where((e) => (e.value ?? '').trim().isNotEmpty)
      .map((e) => MapEntry(e.key, e.value!.trim()))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return Uri(queryParameters: Map.fromEntries(entries)).query;
}
