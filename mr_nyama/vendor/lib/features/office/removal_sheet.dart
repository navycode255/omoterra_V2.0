import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import 'people_screens.dart' show officeErrorText;

/// Deletes something added by mistake (owner decision 28 October 2026):
/// what it is for, a reason, a confirmation, then one server call. When the
/// item has records the server refuses and its words (what to do instead)
/// are shown. Pops true once deleted.
Future<bool> showRemovalSheet(BuildContext context,
    {required String title,
    required String body,
    required String name,
    required Future<void> Function(OfficeRemovalRepository r, String reason)
        run}) async {
  final done = await showMNSheet<bool>(context,
      builder: (_) =>
          _RemovalSheet(title: title, body: body, name: name, run: run));
  return done ?? false;
}

class _RemovalSheet extends ConsumerStatefulWidget {
  final String title, body, name;
  final Future<void> Function(OfficeRemovalRepository r, String reason) run;
  const _RemovalSheet(
      {required this.title,
      required this.body,
      required this.name,
      required this.run});
  @override
  ConsumerState<_RemovalSheet> createState() => _RemovalSheetState();
}

class _RemovalSheetState extends ConsumerState<_RemovalSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = s.reasonInvalid);
      return;
    }
    final yes = await showMNConfirmDialog(context,
        title: s.deleteConfirmTitle(widget.name),
        message: widget.body,
        confirmLabel: s.deleteYes,
        cancelLabel: s.cancel,
        destructive: true);
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((repo) {
        if (repo is! OfficeRemovalRepository) {
          throw const OfficeError(OfficeErrorKind.invalid);
        }
        return widget.run(repo as OfficeRemovalRepository, reason);
      });
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
    return MNSheet(title: widget.title, children: [
      MNNote(widget.body, tone: MNNoteTone.warning),
      MNTextField(
          label: s.changeReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton.destructive(widget.title,
          busy: _busy, onPressed: _busy ? null : _delete),
    ]);
  }
}
