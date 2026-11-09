import 'owner_widgets.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/number_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/product_card.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;
import 'product_screens.dart'
    show officeProductsProvider, officeUnitsProvider, ownerProductImage;
import 'stock_screens.dart' show officeStockCall;

/// Recipes (drafted by operations or the owner, approved by the owner and
/// never by the drafter) and kitchen production runs. The person types
/// every quantity; the server computes batches, costs and variance, and
/// the screens show what it answered.

// Data ---------------------------------------------------------------------------------

Future<T> officeProductionCall<T>(OfficeSessionController session,
        Future<T> Function(OfficeProductionRepository) work) =>
    session.guard((repo) {
      if (repo is! OfficeProductionRepository) {
        throw const OfficeError(OfficeErrorKind.invalid);
      }
      return work(repo as OfficeProductionRepository);
    });

final recipesProvider = FutureProvider.autoDispose<List<OfficeRecipe>>((ref) =>
    officeProductionCall(
        ref.read(officeSessionProvider.notifier), (r) => r.recipes()));

final recipeProvider = FutureProvider.autoDispose.family<OfficeRecipe, String>(
    (ref, id) => officeProductionCall(
        ref.read(officeSessionProvider.notifier), (r) => r.recipe(id)));

final productionRunsProvider =
    FutureProvider.autoDispose<List<OfficeProductionRun>>((ref) =>
        officeProductionCall(ref.read(officeSessionProvider.notifier),
            (r) => r.productionRuns()));

final productionRunProvider = FutureProvider.autoDispose
    .family<OfficeProductionRun, String>((ref, id) => officeProductionCall(
        ref.read(officeSessionProvider.notifier), (r) => r.productionRun(id)));

/// Kitchens the person may record at. Kitchen staff get exactly the
/// kitchens on their kitchen-staff grants (`/staff/me`, the rule the
/// production routes enforce); the owner and other staff who may list
/// locations see every active kitchen.
final productionKitchensProvider =
    FutureProvider.autoDispose<List<OfficeStockLocation>>((ref) async {
  final session = ref.read(officeSessionProvider.notifier);
  final auth = ref.read(officeSessionProvider).valueOrNull;
  final roles = auth is OfficeSignedIn ? auth.profile.roles : const <String>[];
  if (roles.contains(StaffRole.kitchen) && !roles.contains(StaffRole.owner)) {
    final me = await officeProductionCall(session, (r) => r.staffMe());
    return [
      for (final k in me.kitchens)
        OfficeStockLocation(
            id: k.id, code: k.code, name: k.name, kind: 'kitchen'),
    ];
  }
  final rows = await officeStockCall(session, (r) => r.stockLocations());
  return [
    for (final l in rows)
      if (l.active && l.kind == 'kitchen') l
  ];
});

/// What the signed-in account may plausibly do. The server decides.
({bool draft, bool approve, bool record, bool view, String? me})
    productionAccess(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final profile = auth is OfficeSignedIn ? auth.profile : null;
  final roles = profile?.roles ?? const <String>[];
  bool any(Set<String> set) => roles.any(set.contains);
  return (
    draft: any({StaffRole.operationsAdmin, StaffRole.owner}),
    approve: roles.contains(StaffRole.owner),
    record: any({StaffRole.kitchen, StaffRole.owner}),
    view: any({
      StaffRole.kitchen,
      StaffRole.supervisor,
      StaffRole.finance,
      StaffRole.operationsAdmin,
      StaffRole.owner
    }),
    me: profile?.id,
  );
}

// Formatting ---------------------------------------------------------------------------

String _qty(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

String _quantity(Strings s, num n, String unit) =>
    unit.isEmpty ? _qty(n) : '${_qty(n)} ${s.unitName(unit)}';

/// Shillings from a decimal amount, with cents only when there are any.
String productionTsh(num v) {
  final whole = v.truncate();
  final cents = ((v - whole).abs() * 100).round();
  return cents == 0
      ? formatTsh(whole)
      : '${formatTsh(whole)}.${cents.toString().padLeft(2, '0')}';
}

String _when(Strings s, DateTime? t) {
  if (t == null) return '—';
  final eat = eatClock(t);
  return '${s.date(eat)}, ${s.hhmm(eat)}';
}

String _kitchenName(Strings s, OfficeStockLocation k) => k.name.isNotEmpty
    ? k.name
    : s.productionKitchenNamed(k.code.isNotEmpty
        ? k.code
        : (k.id.length > 8 ? k.id.substring(0, 8) : k.id).toUpperCase());

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

TextStyle _title(BuildContext c) => OwnerStyle.text(c, 16, weight: 600);
TextStyle _body(BuildContext c, {Color color = OwnerStyle.ink}) =>
    OwnerStyle.text(c, 14, color: color);
TextStyle _meta(BuildContext c) =>
    OwnerStyle.text(c, 13, color: OwnerStyle.muted);
TextStyle _status(BuildContext c, Color color) =>
    OwnerStyle.text(c, 13, weight: 600, color: color);
TextStyle _heading(BuildContext c) => OwnerStyle.text(c, 17, weight: 700);

Widget _gap(BuildContext context, [double n = 12]) =>
    SizedBox(height: OwnerStyle.px(context, n));

EdgeInsets _pad(BuildContext context) =>
    EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12));

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => OwnerCard(
      child: Padding(
          padding: EdgeInsets.all(OwnerStyle.px(context, 16)), child: child));
}

