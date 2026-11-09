import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/radio_mark.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/number_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import '../sales/checkout.dart';
import '../sales/product_images.dart';
import '../sales/sales_store.dart';
import 'damage_store.dart';

final _savedDamageProvider = StreamProvider.autoDispose
    .family<DamageEntry?, String>((ref, id) => ref
        .watch(damageStoreProvider)
        .watchRecent(ref.watch(clockProvider)())
        .map((rows) => rows.where((r) => r.reportId == id).firstOrNull));

enum _Step { product, quantity, reason, review, saved }

final pickDamagePhotoProvider = Provider<Future<XFile?> Function()>((ref) =>
    () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
        requestFullMetadata: false));

/// Reporting damaged goods: product, quantity, reason, check, saved. The
/// report is a claim for the office to verify; it deducts no stock.
class DamageReportScreen extends ConsumerStatefulWidget {
  const DamageReportScreen({super.key});

  @override
  ConsumerState<DamageReportScreen> createState() => _DamageReportScreenState();
}

class _DamageReportScreenState extends ConsumerState<DamageReportScreen> {
  var _step = _Step.product;
  Product? _product;
  int _quantity = 1;
  DamageReason? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _photoPath;

  /// One report ID per attempt; a retry or double tap reuses it.
  String? _reportId;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == _Step.product || _step == _Step.saved) {
      context.pop();
    } else {
      setState(() => _step = _Step.values[_step.index - 1]);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    final strings = ref.read(stringsProvider);
    final store = ref.read(damageStoreProvider);
    final auth = ref.read(sessionProvider).valueOrNull;
    try {
      if (auth is! SignedIn || _product == null || _reason == null) return;
      final now = ref.read(clockProvider)();
      if (_reportId == null) {
        final similar = await store.recentSimilar(
            productId: _product!.id,
            quantity: _quantity,
            reason: _reason!,
            now: now);
        if (similar != null && mounted) {
          final yes = await showMNConfirmDialog(context,
              title: strings.similarTitle,
              message: strings.similarBody,
              confirmLabel: strings.saveAnother,
              cancelLabel: strings.stay);
          if (!yes) return;
        }
      }
      if (mounted) setState(() {});
      _reportId ??= const Uuid().v4();
      await store.submit(
          reportId: _reportId!,
          product: _product!,
          quantity: _quantity,
          reason: _reason!,
          note: _note.text,
          photoPath: _photoPath,
          stationKey: auth.profile.stationKey,
          actorId: auth.profile.id,
          now: now);
      if (mounted) setState(() => _step = _Step.saved);
    } on DamageRefused {
      if (mounted) setState(() => _error = strings.enterDamaged);
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveErrorTitle);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    final strings = ref.read(stringsProvider);
    try {
      final file = await ref.read(pickDamagePhotoProvider)();
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException();
      }
      setState(() {
        _photoPath = file.path;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = strings.photoFailed);
    }
  }

  void _restart() => setState(() {
        _step = _Step.product;
        _product = null;
        _quantity = 1;
        _reason = null;
        _note.clear();
        _photoPath = null;
        _reportId = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final report = _reportId == null
        ? null
        : ref.watch(_savedDamageProvider(_reportId!)).valueOrNull;
    return PopScope(
      canPop: _step == _Step.product || _step == _Step.saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: MNColors.pageBackground,
        appBar: MNWorkflowHeader(
          title: switch (_step) {
            _Step.product => strings.chooseProduct,
            _Step.quantity => strings.damagedQuantity,
            _Step.reason => strings.damageReasonTitle,
            _Step.review => strings.reviewReport,
            _Step.saved => strings.damaged,
          },
          onBack: _back,
          actions: [
            MNWorkflowHelp(messages: [strings.reportNotLoss])
          ],
        ),
        body: switch (_step) {
          _Step.product => _ProductStep(
              onPick: (p) => setState(() {
                    _product = p;
                    _step = _Step.quantity;
                  })),
          _Step.quantity => _QuantityStep(
              product: _product!,
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v)),
          _Step.reason => _ReasonStep(
              selected: _reason,
              note: _note,
              onPick: (r) => setState(() => _reason = r)),
          _Step.review =>
            ListView(padding: const EdgeInsets.all(16), children: [
              MNReferenceSurface(
                  child: Column(children: [
                _DamageInfoRow(
                    first: true,
                    label: strings.products,
                    value: Text(_product!.name)),
                _DamageInfoRow(
                    label: strings.stockQuantity, value: Text('$_quantity')),
                _DamageInfoRow(
                    label: strings.damageReasonTitle,
                    value: Text(strings.damageReason(_reason!.name))),
                if (_note.text.trim().isNotEmpty)
                  _DamageInfoRow(
                      label: strings.noteOptional,
                      value: Text(_note.text.trim())),
              ])),
              const SizedBox(height: MNSpace.x3),
              MNButton.secondary(strings.damagePhoto,
                  onPressed: _busy ? null : _pickPhoto),
              if (_photoPath != null) ...[
                const SizedBox(height: MNSpace.x2),
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_photoPath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(height: 1))),
                const SizedBox(height: MNSpace.x2),
                MNButton.secondary(strings.removePhoto,
                    onPressed:
                        _busy ? null : () => setState(() => _photoPath = null)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                MNNote(_error!, error: true),
              ],
            ]),
          _Step.saved => ListView(padding: const EdgeInsets.all(24), children: [
              const SizedBox(height: 32),
              const Center(child: MNIcon(MNIconData.check, size: 48)),
              const SizedBox(height: 20),
              Text(strings.reportSaved,
                  textAlign: TextAlign.center, style: MNText.heading),
              const SizedBox(height: 24),
              MNReferenceSurface(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Text(strings.quantityOf(_product!.name, _quantity),
                            style: MNText.title, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(strings.savedOnPhone, style: MNText.secondary),
                        const SizedBox(height: 6),
                        Text(
                            strings.damageStatus(report?.sent ?? false,
                                report?.review ?? 'reported'),
                            style: MNText.meta),
                      ]))),
            ]),
        },
        bottomNavigationBar: switch (_step) {
          _Step.product => null,
          _ => SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
                child: switch (_step) {
                  _Step.quantity => MNButton(strings.continueAction,
                      onPressed: _quantity > 0
                          ? () => setState(() => _step = _Step.reason)
                          : null),
                  _Step.reason => MNButton(strings.continueAction,
                      onPressed: _reason == null
                          ? null
                          : () => setState(() => _step = _Step.review)),
                  _Step.review => MNButton(strings.submitReport,
                      busy: _busy, onPressed: _busy ? null : _save),
                  _ => Column(mainAxisSize: MainAxisSize.min, children: [
                      MNButton(strings.anotherReport, onPressed: _restart),
                      const SizedBox(height: MNSpace.x2),
                      MNButton.secondary(strings.back,
                          onPressed: () => context.pop()),
                    ]),
                },
              ),
            ),
        },
      ),
    );
  }
}

