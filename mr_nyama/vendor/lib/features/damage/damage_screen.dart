import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/workflow_header.dart';
import '../../shared/widgets/workflow_help.dart';
import '../../shared/widgets/vendor_reference.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/product_card.dart';
import '../sales/product_images.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/rows.dart';
import '../../shared/widgets/states.dart';
import 'damage_store.dart';

final _recentDamageProvider = StreamProvider.autoDispose<List<DamageEntry>>(
    (ref) =>
        ref.watch(damageStoreProvider).watchRecent(ref.watch(clockProvider)()));

/// Vimeharibika: the last seven days of damage reports and their status,
/// and the way to report new damage.
class DamageScreen extends ConsumerWidget {
  const DamageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final reports = ref.watch(_recentDamageProvider);
    return Scaffold(
      backgroundColor: MNColors.pageBackground,
      appBar: MNWorkflowHeader(title: strings.damaged, actions: [
        MNWorkflowHelp(messages: [strings.reportNotLoss])
      ]),
      body: MNAsyncView(
        value: reports,
        isEmpty: (value) => value.isEmpty,
        empty: (_) => MNEmptyState(
            icon: MNIconData.damage,
            image: 'assets/errors/damage_state.png',
            imageWidth: 226,
            title: strings.noDamageReports),
        onRetry: () => ref.invalidate(_recentDamageProvider),
        data: (value) => ListView(padding: const EdgeInsets.all(16), children: [
          MNReferenceSurface(
              child: Column(children: [
            for (final (i, r) in value.indexed)
              _reportRow(context, ref, r, i == 0),
          ])),
        ]),
      ),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: MNButton(strings.reportDamage,
                  onPressed: () => context.push(MNRoutes.newDamage)))),
    );
  }

  Widget _reportRow(
      BuildContext context, WidgetRef ref, DamageEntry r, bool first) {
    final strings = ref.watch(stringsProvider);
    final when = eatClock(r.reportedAt);
    final status = strings.damageStatus(r.sent, r.review);
    return MNListRow(
      first: first,
      semanticLabel: '${strings.hhmm(when)}, '
          '${strings.quantityOf(r.productName, r.quantity)}, '
          '${strings.damageReason(r.reason.name)}, $status',
      onTap: () => showMNSheet<void>(context,
          builder: (_) => MNSheet(
                  title: strings.quantityOf(r.productName, r.quantity),
                  children: [
                    Text('${strings.date(when)} · ${strings.hhmm(when)}',
                        style: MNText.meta),
                    Text(status, style: MNText.status),
                    Text(strings.damageReason(r.reason.name),
                        style: MNText.body),
                    if (r.note != null) Text(r.note!, style: MNText.body),
                    Text(strings.reportNotLoss, style: MNText.secondary),
                  ])),
      leading: MNProductImage.thumb(
          image: productImageFor(null, productName: r.productName)),
      title: ExcludeSemantics(
        child: Text(strings.quantityOf(r.productName, r.quantity),
            style: MNText.title),
      ),
      subtitle: ExcludeSemantics(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${strings.date(when)} · ${strings.hhmm(when)}',
            style: MNText.meta),
        const SizedBox(height: 4),
        Text(status,
            style: MNText.meta.copyWith(
                color: switch (r.review) {
              'verified' => MNColors.success,
              'rejected' => MNColors.error,
              _ => MNColors.muted,
            })),
      ])),
      trailing:
          const MNIcon(MNIconData.chevron, size: 18, color: MNColors.muted),
    );
  }
}
