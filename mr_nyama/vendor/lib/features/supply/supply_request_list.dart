import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client_id.dart';
import '../../core/api/providers.dart';
import '../../core/api/supply_requests.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/session.dart';
import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/workflow_header.dart';

/// Runs a seller supply call with the seller session. Requests are online
/// only: a call that cannot reach the server fails and nothing is queued.
Future<T> vendorSupply<T>(R Function<R>(ProviderListenable<R>) read,
    Future<T> Function(VendorSupplyRepository repository, String token) call) {
  final repository = read(vendorRepositoryProvider);
  if (repository is! VendorSupplyRepository) {
    return Future.error(const AuthFailure(AuthFailureKind.offline));
  }
  return read(sessionProvider.notifier)
      .authorised((token) => call(repository as VendorSupplyRepository, token));
}

/// The seller's own requests, newest first.
final supplyRequestsProvider =
    FutureProvider.autoDispose<List<SupplyRequest>>((ref) {
  if (ref.read(vendorRepositoryProvider) is! VendorSupplyRepository) {
    return const <SupplyRequest>[];
  }
  return vendorSupply(ref.read, (r, token) => r.supplyRequests(token));
});

/// Money this seller holds and has not had closed. A repository without
/// supply requests, or a failed call, shows nothing on Nyumbani.
final supplyHeldProvider =
    FutureProvider.autoDispose<List<OutstandingAdvance>>((ref) {
  if (ref.read(vendorRepositoryProvider) is! VendorSupplyRepository) {
    return const <OutstandingAdvance>[];
  }
  return vendorSupply(ref.read, (r, token) => r.supplyOutstanding(token));
});

/// Words for a failed supply call. A definite refusal says why; anything
/// else (no connection, a service problem) says the request was not sent.
String supplyErrorText(Strings s, Object error) => switch (error) {
      SupplyError(:final code) => s.supplyRefusal(code),
      AuthFailure(kind: AuthFailureKind.offline) => s.supplyNotSent,
      AuthFailure() => s.failure(error),
      _ => s.supplyNotSent,
    };

/// One of the seller's requests, read by its id.
final supplyRequestProvider =
    FutureProvider.autoDispose.family<SupplyRequest?, String>((ref, id) async {
  if (ref.read(vendorRepositoryProvider) is! VendorSupplyRepository) {
    return null;
  }
  try {
    return await vendorSupply(
        ref.read, (r, token) => r.supplyRequestById(token, id));
  } on SupplyError catch (e) {
    if (e.status == 404 || e.status == 403) return null;
    rethrow;
  }
});

/// The state of a list inside a page that already scrolls: a loading block
/// of fixed height (the loading rows cannot take unbounded height).
Widget _loaded<T>(AsyncValue<T> value, VoidCallback retry,
        Widget Function(T value) data) =>
    switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => MNErrorState(error: error, onRetry: retry),
      _ => const SizedBox(height: 240, child: MNLoadingState()),
    };

Color _statusColor(String status) => switch (status) {
      'pending' => MNColors.warning,
      'rejected' => MNColors.error,
      'approved' || 'closed' => MNColors.success,
      _ => MNColors.ink,
    };

/// Maombi ya mzigo: the seller's requests with their status and who each
/// waits for, and a button for a new one.
class SupplyRequestListScreen extends ConsumerWidget {
  const SupplyRequestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: MNWorkflowHeader(title: s.supplyTitle),
      body: MNRefreshArea(
          onRefresh: () async {
            ref.invalidate(supplyHeldProvider);
            await ref
                .refresh(supplyRequestsProvider.future)
                .then((_) {}, onError: (_) {});
          },
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 24),
              children: [
                MNButton(s.supplyNewTitle,
                    icon: MNIconData.plus,
                    onPressed: () => context.push(MNRoutes.supplyRequestNew)),
                const SizedBox(height: 16),
                _loaded<List<SupplyRequest>>(
                    ref.watch(supplyRequestsProvider),
                    () => ref.invalidate(supplyRequestsProvider),
                    (rows) => rows.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text(s.supplyNone,
                                    style: MNText.secondary)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                for (final request in rows) ...[
                                  SupplyRequestCard(request: request),
                                  const SizedBox(height: 12),
                                ]
                              ])),
              ])),
    );
  }
}

