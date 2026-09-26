import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/auth/operator_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/phone.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/decor.dart';
import '../account/role_registration_screen.dart';
import 'register_buyer_screen.dart';

/// Shows [child] to a signed-in operator, and staff sign-in to anyone else.
class AdminGate extends ConsumerWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(operatorSessionProvider).when(
          data: (operator) => operator == null ? const AdminSignIn() : child,
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => const AdminSignIn());
}

/// Staff sign-in: the mobile admin passphrase and the operator's phone, then
/// the code sent to that phone.
class AdminSignIn extends ConsumerStatefulWidget {
  const AdminSignIn({super.key});
  @override
  ConsumerState<AdminSignIn> createState() => _AdminSignInState();
}

class _AdminSignInState extends ConsumerState<AdminSignIn> {
  final _form = GlobalKey<FormState>();
  final _passphrase = TextEditingController(),
      _phone = TextEditingController(),
      _code = TextEditingController();
  Map<String, dynamic>? _challenge;
  bool _busy = false, _hidden = true;
  Object? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        final challenge = await ref
            .read(operatorSessionProvider.notifier)
            .start(_passphrase.text, tanzanianMobile(_phone.text)!);
        if (mounted) {
          setState(() {
            _challenge = challenge;
            // Without an SMS provider the server returns the code itself;
            // fill it in so testing needs no phone. Real deployments with
            // SMS never send it.
            _code.text = '${challenge['development_code'] ?? ''}';
          });
        }
      });

  Future<void> _verify() => _run(() => ref
      .read(operatorSessionProvider.notifier)
      .verify('${_challenge!['challenge_id']}', _code.text.trim()));

  @override
  Widget build(BuildContext context) {
    final codeStep = _challenge != null;
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.omoterraStaff)),
        body: SafeArea(
            child: Form(
                key: _form,
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text(codeStep ? s.enterYourCode : s.staffSignIn,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                          codeStep
                              ? s.sentCodeTo('${tanzanianMobile(_phone.text)}')
                              : s.staffSignInIntro,
                          style: const TextStyle(color: OColors.secondary)),
                      const SizedBox(height: 24),
                      if (!codeStep) ...[
                        TextFormField(
                            key: const Key('admin_passphrase'),
                            controller: _passphrase,
                            obscureText: _hidden,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                                labelText: s.staffPassphrase,
                                suffixIcon: IconButton(
                                    tooltip: _hidden
                                        ? s.showPassphrase
                                        : s.hidePassphrase,
                                    icon: Icon(_hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                    onPressed: () =>
                                        setState(() => _hidden = !_hidden))),
                            validator: (v) => (v ?? '').isEmpty
                                ? s.enterStaffPassphrase
                                : null),
                        const SizedBox(height: 14),
                        TextFormField(
                            key: const Key('admin_phone'),
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                                labelText: s.staffPhone,
                                hintText: '0712 345 678'),
                            validator: (v) => tanzanianMobile(v ?? '') == null
                                ? s.enterTzMobileShort
                                : null),
                      ] else ...[
                        TextFormField(
                            key: const Key('admin_code'),
                            controller: _code,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            decoration: InputDecoration(labelText: s.codeLabel),
                            validator: (v) =>
                                RegExp(r'^\d{4,8}$').hasMatch(v?.trim() ?? '')
                                    ? null
                                    : s.enterSmsCode),
                        if (_challenge!['development_code'] != null)
                          Container(
                              key: const Key('admin_dev_code'),
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFDF6EC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFF0DEC4))),
                              child: Text(
                                  s.developmentCode(
                                      '${_challenge!['development_code']}'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: OColors.warning,
                                      fontWeight: FontWeight.w600))),
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _challenge = null),
                            child: Text(s.useDifferentNumber)),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _SignInError(_error!),
                      ],
                      const SizedBox(height: 20),
                      OmoterraButton(codeStep ? s.signIn : s.sendCode,
                          busy: _busy,
                          onPressed: codeStep ? _verify : _sendCode),
                    ]))));
  }
}

/// The server's own reason, word for word: staff need it to fix sign-in
/// (a wrong passphrase, a number that isn't an operator, sign-in switched
/// off), where the app's general error copy would only say "try again".
class _SignInError extends StatelessWidget {
  final Object error;
  const _SignInError(this.error);
  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final message = error is ApiFailure && (error as ApiFailure).kind == null
        ? switch ((error as ApiFailure).message) {
            final m when m.contains('turned off') => s.staffSignInOff,
            final m => m,
          }
        : friendlyErrorMessage(error, s);
    return Container(
        key: const Key('admin_sign_in_error'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: const Color(0xFFFCE8E6),
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, color: OColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 14, height: 1.4, color: OColors.ink))),
        ]));
  }
}

final myReferralsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async => [
          for (final row in await ref
              .watch(repositoryProvider)
              .read('/referrals/mine') as List)
            Map<String, dynamic>.from(row)
        ]);

/// The operator's home: register a buyer or supplier, and everyone they
/// have registered.
class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operator = ref.watch(operatorSessionProvider).valueOrNull ?? {};
    final referrals = ref.watch(myReferralsProvider);
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.omoterraStaff), actions: [
          TextButton(
              onPressed: () =>
                  ref.read(operatorSessionProvider.notifier).signOut(),
              child: Text(s.signOut)),
        ]),
        body: RefreshIndicator(
            onRefresh: () => ref.refresh(myReferralsProvider.future),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Text(s.hello('${operator['name'] ?? s.staffWord}'),
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(s.registerSomeone,
                      style: const TextStyle(color: OColors.secondary)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: _RegisterTile(
                            icon: Icons.storefront_outlined,
                            title: s.label('buyer'),
                            onTap: () => context.push('/admin/buyer'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _RegisterTile(
                            icon: Icons.agriculture_outlined,
                            title: s.label('supplier'),
                            onTap: () => context.push('/admin/supplier'))),
                  ]),
                  SectionHeader(
                      s.myRegistrations(referrals.valueOrNull?.length)),
                  referrals.when(
                      loading: () => const LoadingSkeleton(),
                      error: (e, _) => ErrorState(e,
                          retry: () => ref.invalidate(myReferralsProvider)),
                      data: (rows) => rows.isEmpty
                          ? EmptyState(
                              s.nobodyRegistered, s.nobodyRegisteredBody)
                          : Column(children: [
                              for (final row in rows)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ReferralCard(row)),
                            ])),
                ])));
  }
}

class _RegisterTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _RegisterTile(
      {required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => DecorCard(
      onTap: onTap,
      wave: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: OColors.forest, size: 28),
        const SizedBox(height: 14),
        Text(context.s.register,
            style: const TextStyle(fontSize: 12.5, color: OColors.secondary)),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: OColors.ink)),
      ]));
}

class _ReferralCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ReferralCard(this.row);
  @override
  Widget build(BuildContext context) {
    final supplier = row['role'] == 'supplier';
    final created = DateTime.tryParse('${row['created_at']}')?.toLocal();
    final business = '${row['business_name'] ?? ''}';
    final s = context.s;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OColors.border)),
        child: Row(children: [
          CircleAvatar(
              backgroundColor: OColors.soft,
              child: Icon(
                  supplier
                      ? Icons.agriculture_outlined
                      : Icons.storefront_outlined,
                  color: OColors.forest,
                  size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(business.isEmpty ? '${row['name']}' : business,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    '${s.label(supplier ? 'supplier' : 'buyer')} · ${row['phone']}'
                    '${created == null ? '' : ' · ${s.dayMonth(created)}'}',
                    style: const TextStyle(
                        fontSize: 12.5, color: OColors.secondary)),
                // A supplier's own verification, separate from the
                // registration itself.
                if (supplier && row['supplier_status'] != null) ...[
                  const SizedBox(height: 6),
                  StatusText('${row['supplier_status']}'),
                ],
              ])),
        ]));
  }
}

/// Supplier registration by staff: the self-registration wizard, with the
/// supplier's phone, staff notes, and photos owned by the new supplier.
class AdminRegisterSupplier extends ConsumerWidget {
  const AdminRegisterSupplier({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ProviderScope(
          overrides: [
            photoUploadPathProvider.overrideWithValue('/referrals/photos')
          ],
          child: SupplierOnboardingWizard(
              onBehalf: true,
              onRegistered: () => registered(context, ref, 'supplier')));
}

class AdminRegisterBuyer extends ConsumerWidget {
  const AdminRegisterBuyer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => RegisterBuyerScreen(
      onRegistered: () => registered(context, ref, 'buyer'));
}

/// [role] is `buyer` or `supplier`.
void registered(BuildContext context, WidgetRef ref, String role) {
  ref.invalidate(myReferralsProvider);
  final s = ref.read(stringsProvider);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(s.roleRegistered(s.label(role)))));
  context.go('/admin');
}
