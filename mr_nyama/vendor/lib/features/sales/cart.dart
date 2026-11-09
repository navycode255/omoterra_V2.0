import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sale being put together. It holds product IDs and quantities only:
/// prices and totals are always read from the authoritative product
/// configuration when shown or saved, never stored here.
///
/// App-scoped, so it survives switching tabs and opening other screens.
/// It is cleared only by an explicit [CartController.clear] (after a sale is
/// saved, or when the vendor empties it).
class Cart {
  /// Product ID → quantity, in the order the products were added.
  final Map<String, int> lines;
  const Cart([this.lines = const {}]);

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.values.fold(0, (a, b) => a + b);
  int quantityOf(String productId) => lines[productId] ?? 0;

  /// Sum of quantity × price, with [priceOf] supplied from the product
  /// configuration. Null when any product's price is unknown: a partial
  /// total would understate the sale, so none is shown instead.
  int? total(int? Function(String productId) priceOf) {
    var sum = 0;
    for (final MapEntry(key: id, value: quantity) in lines.entries) {
      final price = priceOf(id);
      if (price == null) return null;
      sum += price * quantity;
    }
    return sum;
  }
}

class CartController extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  void add(String productId, [int quantity = 1]) =>
      setQuantity(productId, state.quantityOf(productId) + quantity);

  void setQuantity(String productId, int quantity) {
    final lines = Map<String, int>.of(state.lines);
    if (quantity <= 0) {
      lines.remove(productId);
    } else {
      lines[productId] = quantity;
    }
    state = Cart(Map.unmodifiable(lines));
  }

  void remove(String productId) => setQuantity(productId, 0);

  /// Puts a removed line back at [index] (undo), keeping the cart's order.
  void restore(String productId, int quantity, int index) {
    if (quantity <= 0) return;
    final entries =
        state.lines.entries.where((e) => e.key != productId).toList();
    entries.insert(
        index.clamp(0, entries.length), MapEntry(productId, quantity));
    state = Cart(Map.unmodifiable(Map.fromEntries(entries)));
  }

  void clear() => state = const Cart();
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);