/// One request opened from a notification.
class SupplyRequestScreen extends ConsumerWidget {
  final String id;
  const SupplyRequestScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: MNWorkflowHeader(title: s.supplyTitle),
      body: MNRefreshArea(
          onRefresh: () async {
            await ref
                .refresh(supplyRequestProvider(id).future)
                .then((_) {}, onError: (_) {});
          },
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 24),
              children: [
                _loaded<SupplyRequest?>(ref.watch(supplyRequestProvider(id)),
                    () => ref.invalidate(supplyRequestProvider(id)), (found) {
                  return found == null
                      ? MNNote(s.supplyNotFound, tone: MNNoteTone.info)
                      : SupplyRequestCard(request: found);
                }),
              ])),
    );
  }
}

/// Lines, status, who it waits for, and what the seller can do next.
class SupplyRequestCard extends ConsumerStatefulWidget {
  final SupplyRequest request;
  const SupplyRequestCard({super.key, required this.request});
  @override
  ConsumerState<SupplyRequestCard> createState() => _SupplyRequestCardState();
}

class _SupplyRequestCardState extends ConsumerState<SupplyRequestCard> {
  final _retry = RetryId();
  bool _busy = false;
  String? _error;

  Future<void> _withdraw() async {
    final s = ref.read(stringsProvider);
    final yes = await showMNConfirmDialog(context,
        title: s.supplyWithdraw,
        confirmLabel: s.supplyWithdraw,
        cancelLabel: s.cancel,
        destructive: true);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = _retry.forDetails('withdraw ${widget.request.id}');
      await vendorSupply(
          ref.read,
          (r, token) =>
              r.withdrawSupplyRequest(token, widget.request.id, clientId: id));
      ref.invalidate(supplyRequestsProvider);
      ref.invalidate(supplyRequestProvider(widget.request.id));
      ref.invalidate(supplyHeldProvider);
    } catch (error) {
      if (mounted) setState(() => _error = supplyErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _explain() async {
    final done = await showMNSheet<bool>(context,
        builder: (_) => SupplySettleSheet(request: widget.request));
    if (done == true) {
      ref.invalidate(supplyRequestsProvider);
      ref.invalidate(supplyHeldProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = widget.request;
    final status = s.supplyStatusLine(r.status, r.waitingKind, r.chain);
    final refusal = r.steps.where((x) => x.approve == false).firstOrNull;
    return MNReferenceSurface(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(status,
                      style: MNText.withWeight(
                              MNText.referenceBody, FontWeight.w700)
                          .copyWith(color: _statusColor(r.status))),
                  const SizedBox(height: 6),
                  for (final line in r.lines) ...[
                    Text('${line.name} · ${line.quantity} ${line.unit}',
                        style: MNText.referenceBody),
                    if (r.deliveries.isNotEmpty && line.received != null)
                      Text('${s.supplyReceived}: ${line.received} ${line.unit}',
                          style: MNText.referenceCaption),
                  ],
                  const SizedBox(height: 6),
                  Text(
                      '${s.supplyEstimatedTotal}: ${formatTsh(r.estimatedTotal)}',
                      style: MNText.referenceCaption),
                  if (r.neededBy.isNotEmpty)
                    Text('${s.supplyNeededBy}: ${r.neededBy}',
                        style: MNText.referenceCaption),
                  if (refusal?.reason != null && refusal!.reason!.isNotEmpty)
                    Text(refusal.reason!, style: MNText.referenceCaption),
                  if (r.advance != null)
                    Text('${s.supplyGiven}: ${formatTsh(r.advance!.amount)}',
                        style: MNText.referenceCaption),
                  if (r.settlement != null)
                    Text(
                        '${s.supplySpent.replaceAll(' (TSh)', '')}: ${formatTsh(r.settlement!.spent)}',
                        style: MNText.referenceCaption),
                  if (r.status == SupplyStatus.purchased)
                    Text(s.supplyAwaitingConfirm,
                        style: MNText.referenceCaption
                            .copyWith(color: MNColors.warning)),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    MNNote(_error!, error: true),
                  ],
                  if (r.status == SupplyStatus.funded) ...[
                    const SizedBox(height: 12),
                    MNButton(s.supplyExplain, onPressed: _explain),
                  ],
                  if (r.isPending) ...[
                    const SizedBox(height: 12),
                    MNButton.secondary(s.supplyWithdraw,
                        busy: _busy, onPressed: _busy ? null : _withdraw),
                  ],
                ])));
  }
}