/// Shows [count] items ten at a time, with "Zaidi" for the next ten.
class _Paged extends ConsumerStatefulWidget {
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  const _Paged({required this.count, required this.itemBuilder});
  @override
  ConsumerState<_Paged> createState() => _PagedState();
}

class _PagedState extends ConsumerState<_Paged> {
  int _limit = 10;
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < math.min(_limit, widget.count); i++) ...[
        if (i > 0) _gap(context),
        widget.itemBuilder(context, i),
      ],
      if (widget.count > _limit) ...[
        _gap(context),
        MNButton.secondary(s.moreRows,
            onPressed: () => setState(() => _limit += 10)),
      ],
    ]);
  }
}

// A typed quantity: the kikapu stepper for whole units, decimals for kg-like units -

/// Disposes [items] after the frame that removed their fields.
void _disposeLater(Iterable<_Qty> items) {
  final list = items.toList();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final l in list) {
      l.dispose();
    }
  });
}

class _Qty {
  final String product, name, unit;
  final ImageProvider? image;
  int count = 0;
  final text = TextEditingController();
  final basis = TextEditingController();
  _Qty(
      {required this.product,
      required this.name,
      required this.unit,
      this.image,
      Map<String, OfficeUnit> added = const {}})
      : kg = unitAllowsDecimal(unit, added);

  /// Decimals allowed: kg, or an added unit that allows them.
  final bool kg;

  /// The quantity to send (an int, or a decimal string for kg); null when
  /// nothing above zero was entered.
  Object? get value =>
      kg ? parseDecimalQuantity(text.text) : (count > 0 ? count : null);

  /// Something was typed that is not a valid quantity.
  bool get invalid => kg && text.text.trim().isNotEmpty && value == null;

  String shown(Strings s) => kg
      ? '${text.text.trim()} ${s.unitName(unit)}'
      : _quantity(s, count, unit);

  void dispose() {
    text.dispose();
    basis.dispose();
  }
}

final _decimalInput = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  LengthLimitingTextInputFormatter(12),
];

class _QtyField extends ConsumerWidget {
  final _Qty entry;
  final bool locked;
  final String? caption;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final Widget? extra;
  const _QtyField(
      {super.key,
      required this.entry,
      required this.locked,
      required this.onChanged,
      this.caption,
      this.onRemove,
      this.extra});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final e = entry;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: MNSpace.x2),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            MNProductImage.thumb(image: e.image),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  MNPressable(
                      semanticLabel: s.quantityFor(e.name),
                      onTap: locked || e.kg
                          ? null
                          : () async {
                              final v = await showNumberSheet(context,
                                  title: s.quantityFor(e.name),
                                  initial: e.count,
                                  max: 1000000);
                              if (v != null) {
                                e.count = v;
                                onChanged();
                              }
                            },
                      child: Text(e.name,
                          style: MNText.resolve(context, MNText.body))),
                  Text(caption ?? s.unitName(e.unit),
                      style: MNText.resolve(context, MNText.meta)),
                  if (!e.kg) ...[
                    const SizedBox(height: 4),
                    MNQuantitySelector(
                        value: e.count,
                        min: 0,
                        max: 1000000,
                        compact: true,
                        itemLabel: e.name,
                        onChanged: locked
                            ? (_) {}
                            : (v) {
                                e.count = v;
                                onChanged();
                              }),
                  ],
                ])),
            if (onRemove != null)
              MNTextButton(s.remove, onPressed: locked ? null : onRemove),
          ]),
          if (e.kg) ...[
            const SizedBox(height: MNSpace.x2),
            MNTextField(
                label: s.recipeQuantityKg,
                controller: e.text,
                enabled: !locked,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimalInput,
                onChanged: (_) => onChanged()),
          ],
          if (extra != null) ...[const SizedBox(height: MNSpace.x2), extra!],
        ]));
  }
}

// Recipes ------------------------------------------------------------------------------

class OfficeRecipesScreen extends ConsumerWidget {
  const OfficeRecipesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = productionAccess(ref);
    final allowed = access.draft || access.approve;
    return OwnerPage(
        title: s.recipes,
        strings: s,
        onAdd: access.draft
            ? () async {
                final recipe = await showMNSheet<OfficeRecipe>(context,
                    builder: (_) => const _NewRecipeSheet());
                if (recipe == null) return;
                ref.invalidate(recipesProvider);
                if (context.mounted) {
                  context.push(MNRoutes.officeRecipe(recipe.id));
                }
              }
            : null,
        addLabel: s.recipeNew,
        addIcon: 'plus',
        onRefresh: allowed ? () => ref.refresh(recipesProvider.future) : null,
        child: Padding(
            padding: _pad(context),
            child: !allowed
                ? MNNote(s.notAllowed)
                : OwnerAsyncView(
                    value: ref.watch(recipesProvider),
                    onRetry: () => ref.invalidate(recipesProvider),
                    isEmpty: (rows) => rows.isEmpty,
                    empty: (_) => MNNote(s.recipesNone, tone: MNNoteTone.info),
                    data: (rows) => _Paged(
                        count: rows.length,
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          final v = r.inForce;
                          return OwnerCard(
                              child: OwnerMenuRow(
                                  label: r.name,
                                  subtitle:
                                      '${r.productName} · ${v == null ? s.recipeNoVersionInForce : s.recipeInForce(v.version)}',
                                  onTap: () => context
                                      .push(MNRoutes.officeRecipe(r.id))));
                        }))));
  }
}

class _NewRecipeSheet extends ConsumerStatefulWidget {
  const _NewRecipeSheet();
  @override
  ConsumerState<_NewRecipeSheet> createState() => _NewRecipeState();
}

