import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/session.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountState();
}

class _AccountState extends ConsumerState<AccountScreen> {
  Object? error;
  bool busy = false;
  Future<void> change(String role) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).switchRole(role);
      if (mounted) context.go(role == 'buyer' ? '/buyer' : '/supplier');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final role = ref.watch(activeRoleProvider);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Your account', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
      Surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
        Text(user?.phone ?? ''),
        Text(user?.region ?? ''),
        const SizedBox(height: 12),
        Text('Using Omoterra as a ${label(role)}')
      ])),
      const SectionHeader('Your capabilities'),
      for (final r in ['buyer', 'supplier'])
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r == 'buyer' ? 'Buy Supply' : 'Sell Supply'),
            subtitle: Text(user?.roles.contains(r) == true
                ? 'Enabled'
                : 'Enable this capability'),
            trailing: role == r
                ? const Icon(Icons.check)
                : const Icon(Icons.chevron_right),
            onTap: busy ? null : () => change(r)),
      if (user?.roles.contains('buyer') == true)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Saved delivery addresses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/addresses')),
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Profile & language'),
          subtitle: Text(user?.language == 'sw' ? 'Kiswahili' : 'English'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/account/edit')),
      for (final page in ['support', 'terms', 'privacy'])
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label(page)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/account/$page')),
      if (error != null) ErrorState(error!),
      const SizedBox(height: 24),
      OmoterraButton('Log out', secondary: true, onPressed: () async {
        try {
          await ref.read(sessionProvider.notifier).logout();
        } catch (_) {}
        if (context.mounted) context.go('/welcome');
      })
    ]);
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value!;
    return Scaffold(
        appBar: OmoterraAppBar(title: const Text('Profile & language')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          DataForm(
              path: '/me',
              method: 'PUT',
              fixed: {'roles': user.roles},
              fields: [
                FormFieldSpec('name', 'Your name', initial: user.name),
                FormFieldSpec('region', 'General region', initial: user.region),
                FormFieldSpec('language', 'Language',
                    options: const ['en', 'sw'], initial: user.language),
                if (user.roles.contains('buyer'))
                  FormFieldSpec('buyer_type', 'Buyer type',
                      options: const [
                        'personal',
                        'restaurant',
                        'butchery',
                        'hotel',
                        'retailer',
                        'caterer',
                        'other'
                      ],
                      initial: user.buyerType ?? 'personal')
              ],
              button: 'Save profile',
              onSuccess: (_) {
                ref.invalidate(sessionProvider);
                context.pop();
              })
        ]));
  }
}

class AddressesScreen extends ConsumerWidget {
  final bool create;
  final Map<String, dynamic>? edit;
  const AddressesScreen({super.key, this.create = false, this.edit});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
      appBar: OmoterraAppBar(
          title: Text(create ? 'Delivery address' : 'Saved addresses')),
      body: ListView(
          padding: const EdgeInsets.all(20),
          children: create
              ? [
                  DataForm(
                      path: edit == null
                          ? '/addresses'
                          : '/addresses/${edit!['id']}',
                      method: edit == null ? 'POST' : 'PUT',
                      fields: [
                        for (final entry in {
                          'label': 'Address label',
                          'recipient_name': 'Recipient name',
                          'phone': 'Delivery phone (+255…)',
                          'region': 'Region',
                          'district_area': 'District / area',
                          'address_text': 'Delivery directions'
                        }.entries)
                          FormFieldSpec(entry.key, entry.value,
                              initial: edit?[entry.key] ?? '')
                      ],
                      button: 'Save address',
                      onSuccess: (_) {
                        ref.invalidate(resourceProvider('/addresses'));
                        context.pop();
                      })
                ]
              : [
                  ResourceView('/addresses',
                      builder: (rows) => Column(children: [
                            for (final a in rows)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Surface(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(a['label'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        Text(
                                            '${a['address_text']}, ${a['district_area']}'),
                                        Row(children: [
                                          TextButton(
                                              onPressed: () => context.push(
                                                  '/addresses/new',
                                                  extra:
                                                      Map<String, dynamic>.from(
                                                          a)),
                                              child: const Text('Edit')),
                                          TextButton(
                                              onPressed: () async {
                                                try {
                                                  await ref
                                                      .read(repositoryProvider)
                                                      .write(
                                                          '/addresses/${a['id']}',
                                                          {},
                                                          method: 'DELETE');
                                                  ref.invalidate(
                                                      resourceProvider(
                                                          '/addresses'));
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content:
                                                                Text('$e')));
                                                  }
                                                }
                                              },
                                              child: const Text('Remove'))
                                        ])
                                      ])))
                          ])),
                  const SizedBox(height: 16),
                  OmoterraButton('Add address',
                      onPressed: () => context.push('/addresses/new'))
                ]));
}

class AccountInfoScreen extends StatelessWidget {
  final String page;
  const AccountInfoScreen(this.page, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: OmoterraAppBar(title: Text(label(page))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ResourceView('/config', builder: (config) {
          final text = page == 'support'
              ? config['support_phone']
              : config['${page}_text'];
          return Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (page == 'support')
                  const Text(
                      'For help with supply, payment or delivery, contact the Omoterra team. Keep your order reference ready.'),
                const SizedBox(height: 16),
                SelectableText(text is String && text.isNotEmpty
                    ? text
                    : page == 'support'
                        ? 'Use the Omoterra contact provided with your supply arrangement.'
                        : 'Please contact Omoterra for the current ${page == 'terms' ? 'terms of service' : 'privacy notice'} before placing an order.'),
              ]));
        }),
      ]));
}
