import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
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
    final s = ref.s;
    final ready = _confirm.text.trim().toUpperCase() == s.deleteWord;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.deleteAccount)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: OColors.soft, borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.deletePermanently,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _Point(s.deletePointPersonal),
                    _Point(s.deletePointSupplier),
                    _Point(s.deletePointRecords),
                    _Point(s.cannotBeUndone),
                  ])),
          const SizedBox(height: 20),
          Text(s.deleteBlockedNote,
              style: const TextStyle(color: OColors.secondary)),
          const SizedBox(height: 24),
          Text(s.typeToConfirm(s.deleteWord),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
              key: const Key('delete_confirm_field'),
              controller: _confirm,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: s.deleteWord),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),
          if (_error != null) ErrorState(_error!),
          OmoterraButton(s.deleteMyAccount,
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
