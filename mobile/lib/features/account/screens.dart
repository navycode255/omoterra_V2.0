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
  bool _busy = false;

  Future<void> _switchRole(String role) async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).switchRole(role);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not switch role. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.valueOrNull;
    final role = ref.watch(activeRoleProvider);
    if (user == null) {
      return Center(
          child: session.hasError
              ? TextButton(
                  onPressed: () => ref.invalidate(sessionProvider),
                  child: const Text('Retry loading account'))
              : const CircularProgressIndicator());
    }
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    return LayoutBuilder(builder: (context, constraints) {
      final scale = (constraints.maxWidth / 420).clamp(.85, 1.2);
      return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(children: [
            Positioned(
                top: 84 * scale,
                left: 0,
                right: 0,
                child: CustomPaint(
                    size: Size(constraints.maxWidth, 225 * scale),
                    painter: _AccountWave())),
            Positioned(
                top: 0,
                right: 0,
                child: ClipPath(
                    clipper: _AccountHeroClipper(),
                    child: SizedBox(
                        width: 185 * scale,
                        height: 155 * scale,
                        child: Image.asset(
                            'assets/images/account-cattle-hero-v1.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight)))),
            Positioned(
                top: 0,
                right: 75 * scale,
                child: CustomPaint(
                    size: Size(125 * scale, 155 * scale),
                    painter: _AccountLeaves(const Color(0xFF328552), .32))),
            Padding(
                padding:
                    EdgeInsets.fromLTRB(21 * scale, 22 * scale, 21 * scale, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: EdgeInsets.only(
                              top: 9 * scale, bottom: 43 * scale),
                          child: Text('Your account',
                              style: TextStyle(
                                  fontSize: 31 * scale,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  color: const Color(0xFF030E10)))),
                      Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15 * scale),
                              gradient: const LinearGradient(colors: [
                                Color(0xFF004C36),
                                Color(0xFF003F2D),
                                Color(0xFF085438)
                              ])),
                          child: Stack(children: [
                            Positioned(
                                right: 3,
                                bottom: -16,
                                child: CustomPaint(
                                    size: Size(130 * scale, 150 * scale),
                                    painter: _AccountLeaves(
                                        const Color(0xFF8CBD8D), .19))),
                            Positioned(
                                left: -12,
                                bottom: -30,
                                child: CustomPaint(
                                    size: Size(88 * scale, 115 * scale),
                                    painter: _AccountLeaves(
                                        const Color(0xFF8CBD8D), .10))),
                            Padding(
                                padding: EdgeInsets.all(18 * scale),
                                child: Row(children: [
                                  SizedBox(
                                      width: 83 * scale,
                                      child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                                width: 75 * scale,
                                                height: 75 * scale,
                                                alignment: Alignment.center,
                                                decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                        begin: Alignment
                                                            .topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                        colors: [
                                                          Color(0xFFF7FFF8),
                                                          Color(0xFFBDEEC9)
                                                        ])),
                                                child: Text(
                                                    initials.isEmpty
                                                        ? '?'
                                                        : initials,
                                                    style: TextStyle(
                                                        fontSize: 23 * scale,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: const Color(
                                                            0xFF003F2D)))),
                                            Positioned(
                                                right: 1,
                                                bottom: -2,
                                                child: Material(
                                                    color:
                                                        const Color(0xFF008451),
                                                    shape: const CircleBorder(),
                                                    child: InkWell(
                                                        customBorder:
                                                            const CircleBorder(),
                                                        onTap: () =>
                                                            context.push(
                                                                '/account/edit'),
                                                        child: const SizedBox(
                                                            width: 32,
                                                            height: 32,
                                                            child: Icon(
                                                                Icons.edit,
                                                                color: Colors
                                                                    .white,
                                                                size: 18)))))
                                          ])),
                                  Container(
                                      width: 1,
                                      height: 94 * scale,
                                      color:
                                          Colors.white.withValues(alpha: .14),
                                      margin: EdgeInsets.symmetric(
                                          horizontal: 8 * scale)),
                                  Expanded(
                                      child: Padding(
                                          padding:
                                              EdgeInsets.only(left: 7 * scale),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(user.name,
                                                    style: TextStyle(
                                                        fontSize: 16 * scale,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white)),
                                                const SizedBox(height: 3),
                                                Text(user.phone,
                                                    style: TextStyle(
                                                        fontSize: 14 * scale,
                                                        color: Colors.white)),
                                                const SizedBox(height: 5),
                                                Row(children: [
                                                  const Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      size: 17,
                                                      color: Colors.white),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                      child: Text(user.region,
                                                          style: TextStyle(
                                                              fontSize:
                                                                  12 * scale,
                                                              color: Colors
                                                                  .white)))
                                                ]),
                                                const SizedBox(height: 7),
                                                Wrap(
                                                    alignment: WrapAlignment
                                                        .spaceBetween,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    spacing: 12,
                                                    runSpacing: 8,
                                                    children: [
                                                      SizedBox(
                                                          height: 34,
                                                          child: OutlinedButton(
                                                              style: OutlinedButton.styleFrom(
                                                                  minimumSize:
                                                                      const Size(
                                                                          59, 34),
                                                                  padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          17),
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  side: const BorderSide(
                                                                      color: Color(
                                                                          0xFFB3DCC2)),
                                                                  shape:
                                                                      const StadiumBorder()),
                                                              onPressed: () =>
                                                                  context.push(
                                                                      '/account/edit'),
                                                              child:
                                                                  const Text('Edit')))
                                                    ])
                                              ])))
                                ]))
                          ])),
                      SizedBox(height: 16 * scale),
                      Text('Your capabilities',
                          style: TextStyle(
                              fontSize: 24 * scale,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.8,
                              color: const Color(0xFF030E10))),
                      SizedBox(height: 13 * scale),
                      for (final r in ['buyer', 'supplier'])
                        _AccountRow(
                            title: r == 'buyer' ? 'Buy Supply' : 'Sell Supply',
                            icon: r == 'buyer'
                                ? Icons.shopping_basket_outlined
                                : Icons.storefront_outlined,
                            selected: role == r,
                            leaves: r == 'buyer',
                            scale: scale,
                            onTap: _busy
                                ? null
                                : () => user.roles.contains(r)
                                    ? _switchRole(r)
                                    : context.push('/register-role/$r')),
                      if (role == 'buyer')
                        _AccountRow(
                            title: 'Saved delivery address',
                            icon: Icons.location_on_outlined,
                            scale: scale,
                            onTap: () => context.push('/addresses')),
                      _AccountRow(
                          title: 'Profile & language',
                          icon: Icons.language,
                          leaves: true,
                          scale: scale,
                          onTap: () => context.push('/account/edit')),
                      _AccountRow(
                          title: 'Support',
                          icon: Icons.headset_mic_outlined,
                          scale: scale,
                          onTap: () => context.push('/account/support')),
                      _AccountRow(
                          title: 'Log out',
                          icon: Icons.logout,
                          danger: true,
                          scale: scale,
                          onTap: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await ref
                                        .read(sessionProvider.notifier)
                                        .logout();
                                  } catch (_) {}
                                  if (context.mounted) context.go('/welcome');
                                }),
                    ]))
          ]));
    });
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow(
      {required this.title,
      required this.icon,
      required this.scale,
      required this.onTap,
      this.selected = false,
      this.danger = false,
      this.leaves = false});
  final String title;
  final IconData icon;
  final double scale;
  final VoidCallback? onTap;
  final bool selected, danger, leaves;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFBA1825) : const Color(0xFF003F2D);
    return Padding(
        padding: EdgeInsets.only(bottom: 6 * scale),
        child: Material(
            color: danger ? const Color(0xFFFFF5F5) : const Color(0xFAFBFDFB),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13 * scale),
                side: BorderSide(
                    color: danger
                        ? const Color(0xFFFFE1E4)
                        : const Color(0xFFE0EEE7))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Stack(children: [
                  if (leaves)
                    Positioned(
                        right: 55,
                        bottom: -25,
                        child: CustomPaint(
                            size: Size(85 * scale, 95 * scale),
                            painter:
                                _AccountLeaves(const Color(0xFF70AE87), .10))),
                  Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14 * scale, vertical: 10 * scale),
                      child: Row(children: [
                        Container(
                            width: 45 * scale,
                            height: 45 * scale,
                            decoration: BoxDecoration(
                                color: danger
                                    ? const Color(0xFFFCE0E2)
                                    : const Color(0xFFE0F2E6),
                                borderRadius:
                                    BorderRadius.circular(13 * scale)),
                            child: Icon(icon, size: 27 * scale, color: color)),
                        SizedBox(width: 20 * scale),
                        Expanded(
                            child: Text(title,
                                style: TextStyle(
                                    fontSize: 14 * scale,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.4,
                                    color: danger
                                        ? color
                                        : const Color(0xFF0B1629)))),
                        const SizedBox(width: 8),
                        if (selected)
                          Container(
                              width: 32 * scale,
                              height: 32 * scale,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFDAF1E1)),
                              child: Icon(Icons.check,
                                  size: 22 * scale, color: color))
                        else
                          Icon(Icons.chevron_right,
                              size: 24 * scale, color: color),
                      ]))
                ]))));
  }
}

