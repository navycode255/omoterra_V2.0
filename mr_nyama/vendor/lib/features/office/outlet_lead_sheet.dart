import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/office_outlet_lead.dart';
import '../../core/api/office_repository.dart' show OfficeError;
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import 'office_errors.dart';

/// "Mfanye Kiongozi wa Kituo" / "Ondoa ukiongozi": a reason, a confirmation,
/// then the server makes or ends the link. True once it is saved.
Future<bool> outletLeadSheet(BuildContext context,
        {required String vendorId,
        required String name,
        required bool make}) async =>
    await showMNSheet<bool>(context,
        builder: (_) =>
            _LeadSheet(vendorId: vendorId, name: name, make: make)) ??
    false;

class _LeadSheet extends ConsumerStatefulWidget {
  final String vendorId, name;
  final bool make;
  const _LeadSheet(
      {required this.vendorId, required this.name, required this.make});
  @override
  ConsumerState<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends ConsumerState<_LeadSheet> {
  final _reason = TextEditingController();
  // One id per attempt: a failed save is retried with the same id.
  var _clientId = const Uuid().v4();
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
    if (reason.length < 3) {
      setState(() => _error = s.reasonInvalid);
      return;
    }
    final title = widget.make ? s.makeLead : s.endLead;
    final yes = await showMNConfirmDialog(context,
        title: title,
        message: widget.make ? s.makeLeadHelp : s.endLeadHelp,
        confirmLabel: title,
        cancelLabel: s.cancel,
        destructive: !widget.make,
        sheet: true);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) {
        final repo = r as OfficeOutletLeadRepository;
        return widget.make
            ? repo.makeOutletLead(widget.vendorId,
                clientId: _clientId, reason: reason)
            : repo.endOutletLead(widget.vendorId,
                clientId: _clientId, reason: reason);
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      // A definite refusal (the server answered) ends this attempt: the next
      // one is new. A failed or unknown send keeps the id for the retry.
      if (error is OfficeError) _clientId = const Uuid().v4();
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final title = widget.make ? s.makeLead : s.endLead;
    return MNSheet(title: title, children: [
      MNNote(widget.make ? s.makeLeadHelp : s.endLeadHelp,
          tone: widget.make ? MNNoteTone.info : MNNoteTone.warning),
      MNTextField(
          label: s.changeReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      widget.make
          ? MNButton(title, busy: _busy, onPressed: _busy ? null : _save)
          : MNButton.destructive(title,
              busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
