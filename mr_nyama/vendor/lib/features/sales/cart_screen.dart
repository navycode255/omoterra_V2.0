import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/vendor_repository.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/image_spinner.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/payment_option.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/quantity.dart';
import '../../core/auth/offline_unlock.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../closing/closing_store.dart';
import '../credit/credit_sheets.dart';
import '../credit/credit_store.dart';
import 'cart.dart';
import 'checkout.dart';
import 'kikapu_sheets.dart';
import 'product_images.dart';
import 'quantity_sheet.dart';
import 'sales_store.dart';

/// Kikapu (reference approved 22 October 2026): the lines with − qty + and
/// the line total, swipe left to remove (with undo), the grand total, how
/// the customer paid, and "Hifadhi mauzo". Cash, the Mr. Nyama M-Pesa
/// number, or credit to a customer the office registered (MN018); no split
/// payment. No payment is preselected.
///
/// After the sale is saved on the phone a sheet says so at once; it turns
/// into "sent to the office" only when the server accepts the sale.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

/// A removed line, kept so "Rudisha" can put it back where it was.
typedef _Removed = ({String id, String name, int quantity, int index});

class _CartScreenState extends ConsumerState<CartScreen> {
  String? _error;
  String? _openRow;
  _Removed? _removed;
  Timer? _snackTimer;

  /// The lines just sold, shown behind the result sheet: the cart itself is
  /// already empty, so the same sale can never be saved twice.
  (List<CartLine>, int?)? _sold;

  @override
  void dispose() {
    _snackTimer?.cancel();
    super.dispose();
  }

  void _remove(CartLine line, int index) {
    HapticFeedback.selectionClick();
    ref.read(cartProvider.notifier).remove(line.product.id);
    _snackTimer?.cancel();
    _snackTimer = Timer(MNMotion.undoWindow, () {
      if (mounted) setState(() => _removed = null);
    });
    setState(() {
      _openRow = null;
      _removed = (
        id: line.product.id,
        name: line.product.name,
        quantity: line.quantity,
        index: index
      );
    });
  }

  void _undo() {
    final removed = _removed;
    if (removed == null) return;
    _snackTimer?.cancel();
    ref
        .read(cartProvider.notifier)
        .restore(removed.id, removed.quantity, removed.index);
    setState(() => _removed = null);
  }

