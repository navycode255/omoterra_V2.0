import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_lost_sales.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import 'people_screens.dart' show officeErrorText;

/// "Maliza kuingia kwenye simu": a reason, a confirmation, then the server ends
/// every sign-in of the vendor. The account stays active. True once ended.
Future<bool> endPhoneAccessSheet(BuildContext context, String vendorId) async =>
    await showMNSheet<bool>(context,
        builder: (_) => _EndPhoneSheet(vendorId: vendorId)) ??
    false;

class _EndPhoneSheet extends ConsumerStatefulWidget {
  final String vendorId;
  const _EndPhoneSheet({required this.vendorId});
  @override
  ConsumerState<_EndPhoneSheet> createState() => _EndPhoneState();
}

class _EndPhoneState extends ConsumerState<_EndPhoneSheet> {
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
    if (reason.length < 3) {
      setState(() => _error = s.reasonInvalid);
      return;
    }
    final yes = await showMNConfirmDialog(context,
        title: s.endPhoneAccess,
        message: s.endPhoneConfirm,
        confirmLabel: s.endPhoneYes,
        cancelLabel: s.cancel,
        destructive: true,
        sheet: true);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeLostSalesRepository)
              .endPhoneAccess(widget.vendorId, reason: reason));
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
    return MNSheet(title: s.endPhoneAccess, children: [
      MNNote(s.endPhoneHelp, tone: MNNoteTone.warning),
      MNTextField(
          label: s.changeReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton.destructive(s.endPhoneAccess,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
