import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client_id.dart';
import '../../core/api/notifications.dart';
import '../../core/api/providers.dart';
import '../../core/api/office_repository.dart'
    show OfficeError, OfficeErrorKind;
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/select_field.dart';
import '../office/owner_reference.dart' show OwnerPage;
import '../office/people_screens.dart'
    show officeErrorText, officeStationsProvider, officeVendorsProvider;

/// Messages the signed-in staff member may see (their own, or all for the
/// business-wide roles), newest first.
final sentMessagesProvider =
    FutureProvider.autoDispose<List<OfficeMessage>>((ref) {
  if (ref.read(officeRepositoryProvider) is! OfficeNotificationsRepository) {
    return const <OfficeMessage>[];
  }
  return ref
      .read(officeSessionProvider.notifier)
      .guard((r) => (r as OfficeNotificationsRepository).sentMessages());
});

/// "Tuma ujumbe": a short message to one vendor or a whole kituo; it lands in
/// their notifications (and as a push once step 13B is in).
class OfficeMessageScreen extends ConsumerStatefulWidget {
  const OfficeMessageScreen({super.key});
  @override
  ConsumerState<OfficeMessageScreen> createState() =>
      _OfficeMessageScreenState();
}

class _OfficeMessageScreenState extends ConsumerState<OfficeMessageScreen> {
  final _body = TextEditingController();
  String _to = 'station';
  String? _station, _vendor;
  String _clientId = newClientId();
  bool _busy = false;
  String? _error, _done;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  bool get _ready =>
      _body.text.trim().isNotEmpty &&
      (_to == 'station' ? _station != null : _vendor != null);

  Future<void> _send() async {
    if (_busy || !_ready) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      final sent = await ref.read(officeSessionProvider.notifier).guard((r) =>
          (r as OfficeNotificationsRepository).sendMessage(
              clientId: _clientId,
              body: _body.text.trim(),
              stationId: _to == 'station' ? _station : null,
              vendorId: _to == 'vendor' ? _vendor : null));
      if (!mounted) return;
      setState(() {
        _done = sent.recipients == 0
            ? s.messageNobody
            : s.messageSent(sent.recipients);
        _body.clear();
        _clientId = newClientId();
      });
      ref.invalidate(sentMessagesProvider);
    } on OfficeError catch (error) {
      if (mounted) {
        setState(() => _error = error.kind == OfficeErrorKind.forbidden
            ? s.messageNotYourStation
            : officeErrorText(s, error));
      }
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final stations = ref.watch(officeStationsProvider).valueOrNull ?? const [];
    final vendors = ref.watch(officeVendorsProvider).valueOrNull ?? const [];
    final sent = ref.watch(sentMessagesProvider).valueOrNull ?? const [];
    return OwnerPage(
      title: s.messageNew,
      strings: s,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MNSelectField<String>(
              label: s.messageTo,
              value: _to,
              options: [
                MNSelectOption(value: 'station', label: s.messageToStation),
                MNSelectOption(value: 'vendor', label: s.messageToVendor),
              ],
              onChanged: _busy ? null : (v) => setState(() => _to = v)),
          const SizedBox(height: MNSpace.x3),
          if (_to == 'station')
            MNSelectField<String>(
                label: s.messageStation,
                value: _station,
                options: [
                  for (final st in stations)
                    MNSelectOption(value: st.id, label: st.name),
                ],
                onChanged: _busy ? null : (v) => setState(() => _station = v))
          else
            MNSelectField<String>(
                label: s.messageVendor,
                value: _vendor,
                options: [
                  for (final v in vendors.where((v) => !v.suspended))
                    MNSelectOption(
                        value: v.id, label: v.name, caption: v.stationName),
                ],
                onChanged: _busy ? null : (v) => setState(() => _vendor = v)),
          const SizedBox(height: MNSpace.x3),
          MNTextField(
              label: s.messageBody,
              hint: s.messageHint,
              controller: _body,
              enabled: !_busy,
              maxLines: 4,
              onChanged: (_) => setState(() {
                    _error = null;
                    _done = null;
                  }),
              inputFormatters: [LengthLimitingTextInputFormatter(500)]),
          if (_error != null) ...[
            const SizedBox(height: MNSpace.x3),
            MNNote(_error!, error: true),
          ],
          if (_done != null) ...[
            const SizedBox(height: MNSpace.x3),
            MNNote(_done!, tone: MNNoteTone.info),
          ],
          const SizedBox(height: MNSpace.x4),
          MNButton(s.messageSend,
              busy: _busy, onPressed: _ready && !_busy ? _send : null),
          if (sent.isNotEmpty) ...[
            const SizedBox(height: MNSpace.x6),
            Text(s.messagesSent, style: MNText.resolve(context, MNText.meta)),
            const SizedBox(height: MNSpace.x2),
            for (final m in sent)
              Padding(
                padding: const EdgeInsets.only(bottom: MNSpace.x3),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${m.vendor.isNotEmpty ? m.vendor : m.station} · '
                          '${s.messageRecipients(m.recipients)} · '
                          '${s.notificationTime(m.createdAt, DateTime.now())}',
                          style: MNText.resolve(context, MNText.meta)),
                      const SizedBox(height: MNSpace.x1),
                      Text(m.body, style: MNText.resolve(context, MNText.body)),
                    ]),
              ),
          ],
          const SizedBox(height: MNSpace.x6),
        ]),
      ),
    );
  }
}