class _ProductStep extends ConsumerWidget {
  final ValueChanged<Product> onPick;
  const _ProductStep({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final refresh = ref.watch(catalogRefreshProvider);
    final result = ref.watch(productsProvider);
    final products = result.valueOrNull ?? const <Product>[];
    if (products.isEmpty) {
      if (result.isLoading || refresh.isLoading) return const MNLoadingState();
      if (result.hasError || refresh.hasError) {
        return MNErrorState(
            error: result.error ?? refresh.error,
            onRetry: () => ref.invalidate(catalogRefreshProvider));
      }
      return MNEmptyState(icon: MNIconData.box, title: strings.noProducts);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      MNReferenceSurface(
          child: Column(children: [
        for (final (i, p) in products.indexed)
          MNListRow(
            first: i == 0,
            onTap: () => onPick(p),
            semanticLabel: p.name,
            leading: MNProductImage.thumb(
                image: productImageFor(p.imageKey, productName: p.name)),
            title: ExcludeSemantics(child: Text(p.name, style: MNText.title)),
            trailing: const MNIcon(MNIconData.chevron,
                size: 18, color: MNColors.muted),
          ),
      ])),
    ]);
  }
}

class _QuantityStep extends ConsumerWidget {
  final Product product;
  final int value;
  final ValueChanged<int> onChanged;
  const _QuantityStep(
      {required this.product, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return ListView(padding: const EdgeInsets.all(16), children: [
      MNReferenceSurface(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  MNProductImage.thumb(
                      image: productImageFor(product.imageKey,
                          productName: product.name),
                      size: MNSize.thumbLarge),
                  const SizedBox(width: MNSpace.x3),
                  Expanded(child: Text(product.name, style: MNText.heading)),
                ]),
                const SizedBox(height: MNSpace.x6),
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    MNQuantityButton(
                        icon: MNIconData.minus,
                        label: '${strings.decrease} ${product.name}',
                        large: true,
                        onPressed:
                            value > 1 ? () => onChanged(value - 1) : null),
                    MNPressable(
                      onTap: () async {
                        final v = await showNumberSheet(context,
                            title: strings.damagedQuantity,
                            initial: value,
                            max: 999);
                        if (v != null) onChanged(v);
                      },
                      pressedScale: MNMotion.pressChip,
                      semanticLabel: '${strings.damagedQuantity}, $value',
                      child: SizedBox(
                        width: 96,
                        height: MNSize.quantityLarge,
                        child: Center(
                          child: ExcludeSemantics(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: MNRollingNumber(value,
                                  style: MNText.quantityLarge),
                            ),
                          ),
                        ),
                      ),
                    ),
                    MNQuantityButton(
                        icon: MNIconData.plus,
                        label: '${strings.increase} ${product.name}',
                        large: true,
                        onPressed:
                            value < 999 ? () => onChanged(value + 1) : null),
                  ]),
                ),
                const SizedBox(height: 12),
              ]))),
    ]);
  }
}

class _ReasonStep extends ConsumerWidget {
  final DamageReason? selected;
  final TextEditingController note;
  final ValueChanged<DamageReason> onPick;
  const _ReasonStep(
      {required this.selected, required this.note, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return ListView(padding: const EdgeInsets.all(16), children: [
      MNReferenceSurface(
          child: Column(children: [
        for (final (i, r) in DamageReason.values.indexed)
          MNListRow(
            first: i == 0,
            onTap: () => onPick(r),
            semanticLabel: strings.damageReason(r.name),
            title: ExcludeSemantics(
                child: Text(strings.damageReason(r.name), style: MNText.body)),
            trailing: MNRadioMark(selected: selected == r),
          ),
      ])),
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: MNTextField(
            label: strings.noteOptional,
            controller: note,
            inputFormatters: [
              LengthLimitingTextInputFormatter(damageNoteMaxLength)
            ],
            textInputAction: TextInputAction.done),
      ),
    ]);
  }
}

class _DamageInfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final bool first;
  const _DamageInfoRow(
      {required this.label, required this.value, this.first = false});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: MNColors.referenceLine))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: MNText.secondary)),
        const SizedBox(width: 16),
        Expanded(
            child: DefaultTextStyle(
                style: MNText.title, textAlign: TextAlign.right, child: value)),
      ]));
}
