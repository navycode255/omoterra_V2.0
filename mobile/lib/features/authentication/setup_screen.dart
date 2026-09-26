import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<SetupScreen> {
  final name = TextEditingController(), region = TextEditingController();
  final form = GlobalKey<FormState>();
  bool buy = true, sell = false, busy = false;
  String buyerType = 'personal';
  int step = 0;
  Object? error;

  @override
  void dispose() {
    name.dispose();
    region.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).profile({
        'name': name.text.trim(),
        'region': region.text.trim(),
        'language': ref.read(selectedLanguageProvider),
        'roles': [if (buy) 'buyer', if (sell) 'supplier'],
        'buyer_type': buy ? buyerType : null
      });
      ref.read(activeRoleProvider.notifier).state = buy ? 'buyer' : 'supplier';
      await ref
          .read(sessionProvider.notifier)
          .switchRole(buy ? 'buyer' : 'supplier');
      if (mounted) context.go(buy ? '/buyer' : '/supplier');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const _buyerTypes = <String, IconData>{
    'personal': Icons.person_outline,
    'restaurant': Icons.restaurant_outlined,
    'butchery': Icons.storefront_outlined,
    'hotel': Icons.apartment_outlined,
    'retailer': Icons.shopping_bag_outlined,
    'caterer': Icons.room_service_outlined,
    'other': Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(
            leading: step == 0
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: BackChevron(
                        onPressed: () => setState(
                            () => step = step == 2 && !buy ? 0 : step - 1)))),
        body: Form(
            key: form,
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(children: [
                      Expanded(
                          child: ListView(padding: EdgeInsets.zero, children: [
                        if (step == 0) ...[
                          Text(s.roleTitle,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 10),
                          Text(s.roleBody,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: OColors.secondary, height: 1.5)),
                          const SizedBox(height: 28),
                          _RoleCard(
                              icon: Icons.shopping_cart_outlined,
                              title: s.buySupply,
                              body: s.buySupplyBody,
                              selected: buy,
                              onTap: () => setState(() => buy = !buy)),
                          const SizedBox(height: 12),
                          _RoleCard(
                              icon: Icons.eco_outlined,
                              title: s.sellSupply,
                              body: s.sellSupplyBody,
                              selected: sell,
                              onTap: () => setState(() => sell = !sell)),
                        ],
                        if (step == 1) ...[
                          Text(s.buyerTypeTitle,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 10),
                          Text(s.buyerTypeBody,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: OColors.secondary)),
                          const SizedBox(height: 24),
                          for (final entry in _buyerTypes.entries)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ChoiceRow(
                                    icon: entry.value,
                                    label: s.label(entry.key),
                                    selected: buyerType == entry.key,
                                    onTap: () =>
                                        setState(() => buyerType = entry.key))),
                        ],
                        if (step == 2) ...[
                          Text(s.profileTitle,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 24),
                          OmoterraTextField(s.fullName, name),
                          OmoterraTextField(s.region, region),
                        ],
                      ])),
                      if (error != null) ErrorState(error!),
                      OmoterraButton(
                          step == 2 ? s.finishSetup : s.continueLabel,
                          busy: busy, onPressed: () {
                        if (step == 2) {
                          submit();
                          return;
                        }
                        if (!buy && !sell) {
                          setState(() => error = s.chooseBuyOrSell);
                          return;
                        }
                        setState(() {
                          error = null;
                          step = step == 0 && !buy ? 2 : step + 1;
                        });
                      }),
                    ])))));
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard(
      {required this.icon,
      required this.title,
      required this.body,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: selected ? OColors.soft : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? OColors.forest : OColors.border,
                  width: selected ? 1.5 : 1)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 26, color: OColors.forest),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 13, color: OColors.secondary, height: 1.4))
                ])),
            const SizedBox(width: 8),
            _Check(selected: selected),
          ])));
}

class _Check extends StatelessWidget {
  final bool selected;
  const _Check({required this.selected});
  @override
  Widget build(BuildContext context) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
          color: selected ? OColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? OColors.forest : OColors.border, width: 1.5)),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null);
}

class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceRow(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
              color: selected ? OColors.soft : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? OColors.forest : OColors.border,
                  width: selected ? 1.5 : 1)),
          child: Row(children: [
            Icon(icon, size: 21, color: OColors.forest),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500))),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 21, color: selected ? OColors.forest : OColors.border),
          ])));
}
