import 'package:flutter/painting.dart';

/// SAMPLE DATA FOR THE DEVELOPMENT SHOWCASE ONLY.
///
/// Nothing outside `lib/dev/` may import this file (test/dev_isolation_test.dart
/// enforces it). Names and prices are illustrative, taken from the design
/// storyboards; they are not Mr. Nyama's product configuration.
class SampleProduct {
  final String id;
  final String name;
  final int price;
  final String remaining;
  final ImageProvider? image;
  const SampleProduct(this.id, this.name, this.price, this.remaining,
      [this.image]);
}

const _breast = AssetImage('assets/images/grill.png');
const _necks = AssetImage('assets/products/bbq-chicken-necks-skewer.png');

const sampleProducts = [
  SampleProduct('sample-kidali', 'Kidali (Robo)', 2500, '28', _breast),
  SampleProduct('sample-shingo', 'Shingo (1)', 500, '40', _necks),
  SampleProduct('sample-paja', 'Paja (Robo)', 2000, '0'),
  SampleProduct('sample-firigisi', 'Firigisi (2)', 1000, '50'),
];