class _NewRecipeState extends ConsumerState<_NewRecipeSheet> {
  final _name = TextEditingController(), _reason = TextEditingController();
  String? _product, _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final name = _name.text.trim(), reason = _reason.text.trim();
    if (name.length < 2 ||
        name.length > 120 ||
        _product == null ||
        reason.length < 3 ||
        reason.length > 500) {
      setState(() => _error = s.recipeNameInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recipe = await officeProductionCall(
          ref.read(officeSessionProvider.notifier),
          (r) =>
              r.createRecipe(name: name, product: _product!, reason: reason));
      if (mounted) Navigator.of(context).pop(recipe);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(officeProductsProvider);
    return MNSheet(title: s.recipeNew, children: [
      MNTextField(
          label: s.recipeName,
          controller: _name,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(120)]),
      MNSelectField<String>(
          label: s.recipeProduct,
          value: _product,
          emptyText: products.isLoading ? s.loading : s.noOfficeProducts,
          options: [
            for (final p in products.valueOrNull ?? const <OfficeProduct>[])
              if (p.status == 'active')
                MNSelectOption(
                    value: p.code,
                    label: p.name,
                    image: ownerProductImage(p),
                    caption: s.unitName(p.unit)),
          ],
          onChanged: _busy ? null : (v) => setState(() => _product = v)),
      MNTextField(
          label: s.moneyReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveWorkflow, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

class OfficeRecipeScreen extends ConsumerWidget {
  final String recipeId;
  const OfficeRecipeScreen({super.key, required this.recipeId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = productionAccess(ref);
    final value = ref.watch(recipeProvider(recipeId));
    return OwnerPage(
        title: value.valueOrNull?.name ?? s.recipes,
        strings: s,
        onRefresh: () => ref.refresh(recipeProvider(recipeId).future),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView(
                value: value,
                onRetry: () => ref.invalidate(recipeProvider(recipeId)),
                data: (recipe) {
                  final current = recipe.inForce;
                  final versions = recipe.newestFirst;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(recipe.productName, style: _body(context)),
                        Text(
                            current == null
                                ? s.recipeNoVersionInForce
                                : s.recipeInForce(current.version),
                            style: _status(
                                context,
                                current == null
                                    ? MNColors.warning
                                    : MNColors.success)),
                        if (access.draft) ...[
                          _gap(context),
                          MNButton(s.recipeNewVersion, onPressed: () async {
                            await context.push(
                                MNRoutes.officeRecipeNewVersion(recipe.id));
                            ref.invalidate(recipeProvider(recipe.id));
                            ref.invalidate(recipesProvider);
                          }),
                        ],
                        for (final v in versions) ...[
                          _gap(context),
                          RecipeVersionCard(
                              version: v,
                              canDecide: access.approve,
                              me: access.me,
                              onDecided: () {
                                ref.invalidate(recipeProvider(recipe.id));
                                ref.invalidate(recipesProvider);
                              }),
                        ],
                      ]);
                })));
  }
}

class RecipeVersionCard extends ConsumerWidget {
  final RecipeVersion version;
  final bool canDecide;
  final String? me;
  final VoidCallback onDecided;
  const RecipeVersionCard(
      {super.key,
      required this.version,
      required this.canDecide,
      required this.me,
      required this.onDecided});

  Future<void> _decide(
      BuildContext context, WidgetRef ref, bool approve) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _DecisionSheet(version: version, approve: approve));
    if (done != true) return;
    onDecided();
    if (context.mounted) _toast(context, s.decisionSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final v = version;
    final color = v.approved
        ? MNColors.success
        : v.rejected
            ? MNColors.error
            : MNColors.warning;
    final primaryUnit = v.primaryInput?.unit ?? '';
    final method = v.method;
    String basis(RecipeLine l) => switch (method) {
          _ when l.basis == null => '',
          AllocationMethod.weight => ' · ${_qty(l.basis!)} kg',
          AllocationMethod.sellingValue => ' · ${formatTsh(l.basis!.round())}',
          AllocationMethod.fixedShares => ' · ${_qty(l.basis! / 100)}%',
          null => '',
        };
    final mine = me != null && v.draftedBy == me;
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.recipeVersion(v.version), style: _title(context)),
      Text(s.recipeStatus(v.status), style: _status(context, color)),
      if (v.inForce)
        Text(s.recipeInForceNow, style: _status(context, MNColors.success)),
      if (v.effectiveFrom != null)
        Text(s.recipeEffective(_when(s, v.effectiveFrom)),
            style: _meta(context)),
      _gap(context, 8),
      OwnerDetails(title: s.recordDetails, children: [
        if (method != null)
          Text('${s.recipeMethod}: ${s.methodName(method.wire)}',
              style: _body(context)),
        Text(
            s.recipeWasteText(v.wasteKind == 'percent'
                ? '${_qty(v.wasteValue)}%'
                : _quantity(s, v.wasteValue, primaryUnit)),
            style: _body(context)),
        Text(s.recipeRatioText(_qty(v.maxOutputRatio)), style: _body(context)),
        _gap(context, 8),
        Text(s.recipeInputs, style: _meta(context)),
        for (final (i, l) in v.inputs.indexed)
          Text(
              '${_quantity(s, l.quantity, l.unit)} × ${l.name}'
              '${i == 0 ? ' · ${s.recipePrimary}' : ''}',
              style: _body(context)),
        _gap(context, 4),
        Text(s.recipeOutputs, style: _meta(context)),
        for (final l in v.outputs)
          Text('${_quantity(s, l.quantity, l.unit)} × ${l.name}${basis(l)}',
              style: _body(context)),
        if (v.reason.isNotEmpty) ...[
          _gap(context, 4),
          Text(s.reasonText(v.reason), style: _meta(context)),
        ],
        if (v.decisionReason != null)
          Text(s.reasonText(v.decisionReason!), style: _meta(context)),
      ]),
      if (v.draft && canDecide) ...[
        _gap(context),
        if (mine)
          MNNote(s.recipeYourDraft, tone: MNNoteTone.info)
        else ...[
          MNButton(s.recipeApprove,
              onPressed: () => _decide(context, ref, true)),
          _gap(context, 8),
          MNButton.secondary(s.recipeReject,
              onPressed: () => _decide(context, ref, false)),
        ],
      ],
    ]));
  }
}