  void _addMore() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(MNRoutes.sales);
    }
  }

  Future<void> _clear() async {
    final strings = ref.read(stringsProvider);
    setState(() => _openRow = null);
    if (await showClearCartSheet(context, strings) && mounted) {
      _snackTimer?.cancel();
      setState(() => _removed = null);
      ref.read(cartProvider.notifier).clear();
    }
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final lines = ref.read(cartLinesProvider);
    final total = ref.read(cartTotalProvider);
    _snackTimer?.cancel();
    setState(() {
      _error = null;
      _openRow = null;
      _removed = null;
    });
    final SavedSale? sale;
    try {
      sale = await ref.read(checkoutProvider.notifier).confirm();
    } on CheckoutBlocked catch (blocked) {
      setState(() => _error = blocked.reason == 'customer'
          ? strings.creditCustomerRequired
          : strings.choosePayment);
      return;
    } catch (_) {
      // Not saved: the cart is untouched. Offer to try again.
      if (!mounted) return;
      if (await showSaveFailedSheet(context, strings) && mounted) {
        await _save();
      }
      return;
    }
    if (sale == null || !mounted) return;
    setState(() => _sold = (lines, total));
    // Saved on the phone: send it now if there is a network. The sheet
    // never waits for this.
    ref.read(syncEngineProvider.notifier).requestSync();
    await showSaleResultSheet(context, sale.clientId);
    if (mounted) context.go(MNRoutes.sales);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final sold = _sold;
    final List<CartLine> lines =
        sold == null ? ref.watch(cartLinesProvider) : sold.$1;
    final total = sold == null ? ref.watch(cartTotalProvider) : sold.$2;
    final checkout = ref.watch(checkoutProvider);
    final mpesa = ref.watch(mpesaRecipientProvider).valueOrNull;
    // The station's credit customers, refreshed when there is a network.
    ref.watch(creditRefreshProvider);
    final customers =
        ref.watch(creditCustomersProvider).valueOrNull ?? const [];
    final customer = checkout.payment == PaymentMethod.credit
        ? customers.where((c) => c.id == checkout.customer?.id).firstOrNull
        : null;
    final locked = checkout.saving || sold != null;
    final empty = lines.isEmpty && !locked;
    // Yesterday was worked but not closed: Funga Siku first (owner decision
    // 26 October 2026). Never while a sale is being saved or shown.
    final closeYesterday = sold == null &&
        ref.watch(yesterdayClosingProvider).valueOrNull ==
            YesterdayClosing.open;
    // Offline time is over (policies §10.4): no new sale until online.
    final offlineStopped = sold == null &&
        ref.watch(offlineRecordingStoppedProvider).valueOrNull == true;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomGap = bottom > 12 ? bottom : 12.0;
    final removed = _removed;

    final snack = removed == null
        ? null
        : _UndoSnack(
            message: strings.cartLineRemoved(removed.name),
            action: strings.undoWorkflow,
            onUndo: _undo);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: MNColors.kikapuBackground),
      child: Scaffold(
        backgroundColor: MNColors.kikapuBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                  title: strings.cart,
                  clearLabel: strings.clearCart,
                  backLabel: strings.back,
                  onBack: locked ? null : _addMore,
                  onClear: locked || lines.isEmpty ? null : _clear),
              if (empty) ...[
                Expanded(
                    child: _EmptyCart(
                        title: strings.emptyCartTitle,
                        message: strings.emptyCartBody,
                        action: strings.addMore,
                        onAdd: _addMore)),
                if (snack != null)
                  Padding(
                      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomGap),
                      child: snack),
              ] else ...[
                Flexible(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _openRow == null
                        ? null
                        : () => setState(() => _openRow = null),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 6),
                      children: [
                        _LinesCard(
                          lines: lines,
                          locked: locked,
                          openRow: _openRow,
                          addLabel: strings.addMore,
                          onAdd: _addMore,
                          onOpen: (id) => setState(() => _openRow = id),
                          onRemove: _remove,
                        ),
                        const SizedBox(height: 15),
                        _TotalCard(label: strings.total, total: total),
                        if (lines.any((l) => l.exceedsRecordedStock)) ...[
                          const SizedBox(height: 12),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: MNNote(strings.lowStockNote)),
                        ],
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Semantics(
                              header: true,
                              child: Text(strings.howPaid,
                                  style: MNText.kikapuHeading)),
                        ),
                        const SizedBox(height: 7),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(strings.paymentInstructions,
                              style: MNText.kikapuHint),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(children: [
                            MNPaymentOption(
                              reference: true,
                              icon: MNIconData.cash,
                              title: strings.cash,
                              caption: strings.cashCaption,
                              selected: checkout.payment == PaymentMethod.cash,
                              onTap: locked
                                  ? null
                                  : () => ref
                                      .read(checkoutProvider.notifier)
                                      .choosePayment(PaymentMethod.cash),
                            ),
                            // Offered only once a receiving number exists.
                            if (mpesa != null) ...[
                              const SizedBox(height: 6),
                              MNPaymentOption(
                                reference: true,
                                icon: MNIconData.phone,
                                title: strings.mpesa,
                                caption: strings.mpesaCaption(mpesa),
                                selected:
                                    checkout.payment == PaymentMethod.mpesa,
                                onTap: locked
                                    ? null
                                    : () => ref
                                        .read(checkoutProvider.notifier)
                                        .choosePayment(PaymentMethod.mpesa),
                              ),
                            ],
                            const SizedBox(height: 6),
                            MNPaymentOption(
                              reference: true,
                              icon: MNIconData.user,
                              title: strings.credit,
                              caption: customers.isEmpty
                                  ? strings.creditNoCustomers
                                  : customer == null
                                      ? strings.creditCaption
                                      : '${customer.name} · '
                                          '${creditCaption(strings, customer)}',
                              selected:
                                  checkout.payment == PaymentMethod.credit,
                              onTap: locked || customers.isEmpty
                                  ? null
                                  : () async {
                                      final picked =
                                          await showCreditCustomerSheet(
                                              context, ref, customers,
                                              selectedId: customer?.id);
                                      if (picked != null) {
                                        ref
                                            .read(checkoutProvider.notifier)
                                            .chooseCredit(picked.data);
                                      }
                                    },
                            ),
                            // Over the limit: warned, still saved, and the
                            // office reviews it (owner decision).
                            if (customer != null &&
                                total != null &&
                                customer.wouldExceed(total)) ...[
                              const SizedBox(height: 12),
                              MNNote(strings.creditOverLimit(
                                  customer.name,
                                  formatTsh(customer.owed + total),
                                  formatTsh(customer.creditLimit!))),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              MNNote(_error!, error: true),
                            ],
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      18, snack == null ? 18 : 8, 18, bottomGap),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (snack != null) ...[
                          snack,
                          const SizedBox(height: 12),
                        ],
                        if (offlineStopped) ...[
                          MNNote(strings.offlineRecordingStopped),
                          const SizedBox(height: 8),
                        ],
                        if (closeYesterday) ...[
                          MNNote(strings.closeYesterdayBody(strings.date(
                              businessDate(ref.read(clockProvider)())
                                  .subtract(const Duration(days: 1))))),
                          const SizedBox(height: 8),
                          MNButton.secondary(strings.closeYesterdayAction,
                              onPressed: () => context.push(MNRoutes.closeDay)),
                          const SizedBox(height: 8),
                        ],
                        MNButton(strings.saveSale,
                            busy: checkout.saving,
                            onPressed: checkout.payment == null ||
                                    total == null ||
                                    locked ||
                                    closeYesterday ||
                                    offlineStopped
                                ? null
                                : _save),
                      ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Back chevron and "Futa zote" above the large "Kikapu" title.
class _Header extends StatelessWidget {
  final String title, clearLabel, backLabel;
  final VoidCallback? onBack, onClear;
  const _Header(
      {required this.title,
      required this.clearLabel,
      required this.backLabel,
      required this.onBack,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    final clearColor =
        onClear == null ? MNColors.kikapuDisabledText : MNColors.referenceMuted;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 48,
        child: Row(children: [
          const SizedBox(width: 2),
          MNPressable(
            onTap: onBack,
            pressedScale: MNMotion.pressChip,
            semanticLabel: backLabel,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Transform.flip(
                  flipX: true,
                  child: const MNIcon(MNIconData.chevron,
                      size: 30,
                      strokeWidth: 1.6,
                      color: MNColors.referenceMuted),
                ),
              ),
            ),
          ),
          const Spacer(),
          MNPressable(
            onTap: onClear,
            pressedScale: MNMotion.pressChip,
            semanticLabel: clearLabel,
            borderRadius: BorderRadius.circular(MNRadius.medium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  MNIcon(MNIconData.trash,
                      size: 24, strokeWidth: 1.6, color: clearColor),
                  const SizedBox(width: 15),
                  ExcludeSemantics(
                      child: Text(clearLabel,
                          style:
                              MNText.kikapuAction.copyWith(color: clearColor))),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 16, 5),
        child: Semantics(
            header: true,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(title, style: MNText.kikapuTitle))),
      ),
    ]);
  }
}