class _AccountHeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .28, 0)
    ..quadraticBezierTo(0, size.height * .85, size.width, size.height)
    ..lineTo(size.width, 0)
    ..close();
  @override
  bool shouldReclip(_AccountHeroClipper oldClipper) => false;
}

class _AccountLeaves extends CustomPainter {
  const _AccountLeaves(this.color, this.opacity);
  final Color color;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 140);
    final paint = Paint()..color = color.withValues(alpha: opacity);
    canvas.drawPath(
        Path()
          ..moveTo(77, 143)
          ..quadraticBezierTo(36, 86, 47, 30),
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (final leaf in [
      Path()
        ..moveTo(48, 65)
        ..quadraticBezierTo(12, 33, 27, 0)
        ..quadraticBezierTo(64, 23, 48, 65),
      Path()
        ..moveTo(47, 86)
        ..quadraticBezierTo(40, 41, 85, 17)
        ..quadraticBezierTo(89, 66, 47, 86),
      Path()
        ..moveTo(56, 108)
        ..quadraticBezierTo(13, 105, 0, 70)
        ..quadraticBezierTo(39, 66, 56, 108),
      Path()
        ..moveTo(64, 126)
        ..quadraticBezierTo(58, 84, 100, 69)
        ..quadraticBezierTo(88, 111, 64, 126),
    ]) {
      canvas.drawPath(leaf, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AccountLeaves oldDelegate) =>
      color != oldDelegate.color || opacity != oldDelegate.opacity;
}

class _AccountWave extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..cubicTo(
              size.width * .3, -15, size.width * .3, 35, size.width * .65, 8)
          ..quadraticBezierTo(size.width * .9, -10, size.width, 55)
          ..lineTo(size.width, size.height)
          ..cubicTo(size.width * .8, size.height + 35, size.width * .45,
              size.height - 70, 0, size.height - 50)
          ..close(),
        Paint()..color = const Color(0xFFE8F3E9));
  }

  @override
  bool shouldRepaint(_AccountWave oldDelegate) => false;
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
        if (page == 'support') ...[
          ListTile(
              title: const Text('Terms of service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/account/terms')),
          ListTile(
              title: const Text('Privacy notice'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/account/privacy')),
        ],
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
        if (page == 'support')
          Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text('Page animation: Flutter Animation Gallery',
                  style: Theme.of(context).textTheme.bodySmall)),
      ]));
}