class _DecisionSheet extends ConsumerStatefulWidget {
  final RecipeVersion version;
  final bool approve;
  const _DecisionSheet({required this.version, required this.approve});
  @override
  ConsumerState<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends ConsumerState<_DecisionSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (reason.length < 3 || reason.length > 500) {
      setState(() => _error = s.decisionReasonInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeProductionCall(
          ref.read(officeSessionProvider.notifier),
          (r) => r.decideVersion(widget.version.id,
              approve: widget.approve, reason: reason));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final n = widget.version.version;
    return MNSheet(
        title:
            widget.approve ? s.recipeApproveTitle(n) : s.recipeRejectTitle(n),
        children: [
          MNNote(widget.approve ? s.recipeApproveBody : s.recipeRejectBody,
              tone: widget.approve ? MNNoteTone.warning : MNNoteTone.info),
          MNTextField(
              label: s.decisionReason,
              controller: _reason,
              enabled: !_busy,
              inputFormatters: [LengthLimitingTextInputFormatter(500)]),
          if (_error != null) MNNote(_error!, error: true),
          MNButton(widget.approve ? s.recipeApprove : s.recipeReject,
              busy: _busy, onPressed: _busy ? null : _save),
        ]);
  }
}

// A new recipe version -----------------------------------------------------------------

class OfficeRecipeVersionScreen extends ConsumerStatefulWidget {
  final String recipeId;
  const OfficeRecipeVersionScreen({super.key, required this.recipeId});
  @override
  ConsumerState<OfficeRecipeVersionScreen> createState() => _VersionFormState();
}

class _VersionFormState extends ConsumerState<OfficeRecipeVersionScreen> {
  final _inputs = <_Qty>[], _outputs = <_Qty>[];
  AllocationMethod? _method;
  String _wasteKind = 'quantity';
  final _waste = TextEditingController(),
      _ratio = TextEditingController(),
      _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final l in [..._inputs, ..._outputs]) {
      l.dispose();
    }
    _waste.dispose();
    _ratio.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _add(Strings s, List<_Qty> side, List<OfficeProduct> products,
      int most) async {
    if (side.length >= most) return;
    final picked = await showMNSelectSheet<OfficeProduct>(context,
        title: s.officeChooseProduct,
        emptyText: s.noOfficeProducts,
        options: [
          for (final p in products.where((p) => p.status == 'active'))
            MNSelectOption(
                value: p,
                label: p.name,
                image: ownerProductImage(p),
                enabled: !side.any((l) => l.product == p.code),
                caption: side.any((l) => l.product == p.code)
                    ? s.officeAlreadyAdded
                    : s.unitName(p.unit)),
        ]);
    if (picked == null || !mounted) return;
    final p = picked.value;
    setState(() {
      side.add(_Qty(
          product: p.code,
          name: p.name,
          unit: p.unit,
          image: ownerProductImage(p),
          added: ref.read(addedUnitsProvider)));
      _error = null;
    });
  }

  /// Fixed shares typed so far, in basis points (invalid rows count 0).
  int get _sharesBps => _outputs.fold<int>(
      0, (sum, l) => sum + (percentToBps(l.basis.text) ?? 0));

