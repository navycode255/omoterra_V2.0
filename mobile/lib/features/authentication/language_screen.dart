import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLanguageProvider);
    final s = ref.s;
    return Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    const Icon(Icons.language, color: OColors.forest, size: 44),
                    const SizedBox(height: 24),
                    Text(s.chooseLanguageEn,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(s.chooseLanguageSw,
                        style: const TextStyle(
                            fontSize: 18, color: OColors.secondary)),
                    const SizedBox(height: 28),
                    for (final entry in Strings.languageNames.entries)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => ref
                                  .read(sessionProvider.notifier)
                                  .setLanguage(entry.key),
                              child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                      color: selected == entry.key
                                          ? OColors.soft
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: selected == entry.key
                                              ? OColors.forest
                                              : OColors.border)),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(entry.value,
                                            style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600))),
                                    if (selected == entry.key)
                                      const Icon(Icons.check_circle,
                                          color: OColors.forest)
                                  ])))),
                    const Spacer(),
                    OmoterraButton(s.continueLabel,
                        onPressed: () => context.go('/welcome')),
                  ]))),
    );
  }
}
