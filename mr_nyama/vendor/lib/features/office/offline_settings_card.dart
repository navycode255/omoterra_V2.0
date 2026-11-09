import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import 'owner_reference.dart';
import 'people_screens.dart' show officeErrorText;

/// The three offline-unlock limits (Phase 11, policies §10): how long a
/// vendor may work offline, when the PIN is asked again, and how many wrong
/// PINs erase the offline grant. Until all three are set, offline unlock is
/// off. Values come only from here; the app suggests none.
class OfficeOfflineCard extends ConsumerStatefulWidget {
  final Map<String, int> values;
  final VoidCallback onSaved;
  final bool showExplanation;
  const OfficeOfflineCard(
      {super.key,
      required this.values,
      required this.onSaved,
      this.showExplanation = true});
  @override
  ConsumerState<OfficeOfflineCard> createState() => _OfflineState();
}

class _OfflineState extends ConsumerState<OfficeOfflineCard> {
  late final _fields = {
    for (final (key, _, _) in OfficeMoneySettings.offlineLimits)
      key: TextEditingController(
          text: widget.values[key] == null ? '' : '${widget.values[key]}'),
  };
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final changed = <String, int>{};
    for (final (key, low, high) in OfficeMoneySettings.offlineLimits) {
      final text = _fields[key]!.text.trim();
      if (text.isEmpty) continue;
      final n = int.tryParse(text);
      if (n == null || n < low || n > high) {
        setState(() => _error = s.offlineLimitInvalid(s.offlineLimitName(key)));
        return;
      }
      if (n != widget.values[key]) changed[key] = n;
    }
    if (changed.isEmpty) {
      setState(() => _error = s.nothingChanged);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reason = s.offlineSaveReason([
        for (final e in changed.entries) '${e.key} = ${e.value}'
      ].join(', '));
      for (final e in changed.entries) {
        await ref
            .read(officeSessionProvider.notifier)
            .guard((r) => r.saveSetting(e.key, value: e.value, reason: reason));
      }
      widget.onSaved();
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final on = OfficeMoneySettings.offlineLimits
        .every((l) => widget.values.containsKey(l.$1));
    return OwnerCard(
        child: Padding(
            padding: EdgeInsets.all(OwnerStyle.px(context, 16)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.showExplanation)
                    Text(s.offlineSettingsTitle,
                        style: OwnerStyle.text(context, 16, weight: 600)),
                  SizedBox(height: OwnerStyle.px(context, 4)),
                  Text(on ? s.offlineOn : s.offlineOff,
                      style: OwnerStyle.text(context, 15, weight: 600)),
                  if (widget.showExplanation)
                    Text(s.offlineSettingsHelp,
                        style: OwnerStyle.text(context, 13,
                            color: OwnerStyle.muted)),
                  for (final (key, _, _)
                      in OfficeMoneySettings.offlineLimits) ...[
                    SizedBox(height: OwnerStyle.px(context, 12)),
                    MNTextField(
                        label: s.offlineLimitName(key),
                        hint:
                            widget.values[key] == null ? s.offlineNotSet : null,
                        controller: _fields[key]!,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4)
                        ]),
                  ],
                  if (_error != null) ...[
                    SizedBox(height: OwnerStyle.px(context, 8)),
                    MNNote(_error!, error: true),
                  ],
                  SizedBox(height: OwnerStyle.px(context, 12)),
                  MNButton(s.saveChanges,
                      busy: _busy, onPressed: _busy ? null : _save),
                ])));
  }
}