  Object? _basis(_Qty l) => switch (_method) {
        AllocationMethod.weight => parseDecimalQuantity(l.basis.text),
        AllocationMethod.sellingValue => switch (
              int.tryParse(l.basis.text.trim())) {
            final v? when v > 0 && v <= 100000000 => v,
            _ => null,
          },
        AllocationMethod.fixedShares => percentToBps(l.basis.text),
        null => null,
      };

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final lines = [..._inputs, ..._outputs];
    if (_inputs.isEmpty ||
        _outputs.isEmpty ||
        lines.any((l) => l.value == null)) {
      setState(() => _error = s.recipeLinesInvalid);
      return;
    }
    final method = _method;
    final waste = _waste.text.trim().replaceAll(',', '.');
    final ratio = _ratio.text.trim().replaceAll(',', '.');
    final reason = _reason.text.trim();
    final wasteOk = RegExp(r'^\d{1,7}(\.\d{1,3})?$').hasMatch(waste) &&
        (_wasteKind != 'percent' || double.parse(waste) <= 100);
    final ratioOk = RegExp(r'^\d{1,3}(\.\d{1,4})?$').hasMatch(ratio) &&
        double.parse(ratio) >= 1 &&
        double.parse(ratio) <= 100;
    if (method == null ||
        !wasteOk ||
        !ratioOk ||
        reason.length < 3 ||
        reason.length > 500) {
      setState(() => _error = s.recipeNumbersInvalid);
      return;
    }
    if (_outputs.any((l) => _basis(l) == null)) {
      setState(() => _error = s.recipeBasisInvalid);
      return;
    }
    if (method == AllocationMethod.fixedShares && _sharesBps != fullShareBps) {
      setState(() => _error = s.sharesMustTotal);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await officeProductionCall(
          ref.read(officeSessionProvider.notifier),
          (r) => r.draftVersion(widget.recipeId,
              inputs: [
                for (final l in _inputs) RecipeLineDraft(l.product, l.value!)
              ],
              outputs: [
                for (final l in _outputs)
                  RecipeLineDraft(l.product, l.value!, _basis(l))
              ],
              method: method,
              wasteKind: _wasteKind,
              wasteValue: waste,
              maxOutputRatio: ratio,
              reason: reason));
      if (!mounted) return;
      _toast(context, s.recipeVersionSaved);
      context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _lines(Strings s, List<_Qty> side, {required bool outputs}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, l) in side.indexed)
          _QtyField(
              key: ValueKey(l),
              entry: l,
              locked: _busy,
              caption: !outputs && i == 0
                  ? '${s.unitName(l.unit)} · ${s.recipePrimary}'
                  : null,
              onChanged: () => setState(() {}),
              onRemove: () {
                setState(() => side.remove(l));
                _disposeLater([l]);
              },
              extra: outputs && _method != null
                  ? MNTextField(
                      label: s.basisLabel(_method!.wire),
                      controller: l.basis,
                      enabled: !_busy,
                      keyboardType: _method == AllocationMethod.sellingValue
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(
                              decimal: true),
                      inputFormatters: _method == AllocationMethod.sellingValue
                          ? [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9)
                            ]
                          : _decimalInput,
                      onChanged: (_) => setState(() {}))
                  : null),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = productionAccess(ref);
    // Names the added units and tells which allow decimals.
    ref.watch(officeUnitsProvider);
    final products = ref.watch(officeProductsProvider).valueOrNull ??
        const <OfficeProduct>[];
    final shares = _sharesBps;
    return OwnerPage(
        title: s.recipeNewVersion,
        strings: s,
        child: Padding(
            padding: _pad(context),
            child: !access.draft
                ? MNNote(s.notAllowed)
                : _Card(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        MNNote(s.recipeNoYields, tone: MNNoteTone.info),
                        _gap(context),
                        Text(s.recipeInputs, style: _heading(context)),
                        _lines(s, _inputs, outputs: false),
                        MNButton.secondary(s.recipeAddInput,
                            onPressed: _busy || _inputs.length >= 20
                                ? null
                                : () => _add(s, _inputs, products, 20)),
                        _gap(context, 16),
                        MNSelectField<AllocationMethod>(
                            label: s.recipeMethod,
                            value: _method,
                            options: [
                              for (final m in AllocationMethod.values)
                                MNSelectOption(
                                    value: m,
                                    label: s.methodName(m.wire),
                                    caption: s.methodHelp(m.wire)),
                            ],
                            onChanged: _busy
                                ? null
                                : (m) => setState(() {
                                      if (m != _method) {
                                        for (final l in _outputs) {
                                          l.basis.clear();
                                        }
                                      }
                                      _method = m;
                                    })),
                        if (_method != null) ...[
                          _gap(context, 8),
                          MNNote(s.methodHelp(_method!.wire),
                              tone: MNNoteTone.info),
                        ],
                        _gap(context, 16),
                        Text(s.recipeOutputs, style: _heading(context)),
                        _lines(s, _outputs, outputs: true),
                        if (_method == AllocationMethod.fixedShares &&
                            _outputs.isNotEmpty)
                          Text(s.sharesTotal(_qty(shares / 100)),
                              style: _status(
                                  context,
                                  shares == fullShareBps
                                      ? MNColors.success
                                      : MNColors.warning)),
                        MNButton.secondary(s.recipeAddOutput,
                            onPressed: _busy || _outputs.length >= 30
                                ? null
                                : () => _add(s, _outputs, products, 30)),
                        _gap(context, 16),
                        Text(s.recipeWaste, style: _heading(context)),
                        _gap(context, 8),
                        MNSelectField<String>(
                            label: s.recipeWaste,
                            value: _wasteKind,
                            options: [
                              for (final k in const ['quantity', 'percent'])
                                MNSelectOption(
                                    value: k, label: s.wasteKindName(k)),
                            ],
                            onChanged: _busy
                                ? null
                                : (k) => setState(() => _wasteKind = k)),
                        _gap(context, 8),
                        MNTextField(
                            label: s.wasteValue,
                            controller: _waste,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: _decimalInput),
                        _gap(context),
                        MNTextField(
                            label: s.recipeMaxRatio,
                            controller: _ratio,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: _decimalInput),
                        OwnerHelp(message: s.recipeMaxRatioHelp),
                        _gap(context),
                        MNTextField(
                            label: s.moneyReason,
                            controller: _reason,
                            enabled: !_busy,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(500)
                            ]),
                        if (_error != null) ...[
                          _gap(context),
                          MNNote(_error!, error: true),
                        ],
                        _gap(context),
                        MNButton(s.saveWorkflow,
                            busy: _busy, onPressed: _busy ? null : _save),
                      ]))));
  }
}

// Production runs ----------------------------------------------------------------------

class OfficeProductionScreen extends ConsumerWidget {
  const OfficeProductionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = productionAccess(ref);
    final kitchens = ref.watch(productionKitchensProvider).valueOrNull;
    String? kitchen(String id) {
      final k = kitchens?.where((k) => k.id == id).firstOrNull;
      return k == null ? null : _kitchenName(s, k);
    }

