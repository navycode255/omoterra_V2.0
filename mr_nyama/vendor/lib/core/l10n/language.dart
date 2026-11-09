import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sales/sales_store.dart' show databaseProvider;
import '../../shared/widgets/select_field.dart';
import '../data/database.dart';
import 'strings.dart';

/// Swahili by default; English is a setting (AGENTS.md §3). The choice is
/// kept on this phone in the local database's settings table, so it survives
/// restarts and signing out, and is never sent to the server.
const languageSettingKey = 'app.language';
const supportedLanguages = ['sw', 'en'];

/// The language saved on this phone, or null when none was chosen.
Future<String?> savedLanguage(AppDatabase db) async {
  final row = await (db.select(db.settings)
        ..where((s) => s.key.equals(languageSettingKey)))
      .getSingleOrNull();
  return row != null && supportedLanguages.contains(row.value)
      ? row.value
      : null;
}

Future<void> saveLanguage(AppDatabase db, String code) =>
    db.into(db.settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: languageSettingKey, value: code));

/// Applies the language saved on this phone, if any (at app start).
Future<void> restoreLanguage(WidgetRef ref) async {
  final code = await savedLanguage(ref.read(databaseProvider));
  if (code != null) ref.read(languageProvider.notifier).state = code;
}

/// Switches the app's language now and keeps it for next time.
Future<void> setLanguage(WidgetRef ref, String code) async {
  if (!supportedLanguages.contains(code)) return;
  ref.read(languageProvider.notifier).state = code;
  await saveLanguage(ref.read(databaseProvider), code);
}

/// The language choice sheet (the app's own, never a platform picker).
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) async {
  final s = ref.read(stringsProvider);
  final picked = await showMNSelectSheet<String>(context,
      title: s.language,
      selected: ref.read(languageProvider),
      emptyText: s.language,
      options: [
        for (final code in supportedLanguages)
          MNSelectOption(value: code, label: s.languageName(code)),
      ]);
  if (picked != null) await setLanguage(ref, picked.value);
}
