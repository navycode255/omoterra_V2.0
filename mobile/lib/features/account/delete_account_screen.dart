import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

/// Explains what deletion does, blocks accidental taps behind a typed
/// confirmation, and reports server-side reasons deletion can't proceed yet
/// (an order in progress, an unsettled payout, stock reserved for a buyer).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).write('/me', {}, method: 'DELETE');
      await ref.read(sessionProvider.notifier).logout();
      if (mounted) context.go('/welcome');
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _confirm.text.trim().toUpperCase() == 'DELETE';
    return Scaffold(
        appBar: const OmoterraAppBar(title: Text('Delete account')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: OColors.soft, borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This permanently deletes your account',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    const _Point(
                        'Your name, phone number and saved addresses are removed.'),
                    const _Point(
                        'A supplier profile, farm location, photos and video are removed and your stock is taken down.'),
                    const _Point(
                        'Past orders and payouts stay on record for Omoterra’s accounts, but are no longer linked to your name.'),
                    const _Point('This can’t be undone.'),
                  ])),
          const SizedBox(height: 20),
          const Text(
              'If you have an order in progress, an unpaid payout, or stock reserved for a buyer, finish or settle it first — deletion is blocked until then.',
              style: TextStyle(color: OColors.secondary)),
          const SizedBox(height: 24),
          Text('Type DELETE to confirm',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
              key: const Key('delete_confirm_field'),
              controller: _confirm,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'DELETE'),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),
          if (_error != null) ErrorState(_error!),
          OmoterraButton('Delete my account',
              busy: _busy, onPressed: ready && !_busy ? _delete : null),
        ]));
  }
}

class _Point extends StatelessWidget {
  final String text;
  const _Point(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.circle, size: 6, color: OColors.secondary)),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]));
}