    return OwnerPage(
        title: s.production,
        strings: s,
        onRefresh: access.view
            ? () => ref.refresh(productionRunsProvider.future)
            : null,
        bottom: access.view && access.record
            ? Padding(
                padding: EdgeInsets.fromLTRB(
                    OwnerStyle.px(context, 20),
                    OwnerStyle.px(context, 12),
                    OwnerStyle.px(context, 20),
                    OwnerStyle.px(context, 24)),
                child: MNButton(s.productionRecord, onPressed: () async {
                  await context.push(MNRoutes.officeProductionNew);
                  ref.invalidate(productionRunsProvider);
                }))
            : null,
        child: Padding(
            padding: _pad(context),
            child: !access.view
                ? MNNote(s.notAllowed)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        OwnerAsyncView(
                            value: ref.watch(productionRunsProvider),
                            onRetry: () =>
                                ref.invalidate(productionRunsProvider),
                            isEmpty: (rows) => rows.isEmpty,
                            empty: (_) => MNEmptyState(
                                icon: MNIconData.list,
                                image: 'assets/errors/production_state.png',
                                imageWidth: 251,
                                title: s.productionNone),
                            data: (rows) => _Paged(
                                count: rows.length,
                                itemBuilder: (_, i) {
                                  final r = rows[i];
                                  return OwnerCard(
                                      child: OwnerMenuRow(
                                          label: r.recipeName,
                                          subtitle: [
                                            _when(s, r.occurredAt),
                                            if (kitchen(r.kitchenId)
                                                case final k?)
                                              k,
                                            if (r.variance)
                                              s.problemKind(
                                                  'production_variance'),
                                          ].join(' · '),
                                          onTap: () => context.push(
                                              MNRoutes.officeProductionRun(
                                                  r.id))));
                                })),
                      ])));
  }
}

class OfficeProductionRunScreen extends ConsumerWidget {
  final String runId;
  const OfficeProductionRunScreen({super.key, required this.runId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(productionRunProvider(runId));
    return OwnerPage(
        title: value.valueOrNull?.recipeName ?? s.production,
        strings: s,
        onRefresh: () => ref.refresh(productionRunProvider(runId).future),
        child: Padding(
            padding: _pad(context),
            child: OwnerAsyncView(
                value: value,
                onRetry: () => ref.invalidate(productionRunProvider(runId)),
                data: (run) => ProductionRunView(run: run))));
  }
}

/// A run as the server answered it: batches, costs, waste and variance.
class ProductionRunView extends ConsumerWidget {
  final OfficeProductionRun run;
  const ProductionRunView({super.key, required this.run});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = run;
    final kitchens = ref.watch(productionKitchensProvider).valueOrNull;
    final kitchen = kitchens?.where((k) => k.id == r.kitchenId).firstOrNull;
    String cost(num? v) => v == null ? s.costUnknown : productionTsh(v);
    return _Card(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${r.recipeName} · ${s.recipeVersion(r.version)}',
          style: _title(context)),
      if (kitchen != null)
        Text(_kitchenName(s, kitchen), style: _body(context)),
      Text(s.productionAt(_when(s, r.occurredAt)), style: _meta(context)),
      _gap(context, 8),
      Text(s.batchesText(_qty(r.batches)), style: _body(context)),
      if (r.costKnown && r.inputCost != null)
        Text(s.productionInputCost(productionTsh(r.inputCost!)),
            style: _body(context))
      else
        Text(s.productionCostUnknown,
            style: _body(context, color: MNColors.warning)),
      if (r.abnormalLossCost != null && r.abnormalLossCost! > 0)
        Text(s.abnormalLossText(productionTsh(r.abnormalLossCost!)),
            style: _body(context, color: MNColors.error)),
      Text(
          s.productionWasteText(_qty(r.wasteQuantity), _qty(r.wasteAllowed),
              _qty(r.wasteAbnormal)),
          style: _body(context)),
      Text(r.variance ? s.productionVariance : s.productionNoVariance,
          style: _status(
              context, r.variance ? MNColors.warning : OwnerStyle.muted)),
      _gap(context, 8),
      OwnerDetails(title: s.recordDetails, children: [
        Text(s.recipeInputs, style: _meta(context)),
        for (final l in r.inputs.where((l) => !l.waste))
          Text(
              // Older servers send the code only.
              l.name.isEmpty
                  ? '${_qty(l.quantity)} × ${l.product} · ${cost(l.cost)}'
                  : '${_quantity(s, l.quantity, l.unit)} ${l.name} · ${cost(l.cost)}',
              style: _body(context)),
        _gap(context, 4),
        Text(s.recipeOutputs, style: _meta(context)),
        for (final o in r.outputs) ...[
          Text(o.name, style: _body(context)),
          Text(
              s.productionOutputText(_quantity(s, o.quantity, o.unit),
                  o.expected == null ? '—' : _quantity(s, o.expected!, o.unit)),
              style: _meta(context)),
          Text(
              o.allocatedCost == null
                  ? s.costUnknown
                  : s.productionAllocated(productionTsh(o.allocatedCost!)),
              style: _meta(context)),
        ],
      ]),
      if (r.note != null) ...[
        _gap(context, 4),
        Text(s.noteText(r.note!), style: _meta(context)),
      ],
    ]));
  }
}

class OfficeProductionRunForm extends ConsumerStatefulWidget {
  const OfficeProductionRunForm({super.key});
  @override
  ConsumerState<OfficeProductionRunForm> createState() => _RunFormState();
}

