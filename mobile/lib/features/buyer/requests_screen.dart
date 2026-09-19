import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

/// The buyer's own bottom-nav slot for supply requests — split out of
/// OrdersScreen (which used to fold this in as a section at the bottom) once
/// Orders moved to the nav's center button and this slot needed its own
/// screen.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        SectionHeader('Request Supply',
            action: '+ New', onTap: () => context.push('/request')),
        ResourceView('/requests', builder: (rows) {
          final list = rows as List;
          if (list.isEmpty) {
            return EmptyState('No requests yet',
                'Tell Omoterra what you need and we’ll help source it.',
                action: OmoterraButton('Request Supply',
                    onPressed: () => context.push('/request')));
          }
          return Column(children: [
            for (final r in list)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                      onTap: () => context.push('/requests/${r['id']}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Surface(
                          child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  '${label(r['category'])} · ${amount(r['quantity'])} ${r['unit_type']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              StatusText(r['status']),
                            ])),
                        const Icon(Icons.chevron_right, color: OColors.muted),
                      ]))))
          ]);
        }),
      ]);
}
