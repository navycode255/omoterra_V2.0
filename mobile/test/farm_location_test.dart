import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:omoterra/shared/widgets/farm_location.dart';

void main() {
  test('reads coordinates from the Google Maps link forms suppliers share', () {
    final cases = {
      'https://www.google.com/maps/place/Farm/@-6.7,39.1,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d-6.792354!4d39.208328':
          const LatLng(-6.792354, 39.208328),
      'https://www.google.com/maps/@-6.8123,39.2801,15z':
          const LatLng(-6.8123, 39.2801),
      'https://maps.google.com/?q=-6.8123,39.2801':
          const LatLng(-6.8123, 39.2801),
      'https://www.google.com/maps/search/?api=1&query=-6.8%2C39.2':
          const LatLng(-6.8, 39.2),
      'https://www.google.com/maps/place/-6.81,+39.28':
          const LatLng(-6.81, 39.28),
      'https://www.google.com/maps/dir/?api=1&destination=-3.37,36.68':
          const LatLng(-3.37, 36.68),
    };
    cases.forEach((url, point) {
      expect(parseGoogleMapsLocation(url), point, reason: url);
    });
    expect(parseGoogleMapsLocation('https://www.google.com/maps/place/Kibaha'),
        isNull);
    expect(
        parseGoogleMapsLocation('https://www.google.com/maps/@0,0,3z'), isNull);
  });

  test('accepts only Google Maps links and pulls them out of shared text', () {
    expect(extractLink('JM Farm\nhttp://maps.app.goo.gl/AbC123'),
        'https://maps.app.goo.gl/AbC123');
    expect(isGoogleMapsLink('https://maps.app.goo.gl/AbC123'), isTrue);
    expect(isGoogleMapsLink('https://www.google.co.tz/maps/@-6,39,5z'), isTrue);
    expect(isGoogleMapsLink('https://google.com.evil.io/maps/x'), isFalse);
    expect(isGoogleMapsLink('https://example.com/maps'), isFalse);
  });

  test('a map pick carries a Google Maps link operations can open', () {
    final pick = FarmLocation.pinned(const LatLng(-6.5, 38.9));
    expect(pick.url,
        'https://www.google.com/maps/search/?api=1&query=-6.500000,38.900000');
    expect(pick.toJson()['farm_latitude'], '-6.500000');
  });
}
