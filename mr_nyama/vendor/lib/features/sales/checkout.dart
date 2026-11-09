import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import 'cart.dart';
import 'stock_pool.dart';
import 'sales_store.dart';

/// Fetches the server's catalogue and caches it. Failure (offline, no API)
/// leaves the cached catalogue in place; the error is exposed so the screen
/// can say so when there is nothing cached.
final catalogRefreshProvider = FutureProvider.autoDispose<void>((ref) async {
  final repository = ref.read(vendorRepositoryProvider);
  final snapshot = await ref
      .read(sessionProvider.notifier)
      .authorised((token) => repository.catalog(token));
  await ref.read(salesStoreProvider).replaceCatalog(snapshot);
});

/// A cart line priced from the current catalogue.
class CartLine {
  final Product product;
  final int quantity;
  const CartLine(this.product, this.quantity);

  int? get lineTotal =>
      product.price == null ? null : product.price! * quantity;

  /// The phone's records show fewer units than this line sells.
  bool get exceedsRecordedStock =>
      product.availableToSell != null && quantity > product.availableToSell!;
}

/// The cart joined with the catalogue, in the order products were added.
/// Products no longer in the catalogue are dropped from the view.
final cartLinesProvider = Provider<List<CartLine>>((ref) {
  final cart = ref.watch(cartProvider);
  final products = {
    for (final p in ref.watch(productsProvider).valueOrNull ?? <Product>[])
      p.id: p
  };
  return [
    for (final MapEntry(key: id, value: quantity) in cart.lines.entries)
      if (products[id] != null) CartLine(products[id]!, quantity),
  ];
});

/// Grand total of the cart, or null when any line has no price.
final cartTotalProvider = Provider<int?>((ref) {
  var total = 0;
  for (final line in ref.watch(cartLinesProvider)) {
    final lineTotal = line.lineTotal;
    if (lineTotal == null) return null;
    total += lineTotal;
  }
  return total;
});

class CheckoutState {
  final PaymentMethod? payment;
  final bool saving;

  /// The credit customer when [payment] is credit (MN018).
  final CreditCustomerData? customer;
  const CheckoutState({this.payment, this.saving = false, this.customer});
}

class CheckoutBlocked implements Exception {
  final String reason;
  const CheckoutBlocked(this.reason);
}

/// Saves the cart as one sale. One client ID per checkout attempt: a retry
/// after a failure reuses it, so the store returns the first sale instead of
/// recording another. A second tap while saving is ignored.
class CheckoutController extends Notifier<CheckoutState> {
  String? _attemptId;

  @override
  CheckoutState build() {
    // The number can be taken away after M-Pesa was chosen: nothing to pay into.
    ref.listen(mpesaRecipientProvider, (_, next) {
      if (_noRecipient(next) && state.payment == PaymentMethod.mpesa) {
        state = CheckoutState(saving: state.saving);
      }
    });
    return const CheckoutState();
  }

  /// Known to be unset; still loading says nothing either way.
  bool _noRecipient(AsyncValue<String?> recipient) =>
      recipient.hasValue && recipient.value == null;

  void choosePayment(PaymentMethod method) =>
      state = CheckoutState(payment: method, saving: state.saving);

  /// Credit to [customer]: they take the goods and pay later.
  void chooseCredit(CreditCustomerData customer) => state = CheckoutState(
      payment: PaymentMethod.credit, saving: state.saving, customer: customer);

  /// Returns the saved sale, or null if a save is already in progress.
  Future<SavedSale?> confirm() async {
    if (state.saving) return null;
    final payment = state.payment;
    final lines = ref.read(cartLinesProvider);
    final auth = ref.read(sessionProvider).valueOrNull;
    if (payment == PaymentMethod.mpesa &&
        _noRecipient(ref.read(mpesaRecipientProvider))) {
      state = CheckoutState(saving: state.saving);
      throw const CheckoutBlocked('payment');
    }
    if (payment == null) throw const CheckoutBlocked('payment');
    final customer = state.customer;
    if (payment == PaymentMethod.credit && customer == null) {
      throw const CheckoutBlocked('customer');
    }
    if (lines.isEmpty) throw const CheckoutBlocked('empty');
    if (lines.any((l) => l.product.price == null)) {
      throw const CheckoutBlocked('price');
    }
    if (auth is! SignedIn) throw const CheckoutBlocked('session');

    state = CheckoutState(payment: payment, saving: true, customer: customer);
    _attemptId ??= const Uuid().v4();
    try {
      final sale = await ref.read(salesStoreProvider).saveSale(SaleDraft(
            clientId: _attemptId!,
            vendorId: auth.profile.id,
            stationKey: auth.profile.stationKey,
            recordedAt: ref.read(clockProvider)(),
            payment: payment,
            customerId: payment == PaymentMethod.credit ? customer!.id : null,
            customerName:
                payment == PaymentMethod.credit ? customer!.name : null,
            lines: [
              for (final l in lines)
                DraftLine(
                    productId: l.product.id,
                    productName: l.product.name,
                    quantity: l.quantity,
                    unitPrice: l.product.price!,
                    priceVersion: l.product.priceVersion,
                    exceedsRecordedStock: l.exceedsRecordedStock),
            ],
          ));
      // Saved: the next sale starts fresh.
      _attemptId = null;
      ref.read(cartProvider.notifier).clear();
      state = const CheckoutState();
      return sale;
    } catch (_) {
      state = CheckoutState(payment: payment, customer: customer);
      rethrow;
    }
  }
}

final checkoutProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);

/// What the grid shows while a sale is being built: the stock once the
/// unsent sales and the cart are taken, with the cuts they need (owner
/// decision 25 October 2026: a Paja from the only bird leaves Nusu 1 and
/// Kidali 1, and Kuku mzima 0). Products the server sent no stock for are
/// left out.
final saleStockProvider =
    Provider<({Map<String, int> remaining, Map<String, int> sellable})>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? const [];
  final cart = ref.watch(cartProvider);
  return poolStock([
    for (final p in products)
      PoolEntry(
          id: p.id,
          held: p.held,
          pendingSold: p.pendingSold + cart.quantityOf(p.id),
          cut: p.cutFrom != null && p.cutCount != null
              ? CutRule(p.cutFrom!, p.cutCount!)
              : null),
  ]);
});
