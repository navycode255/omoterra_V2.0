import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';

/// Every word a vendor reads lives in lib/core/l10n/strings.dart. This fails
/// when copy is written straight into a screen or shared component: a
/// string literal with letters passed to Text or to an argument that is
/// shown or announced. `lib/dev/` (the development showcase) is exempt.
void main() {
  const shownArguments = [
    'title',
    'label',
    'message',
    'hint',
    'error',
    'caption',
    'semanticLabel',
    'tooltip',
    'confirmLabel',
    'cancelLabel',
    'itemLabel',
    'paymentMethod',
  ];
  final patterns = [
    RegExp(r'''\bText\(\s*['"]'''),
    RegExp(
        r'''\b(?:MNButton|MNButton\.secondary|MNButton\.destructive|MNTextButton)\(\s*['"]'''),
    RegExp('''(?<![\\w'"])(?:${shownArguments.join('|')}):\\s*['"]'''),
  ];

  /// The string literal starting at [start], including `${…}`
  /// interpolations that contain quotes of their own.
  String literalAt(String source, int start) {
    final quote = source[start];
    var i = start + 1;
    while (i < source.length && source[i] != quote) {
      if (source[i] == r'\') {
        i += 2;
      } else if (source.startsWith(r'${', i)) {
        var depth = 1;
        i += 2;
        while (i < source.length && depth > 0) {
          final c = source[i];
          if (c == "'" || c == '"') {
            i += literalAt(source, i).length;
            continue;
          }
          if (c == '{') depth++;
          if (c == '}') depth--;
          i++;
        }
      } else {
        i++;
      }
    }
    return source.substring(start, i + 1);
  }

  /// True when the literal has words of its own, not only interpolated data.
  bool hasWords(String literal) {
    var text = literal.substring(1, literal.length - 1);
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
      } else if (text[i] == r'\') {
        i++; // an escape such as \n is not a word
      } else if (text[i] == r'$') {
        while (i + 1 < text.length && RegExp(r'\w').hasMatch(text[i + 1])) {
          i++;
        }
      } else {
        plain.write(text[i]);
      }
    }
    text = plain.toString();
    return RegExp('[A-Za-z]').hasMatch(text);
  }

  test('no user-visible literals outside strings.dart', () {
    final offenders = <String>[];
    for (final dir in ['lib/app', 'lib/features', 'lib/shared']) {
      for (final file in Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final pattern in patterns) {
          for (final m in pattern.allMatches(source)) {
            final literal = literalAt(source, m.end - 1);
            if (hasWords(literal)) {
              final line = '\n'.allMatches(source.substring(0, m.start)).length;
              offenders.add('${file.path}:${line + 1}');
            }
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('Swahili is the default and every string has both languages', () {
    const sw = Strings('sw');
    const en = Strings('en');
    expect(sw.home, 'Nyumbani');
    expect(sw.sales, 'Mauzo');
    expect(sw.products, 'Bidhaa');
    expect(en.home, 'Home');
    expect(sw.tagline, 'MOTO WAKE HAUZIMI!!');
  });

  test('refusals and operational terminology are localized consistently', () {
    const sw = Strings('sw');
    const en = Strings('en');

    expect(sw.serverRefused('Unexpected English refusal'),
        'Ombi halijakubaliwa. Kagua maelezo kisha ujaribu tena. Ikiendelea, wasiliana na ofisi.');
    expect(en.serverRefused('Unexpected English refusal'),
        'The request was not accepted. Check the details and try again. If it continues, contact the office.');
    expect(sw.damaged, sw.referenceDamaged);
    expect(sw.voidAction, 'Batilisha mauzo haya');
    expect(sw.statusVoided, 'Yamebatilishwa');
    expect(sw.cancelAsk, 'Omba kubatilisha');
    expect(sw.ownerNotifications, 'Arifa');
    expect(sw.notificationsEmpty, 'Hakuna arifa bado.');
    expect(sw.reportSaved, 'Ripoti imehifadhiwa.');
    expect(sw.stationInformation, 'Maelezo ya kituo');
  });
}
