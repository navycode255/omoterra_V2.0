import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/format.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';

void main() {
  group('money format', () {
    test('TSh with thousands separators', () {
      expect(formatTsh(0), 'TSh 0');
      expect(formatTsh(2500), 'TSh 2,500');
      expect(formatTsh(245000), 'TSh 245,000');
      expect(formatTsh(1250000), 'TSh 1,250,000');
      expect(groupDigits(24000), '24,000');
    });
  });

  group('cart', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    CartController cart() => container.read(cartProvider.notifier);
    Cart state() => container.read(cartProvider);

    test('adds, changes and removes quantities in order', () {
      cart()
        ..add('kuku')
        ..add('shingo', 3)
        ..add('kuku');
      expect(state().lines, {'kuku': 2, 'shingo': 3});
      expect(state().itemCount, 5);
      cart().setQuantity('kuku', 0);
      expect(state().lines.keys, ['shingo']);
      cart().clear();
      expect(state().isEmpty, isTrue);
    });

    test('totals come only from the supplied prices', () {
      cart()
        ..add('kuku', 2)
        ..add('shingo', 4);
      final prices = {'kuku': 2500, 'shingo': 500};
      expect(state().total((id) => prices[id]), 7000);
    });

    test('no total while any price is unknown, never a partial one', () {
      cart()
        ..add('kuku', 2)
        ..add('unknown', 4);
      final prices = {'kuku': 2500};
      expect(state().total((id) => prices[id]), isNull);
    });

    test('the cart stores no prices', () {
      cart().add('kuku', 2);
      expect(state().lines.values, everyElement(isA<int>()));
      expect(state().lines, {'kuku': 2});
    });
  });
}