/// The white card of cart lines, ending with "+ Ongeza bidhaa".
class _LinesCard extends StatelessWidget {
  final List<CartLine> lines;
  final bool locked;
  final String? openRow;
  final String addLabel;
  final VoidCallback onAdd;
  final ValueChanged<String?> onOpen;
  final void Function(CartLine line, int index) onRemove;
  const _LinesCard(
      {required this.lines,
      required this.locked,
      required this.openRow,
      required this.addLabel,
      required this.onAdd,
      required this.onOpen,
      required this.onRemove});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MNRadius.medium),
          child: ColoredBox(
            color: MNColors.white,
            child: Column(children: [
              for (final (i, line) in lines.indexed) ...[
                if (i > 0)
                  const Padding(
                      padding: EdgeInsets.only(left: 95, right: 15),
                      child: Divider(
                          height: 1, thickness: 1, color: MNColors.kikapuLine)),
                _SwipeRow(
                  key: ValueKey(line.product.id),
                  open: openRow == line.product.id,
                  enabled: !locked,
                  name: line.product.name,
                  onOpen: (open) => onOpen(open ? line.product.id : null),
                  onRemove: () => onRemove(line, i),
                  child: _CartLineRow(line: line, locked: locked),
                ),
              ],
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Divider(
                      height: 1, thickness: 1, color: MNColors.kikapuLine)),
              MNPressable(
                onTap: locked ? null : onAdd,
                pressedScale: 1,
                color: MNColors.white,
                pressedColor: MNColors.surface,
                semanticLabel: addLabel,
                child: SizedBox(
                  height: 53,
                  child: Row(children: [
                    const SizedBox(width: 18),
                    const MNIcon(MNIconData.plus,
                        size: 24,
                        strokeWidth: 1.5,
                        color: MNColors.referenceMuted),
                    const SizedBox(width: 17),
                    Expanded(
                        child: ExcludeSemantics(
                            child: Text(addLabel, style: MNText.kikapuAction))),
                    // Keeps the label clear of the card edge (and the page
                    // background beyond it).
                    const SizedBox(width: 18),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// A row that slides left to reveal the red "Futa" action. Screen readers
/// get the same action without swiping.
class _SwipeRow extends StatefulWidget {
  final bool open, enabled;
  final String name;
  final ValueChanged<bool> onOpen;
  final VoidCallback onRemove;
  final Widget child;
  const _SwipeRow(
      {super.key,
      required this.open,
      required this.enabled,
      required this.name,
      required this.onOpen,
      required this.onRemove,
      required this.child});

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow>
    with SingleTickerProviderStateMixin {
  static const _action = 68.0;
  late final _controller = AnimationController(
      vsync: this, duration: MNMotion.sheet, value: widget.open ? 1 : 0);

  @override
  void didUpdateWidget(covariant _SwipeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) _settle(widget.open);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _settle(bool open) {
    if (MNMotion.reduced(context)) {
      _controller.value = open ? 1 : 0;
    } else {
      _controller.animateTo(open ? 1 : 0, curve: MNMotion.easeOut);
    }
  }

  void _end(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final open = v < -300 || (v <= 300 && _controller.value > .5);
    _settle(open);
    if (open != widget.open) widget.onOpen(open);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ProviderScope.containerOf(context).read(stringsProvider);
    return Semantics(
      customSemanticsActions: widget.enabled
          ? {
              CustomSemanticsAction(label: strings.removeLineFor(widget.name)):
                  widget.onRemove
            }
          : null,
      child: GestureDetector(
        onHorizontalDragUpdate: widget.enabled
            ? (d) => _controller.value -= d.primaryDelta! / _action
            : null,
        onHorizontalDragEnd: widget.enabled ? _end : null,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            final shift = _controller.value * _action;
            return Stack(children: [
              Transform.translate(
                offset: Offset(-shift, 0),
                child: AbsorbPointer(absorbing: widget.open, child: child),
              ),
              if (shift > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: shift,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(10)),
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: _action,
                      maxWidth: _action,
                      child: MNPressable(
                        onTap: widget.onRemove,
                        pressedScale: 1,
                        color: MNColors.kikapuSwipeDelete,
                        pressedColor: MNColors.red,
                        semanticLabel: strings.removeLineFor(widget.name),
                        child: SizedBox.expand(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const MNIcon(MNIconData.trash,
                                    size: 26,
                                    strokeWidth: 1.6,
                                    color: MNColors.white),
                                const SizedBox(height: 6),
                                ExcludeSemantics(
                                    child: Text(strings.removeLine,
                                        style: MNText.kikapuOptionCaption
                                            .copyWith(
                                                fontSize: 14,
                                                color: MNColors.white))),
                              ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

/// One cart line: photo, name, − qty + and the exact line total.
class _CartLineRow extends ConsumerWidget {
  final CartLine line;
  final bool locked;
  const _CartLineRow({required this.line, required this.locked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final p = line.product;
    final cart = ref.read(cartProvider.notifier);
    final image = productImageFor(p.imageKey, productName: p.name);
    return ColoredBox(
      color: MNColors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 15, 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(MNRadius.small),
            child: SizedBox.square(
              dimension: 62,
              child: image == null
                  ? const ColoredBox(
                      color: MNColors.kikapuTile,
                      child: Center(
                          child: MNIcon(MNIconData.food,
                              size: 28, color: MNColors.kikapuDisabledText)))
                  : ColoredBox(
                      color: MNColors.kikapuTile,
                      child: MNLoadingImage(image: image, onDark: false)),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              MNPressable(
                pressedScale: 1,
                semanticLabel: strings.quantityFor(p.name),
                onTap: locked ? null : () => showQuantitySheet(context, p),
                child: Text(p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MNText.kikapuName),
              ),
              if (line.exceedsRecordedStock)
                Text(strings.lowStock(p.name),
                    style: MNText.meta.copyWith(color: MNColors.warning)),
              Row(children: [
                Transform.translate(
                  offset: const Offset(-9, 0),
                  child: MNQuantitySelector(
                      compact: true,
                      value: line.quantity,
                      min: 0,
                      itemLabel: p.name,
                      onChanged:
                          locked ? (_) {} : (v) => cart.setQuantity(p.id, v)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                          line.lineTotal == null
                              ? strings.noPrice
                              : formatTzs(line.lineTotal!),
                          textAlign: TextAlign.right,
                          style: MNText.kikapuLineTotal),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final int? total;
  const _TotalCard({required this.label, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
          decoration: BoxDecoration(
              color: MNColors.white,
              borderRadius: BorderRadius.circular(MNRadius.medium)),
          child: Row(children: [
            Text(label, style: MNText.kikapuTotal),
            const SizedBox(width: 16),
            if (total != null)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child:
                      Text(formatTzs(total!), style: MNText.kikapuTotalAmount),
                ),
              ),
          ]),
        ),
      );
}

/// "Paja limefutwa." with "Rudisha" on the dark snackbar.
class _UndoSnack extends StatelessWidget {
  final String message, action;
  final VoidCallback onUndo;
  const _UndoSnack(
      {required this.message, required this.action, required this.onUndo});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.only(left: 21, right: 10),
          decoration: BoxDecoration(
              color: MNColors.kikapuSnack,
              borderRadius: BorderRadius.circular(MNRadius.medium)),
          child: Row(children: [
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(message, style: MNText.kikapuSnack),
            )),
            MNPressable(
              onTap: onUndo,
              pressedScale: MNMotion.pressChip,
              semanticLabel: action,
              borderRadius: BorderRadius.circular(MNRadius.small),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const MNIcon(MNIconData.undo,
                        size: 22, strokeWidth: 2, color: MNColors.white),
                    const SizedBox(width: 16),
                    ExcludeSemantics(
                        child: Text(action,
                            style: MNText.withWeight(
                                MNText.kikapuSnack, FontWeight.w600))),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// "Kikapu ni tupu": basket, message and a white "+ Ongeza bidhaa" pill.
class _EmptyCart extends StatelessWidget {
  final String title, message, action;
  final VoidCallback onAdd;
  const _EmptyCart(
      {required this.title,
      required this.message,
      required this.action,
      required this.onAdd});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
        child: Column(children: [
          const MNIcon(MNIconData.basket,
              size: 92, strokeWidth: 1.1, color: MNColors.kikapuEmptyIcon),
          const SizedBox(height: 26),
          Semantics(
              header: true,
              child: Text(title,
                  textAlign: TextAlign.center, style: MNText.kikapuEmptyTitle)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center, style: MNText.kikapuEmptyBody),
          const SizedBox(height: 22),
          MNPressable(
            onTap: onAdd,
            color: MNColors.white,
            pressedColor: MNColors.surface,
            borderRadius: BorderRadius.circular(MNRadius.medium),
            semanticLabel: action,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54, minWidth: 216),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MNIcon(MNIconData.plus,
                          size: 24,
                          strokeWidth: 1.5,
                          color: MNColors.kikapuEmptyIcon),
                      const SizedBox(width: 16),
                      Flexible(
                        child: ExcludeSemantics(
                            child: Text(action,
                                textAlign: TextAlign.center,
                                style: MNText.kikapuAction.copyWith(
                                    color: MNColors.kikapuSecondaryText))),
                      ),
                    ]),
              ),
            ),
          ),
        ]),
      );
}
