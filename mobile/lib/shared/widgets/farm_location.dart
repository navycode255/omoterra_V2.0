import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'components.dart';

/// The exact farm pin sent with supplier registration. [url] is the Google
/// Maps link operations open; a map pick gets a generated one.
class FarmLocation {
  final double latitude, longitude;
  final String url;
  const FarmLocation(this.latitude, this.longitude, this.url);
  factory FarmLocation.pinned(LatLng point) =>
      FarmLocation(point.latitude, point.longitude, googleMapsUrl(point));
  LatLng get point => LatLng(latitude, longitude);
  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  Map<String, dynamic> toJson() => {
        'farm_latitude': latitude.toStringAsFixed(6),
        'farm_longitude': longitude.toStringAsFixed(6),
        'farm_map_url': url,
      };
}

String googleMapsUrl(LatLng point) =>
    'https://www.google.com/maps/search/?api=1&query='
    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

final _googleDomain = r'google\.(?:com|[a-z]{2})(?:\.[a-z]{2})?';
final _googleMapsLink = RegExp(
    '^https://(?:(?:www\\.)?$_googleDomain/maps|maps\\.$_googleDomain|'
    'maps\\.app\\.goo\\.gl|goo\\.gl/maps)(?:[/?#]|\$)',
    caseSensitive: false);
bool isGoogleMapsLink(String url) => _googleMapsLink.hasMatch(url);
bool _isShortLink(String url) =>
    RegExp(r'^https://(maps\.app\.goo\.gl|goo\.gl/maps)(/|$)',
            caseSensitive: false)
        .hasMatch(url);

/// The first link in pasted text. Google Maps' share sheet adds the place
/// name before the link, so the whole paste is rarely a bare URL.
String? extractLink(String text) {
  final match = RegExp(r'https?://\S+').firstMatch(text);
  if (match == null) return null;
  return match.group(0)!.replaceFirst(RegExp('^http://'), 'https://');
}

LatLng? _valid(String lat, String lng) {
  final a = double.tryParse(lat), b = double.tryParse(lng);
  if (a == null || b == null) return null;
  if (a.abs() > 90 || b.abs() > 180 || (a == 0 && b == 0)) return null;
  return LatLng(a, b);
}

/// Reads coordinates out of a full Google Maps link: a dropped pin
/// (`!3d..!4d..`), a search or directions query (`q=`, `query=`, `ll=`,
/// `destination=`), a `/place/` or `/search/` path, or the map view (`@`).
LatLng? parseGoogleMapsLocation(String url) {
  final text = Uri.decodeFull(url.replaceAll('+', ' '));
  const number = r'(-?\d{1,3}(?:\.\d+)?)';
  final patterns = [
    RegExp('!3d$number!4d$number'),
    RegExp(
        '[?&](?:q|query|ll|destination|center|daddr)=(?:loc:)?\\s*$number\\s*,\\s*$number'),
    RegExp('/(?:place|search|dir)/$number\\s*,\\s*$number'),
    RegExp('@$number,$number'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    final point = match == null ? null : _valid(match[1]!, match[2]!);
    if (point != null) return point;
  }
  return null;
}

/// Follows a maps.app.goo.gl short link to the full Google Maps link that
/// carries the coordinates. Only ever follows redirects between Google hosts.
Future<String> resolveMapsLink(String url, {Dio? dio}) async {
  if (!_isShortLink(url)) return url;
  final client = dio ??
      Dio(BaseOptions(
          followRedirects: false,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null && status < 400));
  var current = url;
  for (var hop = 0; hop < 5 && _isShortLink(current); hop++) {
    final response = await client.get<dynamic>(current,
        options: Options(followRedirects: false));
    final location = response.headers.value('location');
    if (location == null) break;
    final next = Uri.parse(current).resolve(location).toString();
    if (!isGoogleMapsLink(next)) break;
    current = next;
  }
  return current;
}

/// Registration field for the exact farm location: paste a Google Maps link
/// or drop a pin on the map.
class FarmLocationField extends StatefulWidget {
  final FarmLocation? value;
  final ValueChanged<FarmLocation?> onChanged;

  /// Swappable for tests; defaults to following Google short links.
  final Future<String> Function(String url) resolve;
  const FarmLocationField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.resolve = resolveMapsLink});
  @override
  State<FarmLocationField> createState() => _FarmLocationFieldState();
}