/// "Eleza matumizi": what was spent, the change returned and the supplier.
/// Spent plus change must equal the money given; spending more is allowed
/// only with no change, and the office has to accept it.
class SupplySettleSheet extends ConsumerStatefulWidget {
  final SupplyRequest request;
  const SupplySettleSheet({super.key, required this.request});
  @override
  ConsumerState<SupplySettleSheet> createState() => _SupplySettleState();
}

class _SupplySettleState extends ConsumerState<SupplySettleSheet> {
  final _spent = TextEditingController(),
      _change = TextEditingController(),
      _supplier = TextEditingController();
  final _retry = RetryId();
  String? _error;
  bool _busy = false;

  int get _given => widget.request.advance?.amount ?? 0;
  int? get _spentValue => int.tryParse(_spent.text.trim());
  int get _changeValue => int.tryParse(_change.text.trim()) ?? 0;

  /// Adds up, or is an overspend with no change.
  bool get _addsUp {
    final spent = _spentValue;
    if (spent == null) return false;
    return spent + _changeValue == _given ||
        (spent > _given && _changeValue == 0);
  }

  @override
  void dispose() {
    _spent.dispose();
    _change.dispose();
    _supplier.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = ref.read(stringsProvider);
    if (_spentValue == null || _supplier.text.trim().isEmpty) {
      setState(() => _error = s.supplyExplainBlank);
      return;
    }
    if (!_addsUp) {
      setState(() => _error = s.supplyDoesNotAdd(groupDigits(_given)));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final spent = _spentValue!, change = _changeValue;
      final supplier = _supplier.text.trim();
      final id =
          _retry.forDetails('${widget.request.id}|$spent|$change|$supplier');
      await vendorSupply(
          ref.read,
          (r, token) => r.settleSupply(token, widget.request.id,
              clientId: id,
              spent: spent,
              changeReturned: change,
              supplier: supplier));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = supplyErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final over = (_spentValue ?? 0) - _given;
    return MNSheet(title: s.supplyExplain, children: [
      Text('${s.supplyGiven}: ${formatTsh(_given)}',
          style: MNText.resolve(context, MNText.body)),
      MNTextField(
          label: s.supplySpent,
          controller: _spent,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _error = null),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ]),
      MNTextField(
          label: s.supplyChange,
          controller: _change,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _error = null),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ]),
      MNTextField(
          label: s.supplySupplier,
          controller: _supplier,
          enabled: !_busy,
          onChanged: (_) => setState(() => _error = null),
          inputFormatters: [LengthLimitingTextInputFormatter(120)]),
      if (over > 0)
        MNNote(s.supplyOverspend(groupDigits(over)), tone: MNNoteTone.info),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.supplyExplainSend,
          busy: _busy, onPressed: _busy ? null : _send),
    ]);
  }
}

/// Nyumbani: money this seller holds and has not explained, with the action
/// that explains it. Shows nothing when there is none or it cannot load.
class SupplyHeldRow extends ConsumerWidget {
  const SupplyHeldRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = [
      for (final o in ref.watch(supplyHeldProvider).valueOrNull ??
          const <OutstandingAdvance>[])
        if (o.status == SupplyStatus.funded) o
    ];
    if (open.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final total = open.fold<int>(0, (sum, o) => sum + o.amount);
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: MNReferenceSurface(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.supplyHeld(groupDigits(total)),
                          style: MNText.withWeight(
                                  MNText.referenceBody, FontWeight.w600)
                              .copyWith(color: MNColors.warning)),
                      const SizedBox(height: 12),
                      MNButton.secondary(s.supplyExplain, onPressed: () async {
                        if (open.length > 1) {
                          context.push(MNRoutes.supplyRequests);
                          return;
                        }
                        final done = await showMNSheet<bool>(context,
                            builder: (_) => SupplySettleSheet(
                                request: open.first.asRequest()));
                        if (done == true) {
                          ref.invalidate(supplyHeldProvider);
                          ref.invalidate(supplyRequestsProvider);
                        }
                      }),
                    ]))));
  }
}
