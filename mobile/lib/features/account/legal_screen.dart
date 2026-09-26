import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

/// The Terms of Use and Privacy Policy, from the bundled
/// assets/legal/legal.json. It is a copy of ops/content/legal.json, which the
/// website renders, so both always say the same thing (test/legal_test.dart
/// fails if they drift apart).
final Future<Map<String, dynamic>> legalContent = rootBundle
    .loadString('assets/legal/legal.json')
    .then((raw) => jsonDecode(raw) as Map<String, dynamic>);

/// Opens [page] ('terms' or 'privacy'). Signed-out members reach it from the
/// phone screen, so the route lives outside /account.
class LegalScreen extends StatelessWidget {
  final String page;
  const LegalScreen(this.page, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            title: Text(page == 'terms' ? s.termsOfUse : s.privacyPolicy)),
        body: FutureBuilder<Map<String, dynamic>>(
            future: legalContent,
            builder: (context, snapshot) {
              final legal = snapshot.data;
              if (legal == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final document = legal[page] as Map<String, dynamic>;
              final sections = (document['sections'] as List)
                  .cast<Map<String, dynamic>>();
              return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _Hero(
                        title: '${document['title']}',
                        summary: '${document['summary']}',
                        updated: '${legal['updated']}'),
                    const SizedBox(height: 14),
                    _Switch(page),
                    if (s.isSwahili) ...[
                      const SizedBox(height: 12),
                      Text(s.legalEnglishOnly,
                          style: const TextStyle(
                              color: OColors.secondary, fontSize: 13)),
                    ],
                    const SizedBox(height: 16),
                    for (final (index, section) in sections.indexed) ...[
                      _Section(number: index + 1, section: section),
                      const SizedBox(height: 12),
                    ],
                    _Contact(legal['operator'] as Map<String, dynamic>),
                  ]);
            }));
  }
}

class _Hero extends StatelessWidget {
  final String title, summary, updated;
  const _Hero(
      {required this.title, required this.summary, required this.updated});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
          decoration: BoxDecoration(
              color: OColors.soft,
              border: Border.all(color: OColors.border),
              borderRadius: BorderRadius.circular(20)),
          child: Stack(children: [
            Positioned.fill(
                child: Image.asset('assets/images/farm-landscape-v1.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0, .45],
                            colors: [
                  OColors.soft.withValues(alpha: .15),
                  OColors.soft
                ])))),
            Padding(
                padding: const EdgeInsets.fromLTRB(18, 96, 18, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.s.omoterraLegal.toUpperCase(),
                          style: const TextStyle(
                              color: OColors.positive,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(title,
                          style: const TextStyle(
                              color: OColors.forest,
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6)),
                      const SizedBox(height: 8),
                      Text(summary,
                          style: const TextStyle(
                              color: OColors.secondary, height: 1.45)),
                      const SizedBox(height: 14),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99)),
                          child: Text(context.s.lastUpdated(updated),
                              style: const TextStyle(
                                  color: OColors.forest,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600))),
                    ])),
          ])));
}

/// Terms / Privacy pill switch; replaces the page so back returns to where
/// the member came from rather than to the other document.
class _Switch extends StatelessWidget {
  final String page;
  const _Switch(this.page);
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    Widget pill(String key, String label) {
      final active = key == page;
      return Expanded(
          child: Material(
              color: active ? OColors.forest : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                  key: Key('legal_switch_$key'),
                  borderRadius: BorderRadius.circular(99),
                  onTap: active
                      ? null
                      : () => context.pushReplacement('/legal/$key'),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: active ? Colors.white : OColors.ink,
                              fontWeight: FontWeight.w600))))));
    }

    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: OColors.border)),
        child: Row(children: [
          pill('terms', s.termsOfUse),
          pill('privacy', s.privacyPolicy),
        ]));
  }
}

class _Section extends StatelessWidget {
  final int number;
  final Map<String, dynamic> section;
  const _Section({required this.number, required this.section});
  @override
  Widget build(BuildContext context) {
    const body = TextStyle(color: OColors.secondary, fontSize: 14.5, height: 1.6);
    final blocks = (section['body'] as List).cast<Map<String, dynamic>>();
    return Surface(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: OColors.soft, shape: BoxShape.circle),
                child: Text('$number',
                    style: const TextStyle(
                        color: OColors.forest,
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${section['heading']}',
                        style: Theme.of(context).textTheme.titleMedium))),
          ]),
          for (final block in blocks) ...[
            const SizedBox(height: 10),
            if (block['p'] != null)
              Text('${block['p']}', style: body)
            else
              for (final item in (block['ul'] as List).cast<String>())
                Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(top: 9, right: 12),
                              decoration: const BoxDecoration(
                                  color: OColors.positive,
                                  shape: BoxShape.circle)),
                          Expanded(child: Text(item, style: body)),
                        ])),
          ],
        ]));
  }
}

class _Contact extends StatelessWidget {
  final Map<String, dynamic> operator;
  const _Contact(this.operator);

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
  Widget build(BuildContext context) {
    final s = context.s;
    final email = '${operator['email']}', phone = '${operator['phone']}';
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: OColors.soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC9E4D3))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.legalQuestions,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(s.operatedBy('${operator['name']}', '${operator['address']}'),
                  style: const TextStyle(color: OColors.secondary, height: 1.5)),
              const SizedBox(height: 14),
              OmoterraButton(email,
                  icon: Icons.mail_outline,
                  onPressed: () => _open(context, Uri.parse('mailto:$email'))),
              const SizedBox(height: 10),
              OmoterraButton(phone,
                  icon: Icons.call_outlined,
                  secondary: true,
                  onPressed: () => _open(context,
                      Uri.parse('tel:${phone.replaceAll(' ', '')}'))),
            ]));
  }
}