class _RunFormState extends ConsumerState<OfficeProductionRunForm> {
  /// One id per run: a retry after no answer sends the same id and body.
  String _clientId = const Uuid().v4();
  String? _kitchen, _recipeId;
  RecipeVersion? _version;
  final _inputs = <_Qty>[], _outputs = <_Qty>[];
  _Qty? _waste;
  final _note = TextEditingController();

  /// When the run was done; null is now. Kitchen staff may record an
  /// earlier run (the server decides which recipe version was in force).
  DateTime? _occurredAt;
  String? _error;
  bool _busy = false;
  ({
    String kitchen,
    String version,
    List<RecipeLineDraft> inputs,
    List<RecipeLineDraft> outputs,
    Object waste,
    DateTime? occurredAt,
    String? note
  })? _pending;
  OfficeProductionRun? _saved;

  bool get _locked => _busy || _pending != null;

  @override
  void dispose() {
    for (final l in [..._inputs, ..._outputs, if (_waste != null) _waste!]) {
      l.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _clear() {
    _disposeLater([..._inputs, ..._outputs, if (_waste != null) _waste!]);
    _inputs.clear();
    _outputs.clear();
    _waste = null;
  }

  void _chooseRecipe(OfficeRecipe recipe) {
    final v = recipe.inForce;
    setState(() {
      _clear();
      _recipeId = recipe.id;
      _version = v;
      if (v == null) return;
      // Every quantity starts empty: the person types what happened.
      final added = ref.read(addedUnitsProvider);
      _inputs.addAll([
        for (final l in v.inputs)
          _Qty(product: l.product, name: l.name, unit: l.unit, added: added)
      ]);
      _outputs.addAll([
        for (final l in v.outputs)
          _Qty(product: l.product, name: l.name, unit: l.unit, added: added)
      ]);
      final primary = v.primaryInput;
      if (primary != null) {
        _waste = _Qty(
            product: primary.product,
            name: s.productionWaste(s.unitName(primary.unit)),
            unit: primary.unit,
            added: added);
      }
    });
  }

  Strings get s => ref.read(stringsProvider);

  String _whenText(DateTime at) =>
      '${s.date(businessDate(at))} · ${s.hhmm(eatClock(at))}';

  Future<void> _pickWhen() async {
    final now = ref.read(clockProvider)();
    final current = _occurredAt ?? now;
    final date = await showMNDateSheet(context,
        title: s.productionWhen,
        initial: businessDate(current),
        first: DateTime.utc(2020),
        last: businessDate(now));
    if (date == null || !mounted) return;
    final time = await showMNTimeSheet(context,
        title: s.productionWhen,
        hour: eatClock(current).hour,
        minute: eatClock(current).minute);
    if (time == null || !mounted) return;
    final selected = businessDayRange(date)
        .$1
        .add(Duration(hours: time.hour, minutes: time.minute));
    setState(() {
      if (selected.isAfter(ref.read(clockProvider)())) {
        _error = s.productionWhenFuture;
      } else {
        _occurredAt = selected;
        _error = null;
      }
    });
  }

  Future<void> _review(String kitchenName, OfficeRecipe recipe) async {
    if (_pending == null) {
      final version = _version;
      final note = _note.text.trim();
      final inputs = [
        for (final l in _inputs)
          if (l.value != null) RecipeLineDraft(l.product, l.value!)
      ];
      final outputs = [
        for (final l in _outputs)
          if (l.value != null) RecipeLineDraft(l.product, l.value!)
      ];
      final waste = _waste;
      final wasteValue = waste == null
          ? 0
          : waste.kg
              ? (waste.text.text.trim().isEmpty
                  ? 0
                  : parseDecimalQuantity(waste.text.text))
              : waste.count;
      if (_kitchen == null ||
          version == null ||
          _inputs.isEmpty ||
          _inputs.first.value == null ||
          [..._inputs, ..._outputs].any((l) => l.invalid) ||
          outputs.isEmpty ||
          wasteValue == null ||
          note.length > 300) {
        setState(() => _error = s.productionQuantitiesInvalid);
        return;
      }
      final yes = await showMNSheet<bool>(context,
          builder: (sheet) => MNSheet(title: s.reviewBeforeSending, children: [
                Text(
                    '$kitchenName · ${recipe.name} · ${s.recipeVersion(version.version)}',
                    style: MNText.resolve(context, MNText.body)),
                Text(s.recipeInputs,
                    style: MNText.resolve(context, MNText.meta)),
                for (final l in _inputs)
                  if (l.value != null)
                    Text('${l.shown(s)} × ${l.name}',
                        style: MNText.resolve(context, MNText.body)),
                Text(s.recipeOutputs,
                    style: MNText.resolve(context, MNText.meta)),
                for (final l in _outputs)
                  if (l.value != null)
                    Text('${l.shown(s)} × ${l.name}',
                        style: MNText.resolve(context, MNText.body)),
                if (waste != null)
                  Text('${waste.name}: ${_qty(num.parse('$wasteValue'))}',
                      style: MNText.resolve(context, MNText.body)),
                if (_occurredAt case final at?)
                  Text(s.productionAt(_whenText(at)),
                      style: MNText.resolve(context, MNText.meta)),
                if (note.isNotEmpty)
                  Text(s.noteText(note),
                      style: MNText.resolve(context, MNText.meta)),
                MNButton(s.productionSend,
                    onPressed: () => Navigator.pop(sheet, true)),
                MNButton.secondary(s.cancel,
                    onPressed: () => Navigator.pop(sheet, false)),
              ]));
      if (yes != true || !mounted) return;
      _pending = (
        kitchen: _kitchen!,
        version: version.id,
        inputs: inputs,
        outputs: outputs,
        waste: wasteValue,
        occurredAt: _occurredAt,
        note: note.isEmpty ? null : note,
      );
    }
    await _send();
  }

  Future<void> _send() async {
    final body = _pending;
    if (body == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final run = await officeProductionCall(
          ref.read(officeSessionProvider.notifier),
          (r) => r.recordRun(
              clientId: _clientId,
              kitchenId: body.kitchen,
              versionId: body.version,
              inputs: body.inputs,
              outputs: body.outputs,
              wasteQuantity: body.waste,
              occurredAt: body.occurredAt,
              note: body.note));
      if (mounted) setState(() => _saved = run);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is OfficeError) {
          // A definite refusal recorded nothing: the form opens again.
          _pending = null;
          _clientId = const Uuid().v4();
          _error = error.kind == OfficeErrorKind.invalid
              ? s.productionQuantitiesInvalid
              : officeErrorText(s, error);
        } else {
          _error = '${officeErrorText(s, error)}\n${s.sendRetryNote}';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final access = productionAccess(ref);
    final kitchens = ref.watch(productionKitchensProvider);
    final recipes = ref.watch(recipesProvider);
    final usable = [
      for (final r in recipes.valueOrNull ?? const <OfficeRecipe>[])
        if (r.inForce != null) r
    ];
    final kitchenRows = kitchens.valueOrNull ?? const <OfficeStockLocation>[];
    if (_kitchen == null && kitchenRows.length == 1) {
      _kitchen = kitchenRows.single.id;
    }
    final kitchen = kitchenRows.where((k) => k.id == _kitchen).firstOrNull;
    final recipe = usable.where((r) => r.id == _recipeId).firstOrNull;
    final saved = _saved;
    Widget body;
    if (!access.record) {
      body = MNNote(s.notAllowed);
    } else if (saved != null) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.productionSaved,
            style: OwnerStyle.text(context, 16,
                weight: 600, color: MNColors.success)),
        _gap(context),
        ProductionRunView(run: saved),
        _gap(context),
        MNButton(s.finish, onPressed: () => context.pop(saved)),
      ]);
    } else {
      body = _Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (kitchens.hasError)
          MNNote(officeErrorText(s, kitchens.error!), error: true)
        else if (kitchens.hasValue && kitchenRows.isEmpty)
          MNNote(s.productionNoKitchens)
        else
          MNSelectField<String>(
              label: s.productionKitchen,
              value: _kitchen,
              emptyText: kitchens.isLoading ? s.loading : null,
              options: [
                for (final k in kitchenRows)
                  MNSelectOption(value: k.id, label: _kitchenName(s, k))
              ],
              onChanged: _locked ? null : (v) => setState(() => _kitchen = v)),
        _gap(context),
        if (recipes.hasError)
          MNNote(officeErrorText(s, recipes.error!), error: true)
        else if (recipes.hasValue && usable.isEmpty)
          MNNote(s.productionNoRecipes)
        else
          MNSelectField<String>(
              label: s.productionRecipe,
              value: _recipeId,
              emptyText: recipes.isLoading ? s.loading : null,
              options: [
                for (final r in usable)
                  MNSelectOption(
                      value: r.id,
                      label: r.name,
                      caption: s.recipeVersion(r.inForce!.version)),
              ],
              onChanged: _locked
                  ? null
                  : (id) =>
                      _chooseRecipe(usable.firstWhere((r) => r.id == id))),
        _gap(context),
        if (_version == null || _kitchen == null)
          MNNote(s.productionPickFirst, tone: MNNoteTone.info)
        else ...[
          OwnerHelp(message: s.productionQuantitiesHelp),
          _gap(context),
          Text(s.recipeInputs, style: _heading(context)),
          for (final (i, l) in _inputs.indexed)
            _QtyField(
                key: ValueKey(l),
                entry: l,
                locked: _locked,
                caption: i == 0
                    ? '${s.unitName(l.unit)} · ${s.recipePrimary}'
                    : null,
                onChanged: () => setState(() {})),
          _gap(context),
          Text(s.recipeOutputs, style: _heading(context)),
          for (final l in _outputs)
            _QtyField(
                key: ValueKey(l),
                entry: l,
                locked: _locked,
                onChanged: () => setState(() {})),
          if (_waste case final w?) ...[
            _gap(context),
            _QtyField(
                entry: w, locked: _locked, onChanged: () => setState(() {})),
          ],
          _gap(context),
          MNFieldButton(
              label: s.productionWhen,
              text: _occurredAt == null ? null : _whenText(_occurredAt!),
              placeholder: s.productionNow,
              icon: MNIconData.calendar,
              onTap: _locked ? null : _pickWhen),
          _gap(context),
          MNTextField(
              label: s.additionalNoteOptional,
              controller: _note,
              enabled: !_locked,
              inputFormatters: [LengthLimitingTextInputFormatter(300)]),
        ],
        if (_error != null) ...[
          _gap(context),
          MNNote(_error!, error: true),
        ],
        _gap(context),
        MNButton(_pending == null ? s.productionSend : s.retry,
            busy: _busy,
            onPressed: _busy || _version == null || recipe == null
                ? null
                : () => _review(
                    kitchen == null ? '' : _kitchenName(s, kitchen), recipe)),
      ]));
    }
    return OwnerPage(
        title: s.productionRecord,
        strings: s,
        child: Padding(padding: _pad(context), child: body));
  }
}
