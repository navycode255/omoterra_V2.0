import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every word a member reads lives in lib/core/l10n/strings.dart, in English
/// and Swahili. This fails when copy is written straight into a screen again:
/// a string literal with letters passed to Text, a field's hint or label, a
/// tooltip, a button, an empty state or a snackbar.
void main() {
  // Brand and proper names that read the same in both languages.
  const allowed = {
    'Omoterra',
    'WhatsApp',
    'TZS',
    'OMT-',
    'kg',
    '© OpenStreetMap contributors',
  };

  // Places where user-visible text is passed as a literal. Each pattern
  // ends just before the literal's opening quote.
  const quote = r'''(?=r?['"])''';
  const notInKey = r'''(?<![\w'"])''';
  final patterns = [
    // Text('…'), const Text("…"), SelectableText too.
    RegExp(r'\b(?:Text|SelectableText)\(\s*' + quote),
    // Named arguments that are shown to the member.
    RegExp('$notInKey(?:$_shownArguments):\\s*$quote'),
    // App widgets whose first argument is visible copy.
    RegExp('\\b(?:$_copyWidgets)\\(\\s*$quote'),
    // A form field's title (its second argument).
    RegExp(r"\bFormFieldSpec\(\s*'[^']*',\s*" + quote),
  ];

  /// The string literal starting at [start] (optionally `r`-prefixed),
  /// including any `${…}` interpolations with quotes of their own.
  String literalAt(String source, int start) {
    var i = start;
    final raw = source[i] == 'r';
    if (raw) i++;
    final quote = source[i];
    i++;
    while (i < source.length && source[i] != quote) {
      if (!raw && source[i] == r'\') {
        i += 2;
        continue;
      }
      if (!raw && source.startsWith(r'${', i)) {
        var depth = 1;
        i += 2;
        while (i < source.length && depth > 0) {
          final c = source[i];
          if (c == '{') depth++;
          if (c == '}') depth--;
          if (c == "'" || c == '"') {
            i += literalAt(source, i).length;
            continue;
          }
          i++;
        }
        continue;
      }
      i++;
    }
    return source.substring(start, i + 1);
  }

  bool hasWords(String literal) {
    final body = literal.replaceFirst(RegExp('^r'), '');
    var text = body.substring(1, body.length - 1);
    // Interpolated values are data, not copy.
    final plain = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (text.startsWith(r'${', i)) {
        var depth = 1;
        i += 2;
        while (i < text.length && depth > 0) {
          if (text[i] == "'" || text[i] == '"') {
            i += literalAt(text, i).length;
            continue;
          }
          if (text[i] == '{') depth++;
          if (text[i] == '}') depth--;
          i++;
        }
        i--;
        continue;
      }
      plain.write(text[i]);
    }
    text = plain.toString().replaceAll(RegExp(r'\$\w+'), '').trim();
    if (allowed.contains(text) || text.startsWith('https://')) return false;
    return RegExp('[A-Za-z]{2,}').hasMatch(text);
  }

  Iterable<String> literals(String source) sync* {
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(source)) {
        yield literalAt(source, match.end);
      }
    }
  }

  List<String> offenders() {
    final found = <String>[];
    final roots = [
      'lib/features',
      'lib/shared',
      'lib/core/routing',
      'lib/core/notifications',
    ];
    for (final root in roots) {
      for (final file in Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('.g.dart') &&
              !f.path.endsWith('.freezed.dart'))) {
        // Comments may quote copy; only code counts.
        final source = file
            .readAsStringSync()
            .split('\n')
            .map((line) => line.trimLeft().startsWith('//') ? '' : line)
            .join('\n');
        for (final pattern in patterns) {
          for (final match in pattern.allMatches(source)) {
            final literal = literalAt(source, match.end);
            if (hasWords(literal)) {
              final line = '\n'.allMatches(source.substring(0, match.start));
              found.add('${file.path}:${line.length + 1}  $literal');
            }
          }
        }
      }
    }
    return found;
  }

  test('screens take their copy from Strings, not literals', () {
    final found = offenders();
    expect(found, isEmpty,
        reason: 'Move these into lib/core/l10n/strings.dart with a Swahili '
            'translation:\n${found.join('\n')}');
  });

  test('the guard catches a literal it is meant to catch', () {
    final dir = Directory.systemTemp.createTempSync('l10n_guard');
    addTearDown(() => dir.deleteSync(recursive: true));
    const samples = [
      "Text('Add stock')",
      'const Text("Pause listing")',
      "InputDecoration(hintText: 'Search product')",
      "IconButton(tooltip: 'Close')",
      "OmoterraButton('Save changes')",
      "SnackBar(content: Text('Saved.'))",
      "FormFieldSpec('name', 'Your name')",
    ];
    for (final sample in samples) {
      final hit = literals(sample).any(hasWords);
      expect(hit, isTrue, reason: sample);
    }
    for (final sample in [
      "Text(s.addStock)",
      "Text('Omoterra')",
      "Text('\${amount(n)} · \${s.unit(u)}')",
      "Text('%')",
    ]) {
      final hit = literals(sample).any(hasWords);
      expect(hit, isFalse, reason: sample);
    }
  });
}

const _shownArguments = 'hintText|labelText|helperText|errorText|suffixText|'
    'prefixText|tooltip|semanticsLabel|label|title|subtitle|message|button|'
    'reviewTitle|reviewCopy';
const _copyWidgets = 'OmoterraButton|EmptyState|SectionHeader|'
    'OmoterraTextField|OmoterraDateField|ApiFailure';
