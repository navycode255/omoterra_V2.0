import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_flow.dart' show displayPhone;
import '../../core/contacts/contact_phones.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'input_field.dart';
import 'note.dart';
import 'select_field.dart';
import 'sheet.dart';

/// The most rows the contacts sheet lists at once; typing narrows the rest.
const contactSheetLimit = 80;

/// The contacts button inside a phone field: opens [pickContactPhone] and
/// hands the chosen `+255…` number to [onPicked]. Typing stays possible.
class MNContactPickButton extends ConsumerWidget {
  final ValueChanged<String> onPicked;
  final bool enabled;
  const MNContactPickButton(
      {super.key, required this.onPicked, this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return MNIconButton(MNIconData.contacts,
        label: strings.contactsPick,
        color: MNColors.ink,
        onPressed: !enabled
            ? null
            : () async {
                final phone = await pickContactPhone(context, ref);
                if (phone != null) onPicked(phone);
              });
  }
}

/// Asks to read the phone's contacts, then lets the user pick one number in
/// the app's own sheet. Returns the `+255…` number, or null when dismissed,
/// refused or unreadable (the sheet says so; the field stays editable).
Future<String?> pickContactPhone(BuildContext context, WidgetRef ref) async {
  final strings = ref.read(stringsProvider);
  final source = ref.read(contactPhoneSourceProvider);
  List<ContactPhone>? phones;
  String? problem;
  try {
    if (await source.requestAccess() == ContactAccess.granted) {
      phones = await source.phones();
    } else {
      problem = strings.contactsDenied;
    }
  } catch (_) {
    problem = strings.contactsFailed;
  }
  if (!context.mounted) return null;
  if (problem != null) {
    await showMNSheet<void>(context,
        builder: (_) => MNSheet(
            title: strings.contactsTitle,
            children: [MNNote(problem!, tone: MNNoteTone.warning)]));
    return null;
  }
  final picked = await showMNSheet<String>(context,
      builder: (sheet) => _ContactSheet(
          phones: phones!, onPick: (p) => Navigator.pop(sheet, p)));
  return picked;
}

class _ContactSheet extends ConsumerStatefulWidget {
  final List<ContactPhone> phones;
  final ValueChanged<String> onPick;
  const _ContactSheet({required this.phones, required this.onPick});

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ContactPhone c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return c.name.toLowerCase().contains(q) ||
        (digits.isNotEmpty && c.phone.contains(digits.replaceFirst(RegExp(r'^0'), '')));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final found = widget.phones.where(_matches).toList();
    final shown = found.take(contactSheetLimit).toList();
    return MNSheet(title: strings.contactsTitle, children: [
      if (widget.phones.isEmpty)
        MNNote(strings.contactsEmpty, tone: MNNoteTone.info)
      else ...[
        MNTextField(
            label: strings.contactsSearch,
            controller: _search,
            icon: MNIconData.search,
            onChanged: (v) => setState(() => _query = v)),
        if (shown.isEmpty)
          MNNote(strings.contactsNoMatch, tone: MNNoteTone.info)
        else
          MNSelectList<String>(
              options: [
                for (final c in shown)
                  MNSelectOption(
                      value: c.phone,
                      label: c.name,
                      caption: displayPhone(c.phone)),
              ],
              selected: null,
              onPick: (o) => widget.onPick(o.value)),
        if (found.length > shown.length)
          MNNote(strings.contactsMore(found.length - shown.length),
              tone: MNNoteTone.info),
      ],
    ]);
  }
}