class _FarmLocationFieldState extends State<FarmLocationField> {
  final _link = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _useLink() async {
    final link = extractLink(_link.text.trim());
    if (link == null || !isGoogleMapsLink(link)) {
      setState(() => _error = context.s.pasteMapsLinkError);
      return;
    }
    final s = context.s;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final full = await widget.resolve(link);
      final point = parseGoogleMapsLocation(full);
      if (point == null) {
        throw ApiFailure(s.linkNoLocation);
      }
      widget.onChanged(FarmLocation(point.latitude, point.longitude, link));
      _link.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiFailure ? e.message : s.linkOpenFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickOnMap() async {
    final point = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
        builder: (_) => FarmMapPicker(initial: widget.value?.point)));
    if (point != null) {
      setState(() => _error = null);
      widget.onChanged(FarmLocation.pinned(point));
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.farmOnMap, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(s.farmOnMapBody,
            style: const TextStyle(fontSize: 12, color: OColors.secondary)),
        const SizedBox(height: 12),
        if (value != null) ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                  height: 150,
                  child: IgnorePointer(
                      child: _FarmMap(
                          key: ValueKey(value.label),
                          center: value.point,
                          zoom: 15,
                          pin: true)))),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.place, size: 18, color: OColors.forest),
            const SizedBox(width: 6),
            Expanded(
                child: Text(value.label,
                    key: const Key('farm_location_label'),
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: () => widget.onChanged(null), child: Text(s.remove)),
          ]),
        ] else ...[
          TextField(
              key: const Key('farm_map_link'),
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                  labelText: s.pasteMapsLink,
                  hintText: 'https://maps.app.goo.gl/…',
                  suffixIcon: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          tooltip: s.useThisLink,
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: _useLink)),
              onSubmitted: (_) => _useLink()),
          const SizedBox(height: 8),
          Center(
              child:
                  Text(s.or, style: const TextStyle(color: OColors.secondary))),
          const SizedBox(height: 8),
        ],
        OmoterraButton(value == null ? s.pickOnMap : s.changeOnMap,
            icon: Icons.map_outlined,
            secondary: true,
            onPressed: _busy ? null : _pickOnMap),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  key: const Key('farm_location_error'),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
      ]),
    );
  }
}

/// Tanzania, whole-country view, when there is no pin yet.
const _tanzania = LatLng(-6.37, 34.89);

class _FarmMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final bool pin;
  final MapController? controller;
  const _FarmMap(
      {super.key,
      required this.center,
      required this.zoom,
      this.pin = false,
      this.controller});
  @override
  Widget build(BuildContext context) => FlutterMap(
          mapController: controller,
          options: MapOptions(initialCenter: center, initialZoom: zoom),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.transmark.omoterra'),
            if (pin)
              MarkerLayer(markers: [
                Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_pin,
                        size: 40, color: OColors.forest)),
              ]),
            // OpenStreetMap requires this credit on every map it serves.
            const Align(
                alignment: Alignment.bottomRight,
                child: ColoredBox(
                    color: Color(0xCCFFFFFF),
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('© OpenStreetMap contributors',
                            style: TextStyle(fontSize: 10))))),
          ]);
}

/// Full-screen map with a fixed centre pin: move the map under the pin,
/// or jump to the phone's current location, then confirm.
class FarmMapPicker extends StatefulWidget {
  final LatLng? initial;
  const FarmMapPicker({super.key, this.initial});
  @override
  State<FarmMapPicker> createState() => _FarmMapPickerState();
}

class _FarmMapPickerState extends State<FarmMapPicker> {
  final _map = MapController();
  bool _locating = false;
  String? _error;

  Future<void> _here() async {
    final s = context.s;
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw ApiFailure(s.turnOnLocation);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw ApiFailure(s.allowLocation);
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      _map.move(LatLng(position.latitude, position.longitude), 17);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiFailure ? e.message : s.locationFailed);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.pickFarmLocation)),
        body: Stack(children: [
          _FarmMap(
              controller: _map,
              center: widget.initial ?? _tanzania,
              zoom: widget.initial == null ? 6 : 16),
          // The pin stays put; the supplier moves the map beneath it.
          const IgnorePointer(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.location_pin,
                          size: 44, color: OColors.forest)))),
          Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(s.moveMapHint)))),
          Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null)
                  Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(_error!)),
                OmoterraButton(s.useCurrentLocation,
                    icon: Icons.my_location,
                    secondary: true,
                    busy: _locating,
                    onPressed: _here),
                const SizedBox(height: 8),
                OmoterraButton(s.confirmFarmLocation,
                    icon: Icons.check,
                    onPressed: () =>
                        Navigator.of(context).pop(_map.camera.center)),
              ]))),
        ]));
  }
}
