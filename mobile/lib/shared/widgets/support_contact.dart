import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'components.dart';

/// Omoterra's support number from /config, digits only (e.g. 255712345678),
/// or null when the server has none configured.
final supportPhoneProvider = FutureProvider.autoDispose<String?>((ref) async {
  final config = await ref.watch(repositoryProvider).read('/config');
  final raw = '${(config as Map)['support_phone'] ?? ''}';
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0') && digits.length == 10) {
    digits = '255${digits.substring(1)}';
  }
  return digits.length >= 9 ? digits : null;
});

/// "Call" and "WhatsApp" buttons to reach Omoterra about [topic] (e.g. an
/// order reference, sent as the opening WhatsApp message). Hidden entirely
/// when no support number is configured, so nothing dead is ever shown.
class SupportContact extends ConsumerWidget {
  final String topic;
  const SupportContact({super.key, required this.topic});

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s.couldNotOpenApp)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(supportPhoneProvider).valueOrNull;
    if (phone == null) return const SizedBox.shrink();
    final s = ref.s;
    final message = Uri.encodeComponent(s.supportMessage(topic));
    return Column(
        key: const Key('support_contact'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(s.needHelp),
          Text(s.talkToTeam, style: const TextStyle(color: OColors.secondary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: OmoterraButton(s.call,
                    icon: Icons.call_outlined,
                    secondary: true,
                    onPressed: () => _open(context, Uri.parse('tel:+$phone')))),
            const SizedBox(width: 10),
            Expanded(
                child: OmoterraButton('WhatsApp',
                    icon: Icons.chat_outlined,
                    secondary: true,
                    onPressed: () => _open(context,
                        Uri.parse('https://wa.me/$phone?text=$message')))),
          ]),
        ]);
  }
}
