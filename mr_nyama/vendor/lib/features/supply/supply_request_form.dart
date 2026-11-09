import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client_id.dart';
import '../../core/api/supply_requests.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/quantity.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/workflow_header.dart';
import '../sales/sales_store.dart' show productsProvider;
import 'supply_request_list.dart';

/// Chosen in place of a product: the item is written.
const _writtenItem = '\u0000item';

class _FormLine {
  String? choice;
  int quantity = 1;
  final item = TextEditingController();
  final unit = TextEditingController();
  final price = TextEditingController();

  bool get written => choice == _writtenItem;

  void dispose() {
    item.dispose();
    unit.dispose();
    price.dispose();
  }
}

/// Ombi jipya: what the station needs, a rough price for each, and when. The
/// station is the seller's own and never sent. Online only: a failed send
/// keeps everything typed and sends again with the same client id until a
/// detail changes.
class SupplyRequestFormScreen extends ConsumerStatefulWidget {
  const SupplyRequestFormScreen({super.key});
  @override
  ConsumerState<SupplyRequestFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<SupplyRequestFormScreen> {
  final _lines = <_FormLine>[_FormLine()];
  final _note = TextEditingController();
  final _retry = RetryId();
  late DateTime _needed =
      businessDate(ref.read(clockProvider)()).add(const Duration(days: 1));
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  SupplyDraft? _draft(String clientId) {
    final lines = <SupplyDraftLine>[];
    for (final line in _lines) {
      final price = int.tryParse(line.price.text.trim());
      if (line.choice == null || price == null || line.quantity <= 0) {
        return null;
      }
      if (line.written) {
        if (line.item.text.trim().isEmpty || line.unit.text.trim().isEmpty) {
          return null;
        }
        lines.add(SupplyDraftLine(
            item: line.item.text.trim(),
            unit: line.unit.text.trim(),
            quantity: line.quantity,
            estimatedUnitPrice: price));
      } else {
        lines.add(SupplyDraftLine(
            productId: line.choice,
            quantity: line.quantity,
            estimatedUnitPrice: price));
      }
    }
    return SupplyDraft(
        clientId: clientId,
        neededBy: _needed.toIso8601String().substring(0, 10),
        note: _note.text,
        lines: lines);
  }

  /// Everything typed, so the same details keep the same client id.
  String get _details => jsonEncode({
        'needed': _needed.toIso8601String(),
        'note': _note.text.trim(),
        'lines': [
          for (final l in _lines)
            [l.choice, l.quantity, l.item.text, l.unit.text, l.price.text]
        ],
      });

  Future<void> _send() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final draft = _draft(_retry.forDetails(_details));
    if (draft == null) {
      setState(() => _error = s.supplyNoLines);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await vendorSupply(
          ref.read, (r, token) => r.createSupplyRequest(token, draft));
      ref.invalidate(supplyRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.supplySent)));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(MNRoutes.supplyRequests);
      }
    } catch (error) {
      // The draft stays as typed. A definite refusal says why; a lost
      // connection only says it was not sent.
      if (mounted) {
        setState(() => _error =
            error is SupplyError ? supplyErrorText(s, error) : s.supplyNotSent);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final options = <MNSelectOption<String>>[
      for (final p in products) MNSelectOption(value: p.id, label: p.name),
      MNSelectOption(
          value: _writtenItem, label: s.supplyWrittenItem, action: true),
    ];
    final today = businessDate(ref.read(clockProvider)());
    return Scaffold(
      appBar: MNWorkflowHeader(title: s.supplyNewTitle),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 32),
          children: [
            for (final (i, line) in _lines.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              MNReferenceSurface(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _lineFields(s, line, options))),
            ],
            const SizedBox(height: 12),
            MNButton.secondary(s.supplyAddLine,
                icon: MNIconData.plus,
                onPressed: _busy || _lines.length >= 50
                    ? null
                    : () => setState(() => _lines.add(_FormLine()))),
            const SizedBox(height: 16),
            MNFieldButton(
                label: s.supplyNeededBy,
                text: s.date(_needed),
                placeholder: s.date(_needed),
                icon: MNIconData.calendar,
                onTap: _busy
                    ? null
                    : () async {
                        final picked = await showMNDateSheet(context,
                            title: s.supplyNeededBy,
                            initial: _needed,
                            first: today,
                            last: today.add(const Duration(days: 365)));
                        if (picked != null && mounted) {
                          setState(() => _needed = DateTime.utc(
                              picked.year, picked.month, picked.day));
                        }
                      }),
            const SizedBox(height: 16),
            MNTextField(
                label: s.noteOptional,
                controller: _note,
                enabled: !_busy,
                inputFormatters: [LengthLimitingTextInputFormatter(500)]),
            const SizedBox(height: 8),
            Text(s.supplyEstimateHelp, style: MNText.referenceCaption),
            if (_error != null) ...[
              const SizedBox(height: 12),
              MNNote(_error!, error: true),
            ],
            const SizedBox(height: 16),
            MNButton(s.supplySend,
                busy: _busy, onPressed: _busy ? null : _send),
          ]),
    );
  }

  Widget _lineFields(
      Strings s, _FormLine line, List<MNSelectOption<String>> options) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MNSelectField<String>(
          label: s.supplyProduct,
          value: line.choice,
          options: options,
          emptyText: s.supplyChooseProduct,
          onChanged: _busy ? null : (v) => setState(() => line.choice = v)),
      if (line.written) ...[
        const SizedBox(height: 12),
        MNTextField(
            label: s.supplyItemName,
            controller: line.item,
            enabled: !_busy,
            inputFormatters: [LengthLimitingTextInputFormatter(120)]),
        MNTextField(
            label: s.supplyUnit,
            controller: line.unit,
            enabled: !_busy,
            inputFormatters: [LengthLimitingTextInputFormatter(30)]),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text(s.supplyQuantity, style: MNText.referenceBody)),
        MNQuantitySelector(
            value: line.quantity,
            min: 1,
            max: 999999,
            itemLabel: s.supplyQuantity,
            onChanged:
                _busy ? (_) {} : (v) => setState(() => line.quantity = v)),
      ]),
      const SizedBox(height: 12),
      MNTextField(
          label: s.supplyEstimate,
          controller: line.price,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9)
          ]),
      if (_lines.length > 1)
        MNTextButton(s.supplyRemoveLine,
            onPressed: _busy
                ? null
                : () => setState(() {
                      _lines.remove(line);
                      line.dispose();
                    })),
    ]);
  }
}
