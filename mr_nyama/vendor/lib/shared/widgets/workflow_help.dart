import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'sheet.dart';

/// Operational explanations stay available without filling the task screen.
class MNWorkflowHelp extends ConsumerWidget {
  final List<String> messages;
  final String? title;
  const MNWorkflowHelp({super.key, required this.messages, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return MNIconButton(MNIconData.help,
        label: strings.help,
        onPressed: () => showMNSheet<void>(context,
            builder: (_) => MNSheet(title: title ?? strings.help, children: [
                  for (final message in messages)
                    Text(message, style: MNText.resolve(context, MNText.body))
                ])));
  }
}
