import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/payment_option.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/pressable.dart';
import 'end_phone_access.dart';
import 'outlet_lead_sheet.dart';
import 'owner_reference.dart';
import 'setup_screens.dart';
import 'people_screens.dart';
import 'staff_stations_screen.dart';
import 'station_screen.dart' show stationGuard;

/// One vendor or staff member: details and the owner's corrections (owner
/// control design §10–11). Every action asks for a reason; the server checks
/// permissions and records who, when and why. A person who has left is
/// read-only.

// Shared pieces ------------------------------------------------------------------------

/// What the signed-in office account may plausibly do. The server decides.
({bool manage, bool owner, bool supervisor, String? id}) _me(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  final profile = auth is OfficeSignedIn ? auth.profile : null;
  return (
    manage: profile?.canManagePeople ?? false,
    owner: profile?.isOwner ?? false,
    supervisor: profile?.roles.contains(StaffRole.supervisor) ?? false,
    id: profile?.id,
  );
}

/// Supervisors, finance and the owner (`sales.verify`). The server decides.
bool _canVerify(WidgetRef ref) {
  final auth = ref.watch(officeSessionProvider).valueOrNull;
  return auth is OfficeSignedIn && auth.profile.canVerify;
}

/// Owner, operations and finance roles: only the owner manages them.
const _privileged = {
  StaffRole.owner,
  StaffRole.operationsAdmin,
  StaffRole.finance
};

(String, Color) _statusOf(Strings s,
        {required bool activated,
        required bool suspended,
        required bool left}) =>
    left
        ? (s.statusLeft, MNColors.muted)
        : suspended
            ? (s.statusSuspended, MNColors.error)
            : activated
                ? (s.statusActive, MNColors.success)
                : (s.statusPending, MNColors.warning);

/// The reason is shown only for a suspended or departed account.
String _statusText(Strings s, String status, bool stopped, String? reason) =>
    !stopped || reason == null || reason.trim().isEmpty
        ? status
        : s.statusWithReason(status, reason.trim());

void _toast(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// The page frame both detail screens share.
class _PersonPage extends StatelessWidget {
  final String title;
  final Strings strings;
  final Future<void> Function() onRefresh;
  final Widget child;
  const _PersonPage(
      {required this.title,
      required this.strings,
      required this.onRefresh,
      required this.child});
  @override
  Widget build(BuildContext context) => OwnerPage(
      title: title,
      strings: strings,
      vendorSpacing: true,
      onRefresh: onRefresh,
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: OwnerStyle.px(context, 12)),
          child: child));
}

/// Label above value; stacks cleanly on small phones and at large text.
class _Fact extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Fact(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    return Semantics(
        container: true,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: u(18), vertical: u(12)),
            child: SizedBox(
                width: double.infinity,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: OwnerStyle.text(context, 13,
                              color: OwnerStyle.muted)),
                      SizedBox(height: u(2)),
                      Text(value,
                          style: OwnerStyle.text(context, 16,
                              weight: 600, color: color ?? OwnerStyle.ink)),
                    ]))));
  }
}

Widget _divided(List<Widget> rows) => Column(children: [
      for (final (i, row) in rows.indexed) ...[
        if (i > 0)
          const Divider(height: 1, thickness: .6, color: OwnerStyle.line),
        row,
      ]
    ]);

Widget _gap(BuildContext context) =>
    SizedBox(height: OwnerStyle.px(context, 12));

/// Offers the one-time code straight after a phone change, then shows it.
Future<void> _offerCode(BuildContext context, WidgetRef ref,
    {required String name,
    required bool staff,
    required Future<IssuedCode> Function(OfficeRepository r) issue}) async {
  final s = ref.read(stringsProvider);
  final yes = await showMNConfirmDialog(context,
      title: s.offerCodeTitle,
      message: s.offerCodeBody,
      confirmLabel: s.offerCodeYes,
      cancelLabel: s.later);
  if (!yes || !context.mounted) return;
  await _issueCode(context, ref, name: name, staff: staff, issue: issue);
}

Future<void> _issueCode(BuildContext context, WidgetRef ref,
    {required String name,
    required bool staff,
    required Future<IssuedCode> Function(OfficeRepository r) issue}) async {
  final s = ref.read(stringsProvider);
  try {
    final code = await ref.read(officeSessionProvider.notifier).guard(issue);
    if (context.mounted) {
      context.push(MNRoutes.officeIssuedCode,
          extra: IssuedCodeArgs(name: name, code: code, staff: staff));
    }
  } catch (error) {
    if (context.mounted) _toast(context, officeErrorText(s, error));
  }
}

/// Asks for the reason (and, for [StatusChange.leave], a second clear
/// confirmation), then runs the change. True when it succeeded.
Future<bool> _changeStatus(BuildContext context,
    {required String name,
    required StatusChange change,
    required Future<void> Function(OfficeRepository r, String reason)
        run}) async {
  final done = await showMNSheet<bool>(context,
      builder: (_) =>
          _ReasonSheet(name: name, change: change, run: run, revoke: null));
  return done ?? false;
}

class _ReasonSheet extends ConsumerStatefulWidget {
  final String name;
  final StatusChange? change;

  /// The role being removed, for a revoke.
  final String? revoke;
  final Future<void> Function(OfficeRepository r, String reason) run;
  const _ReasonSheet(
      {required this.name,
      required this.change,
      required this.run,
      required this.revoke});
  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = s.reasonInvalid);
      return;
    }
    if (widget.change == StatusChange.leave) {
      final yes = await showMNConfirmDialog(context,
          title: s.leaveConfirmTitle(widget.name),
          message: s.leaveConfirmBody,
          confirmLabel: s.leaveYes,
          cancelLabel: s.cancel,
          destructive: true);
      if (!yes || !mounted) return;
    }
    if (widget.change == StatusChange.delete) {
      final yes = await showMNConfirmDialog(context,
          title: s.deleteConfirmTitle(widget.name),
          message: s.deleteConfirmBody,
          confirmLabel: s.deleteYes,
          cancelLabel: s.cancel,
          destructive: true);
      if (!yes || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => widget.run(r, reason));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final (title, body, destructive) = switch (widget.change) {
      StatusChange.suspend => (s.suspendAccount, s.suspendBody, true),
      StatusChange.reinstate => (s.reinstateAccount, s.reinstateBody, false),
      StatusChange.leave => (s.markLeft, s.leaveBody, true),
      StatusChange.delete => (s.deleteAccount, s.deleteAccountBody, true),
      StatusChange.returned => (s.returnAccount, s.returnAccountBody, false),
      null => (s.revokeRole(widget.revoke ?? ''), s.revokeRoleBody, true),
    };
    return MNSheet(title: title, children: [
      MNNote(body,
          tone: widget.change == StatusChange.leave ||
                  widget.change == StatusChange.delete
              ? MNNoteTone.error
              : destructive
                  ? MNNoteTone.warning
                  : MNNoteTone.info),
      MNTextField(
          label: s.changeReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      destructive
          ? MNButton.destructive(title,
              busy: _busy, onPressed: _busy ? null : _save)
          : MNButton(title, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

/// Name and phone, with a reason. A new phone is warned about before saving.
/// Pops true when the phone changed (the person needs a new code).
class _EditPersonSheet extends ConsumerStatefulWidget {
  final String name, phone;
  final Future<void> Function(
      OfficeRepository r, String? name, String? phone, String reason) save;
  const _EditPersonSheet(
      {required this.name, required this.phone, required this.save});
  @override
  ConsumerState<_EditPersonSheet> createState() => _EditPersonSheetState();
}

class _EditPersonSheetState extends ConsumerState<_EditPersonSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _phone =
      TextEditingController(text: widget.phone.replaceFirst('+255', ''));
  final _reason = TextEditingController();
  String? _nameError, _phoneError, _error;
  bool _busy = false;

  bool get _phoneChanged {
    final phone = normaliseTanzanianPhone(_phone.text);
    return phone != null && phone != widget.phone;
  }

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final name = _name.text.trim();
    final phone = normaliseTanzanianPhone(_phone.text);
    final reason = _reason.text.trim();
    setState(() {
      _nameError = name.length < 2 ? s.nameRequired : null;
      _phoneError = phone == null ? s.phoneInvalid : null;
      _error = reason.length < 3 ? s.reasonInvalid : null;
    });
    if (_nameError != null || _phoneError != null || _error != null) return;
    final newName = name == widget.name ? null : name;
    final newPhone = phone == widget.phone ? null : phone;
    if (newName == null && newPhone == null) {
      setState(() => _error = s.nothingChanged);
      return;
    }
    if (newPhone != null) {
      final yes = await showMNConfirmDialog(context,
          title: s.phoneChangeTitle,
          message: s.phoneChangeWarning,
          confirmLabel: s.phoneChangeYes,
          cancelLabel: s.cancel,
          destructive: true);
      if (!yes || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => widget.save(r, newName, newPhone, reason));
      if (mounted) Navigator.of(context).pop(newPhone != null);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return MNSheet(title: s.editPerson, children: [
      MNTextField(
          label: s.fullName,
          controller: _name,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          error: _nameError),
      OfficePhoneInput(controller: _phone, error: _phoneError, enabled: !_busy),
      if (_phoneChanged) MNNote(s.phoneChangeWarning),
      MNTextField(
          label: s.changeReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// Vendor -------------------------------------------------------------------------------

class OfficeVendorScreen extends ConsumerWidget {
  final String vendorId;
  const OfficeVendorScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final vendors = ref.watch(officeVendorsProvider);
    final vendor =
        vendors.valueOrNull?.where((v) => v.id == vendorId).firstOrNull;
    return _PersonPage(
        title: vendor?.name ?? s.vendors,
        strings: s,
        onRefresh: () => ref.refresh(officeVendorsProvider.future),
        child: OwnerAsyncView(
            value: vendors,
            onRetry: () => ref.invalidate(officeVendorsProvider),
            data: (_) => vendor == null
                ? MNNote(s.personNotFound, tone: MNNoteTone.info)
                : _VendorDetail(vendor: vendor)));
  }
}

class _VendorDetail extends ConsumerWidget {
  final OfficeVendor vendor;
  const _VendorDetail({required this.vendor});

  void _refresh(WidgetRef ref) {
    ref.invalidate(officeVendorsProvider);
    ref.invalidate(officeStationsProvider);
  }

  Future<void> _station(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    try {
      final station = await pickStation(context, ref);
      if (station == null) return;
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          r.assignVendor(
              vendorId: vendor.id,
              stationId: station.id,
              reason: s.officeReason));
      _refresh(ref);
      if (context.mounted) _toast(context, s.changesSaved);
    } catch (error) {
      if (context.mounted) _toast(context, officeErrorText(s, error));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final phoneChanged = await showMNSheet<bool>(context,
        builder: (_) => _EditPersonSheet(
            name: vendor.name,
            phone: vendor.phone,
            save: (r, name, phone, reason) => r.updateVendor(vendor.id,
                name: name, phone: phone, reason: reason)));
    if (phoneChanged == null) return;
    _refresh(ref);
    if (!context.mounted) return;
    _toast(context, ref.read(stringsProvider).changesSaved);
    if (phoneChanged) {
      await _offerCode(context, ref,
          name: vendor.name,
          staff: false,
          issue: (r) => r.vendorCode(vendor.id));
    }
  }

  Future<void> _status(
      BuildContext context, WidgetRef ref, StatusChange change) async {
    final done = await _changeStatus(context,
        name: vendor.name,
        change: change,
        run: (r, reason) =>
            r.changeVendorStatus(vendor.id, change, reason: reason));
    if (!done) return;
    _refresh(ref);
    if (!context.mounted) return;
    final s = ref.read(stringsProvider);
    if (change == StatusChange.delete) {
      _toast(context, s.deletedToast);
      context.pop();
    } else {
      _toast(context, s.changesSaved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final (status, color) = _statusOf(s,
        activated: vendor.activated,
        suspended: vendor.suspended,
        left: vendor.left);
    final reason = vendor.statusReason;
    final canCode = me.manage || me.supervisor;
    final actions = vendor.left
        ? [
            if (me.manage) ...[
              OwnerMenuRow(
                  label: s.returnAccount,
                  onTap: () => _status(context, ref, StatusChange.returned)),
              OwnerMenuRow(
                  label: s.deleteAccount,
                  onTap: () => _status(context, ref, StatusChange.delete)),
            ],
          ]
        : [
            if (me.manage) ...[
              OwnerMenuRow(
                  label: s.editPerson, onTap: () => _edit(context, ref)),
              OwnerMenuRow(
                  label: vendor.stationName == null
                      ? s.ownerAssignStation
                      : s.changeStation,
                  onTap: () => _station(context, ref)),
            ],
            if (canCode)
              OwnerMenuRow(
                  label: vendor.activated ? s.resetPinCode : s.newCode,
                  onTap: () => _issueCode(context, ref,
                      name: vendor.name,
                      staff: false,
                      issue: (r) =>
                          r.vendorCode(vendor.id, reset: vendor.activated))),
            if (me.manage) ...[
              vendor.suspended
                  ? OwnerMenuRow(
                      label: s.reinstateAccount,
                      onTap: () =>
                          _status(context, ref, StatusChange.reinstate))
                  : OwnerMenuRow(
                      label: s.suspendAccount,
                      onTap: () => _status(context, ref, StatusChange.suspend)),
              // Outlet Lead: `staff.manage` + `roles.grant`, as `me.manage`.
              OwnerMenuRow(
                  label: vendor.isLead ? s.endLead : s.makeLead,
                  onTap: () async {
                    if (await outletLeadSheet(context,
                            vendorId: vendor.id,
                            name: vendor.name,
                            make: !vendor.isLead) &&
                        context.mounted) {
                      _refresh(ref);
                      _toast(context, s.changesSaved);
                    }
                  }),
              // `sessions.revoke`: operations and the owner, as `me.manage`.
              if (!vendor.suspended)
                OwnerMenuRow(
                    label: s.endPhoneAccess,
                    onTap: () async {
                      if (await endPhoneAccessSheet(context, vendor.id) &&
                          context.mounted) {
                        _toast(context, s.endPhoneDone);
                      }
                    }),
              OwnerMenuRow(
                  label: s.markLeft,
                  onTap: () => _status(context, ref, StatusChange.leave)),
              OwnerMenuRow(
                  label: s.deleteAccount,
                  onTap: () => _status(context, ref, StatusChange.delete)),
            ],
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerCard(
          child: _divided([
        _Fact(s.statusLabel,
            _statusText(s, status, vendor.suspended || vendor.left, reason),
            color: color),
        _Fact(s.phone, displayPhone(vendor.phone)),
        if (vendor.code != null) _Fact(s.vendorNumber, vendor.code!),
        _Fact(s.station, vendor.stationName ?? s.noStation),
        if (vendor.isLead) _Fact(s.role, s.leadRole),
        _Fact(s.signInState, vendor.activated ? s.signInDone : s.signInWaiting),
      ])),
      if (vendor.left) ...[
        _gap(context),
        MNNote(s.personLeftNote, tone: MNNoteTone.info),
      ],
      if (me.owner) ...[
        _gap(context),
        OwnerCard(
            child: OwnerMenuRow(
                label: s.opTitle,
                subtitle: s.opPersonPerformance,
                onTap: () =>
                    context.push(MNRoutes.officePerformanceVendor(vendor.id)))),
      ],
      // Sales remembered after a lost phone (MN036); the server checks role and station.
      if (_canVerify(ref)) ...[
        _gap(context),
        OwnerCard(
            child: OwnerMenuRow(
                label: s.lostSalesTitle,
                subtitle: s.lostSalesCaption,
                onTap: () => context.push(MNRoutes.officeLostSales(vendor.id)))),
      ],
      if (actions.isNotEmpty) ...[
        _gap(context),
        OwnerCard(child: _divided(actions)),
      ],
    ]);
  }
}

// Staff --------------------------------------------------------------------------------

class OfficeStaffMemberScreen extends ConsumerWidget {
  final String staffId;
  const OfficeStaffMemberScreen({super.key, required this.staffId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final staff = ref.watch(officeStaffProvider);
    final person = staff.valueOrNull?.where((p) => p.id == staffId).firstOrNull;
    return _PersonPage(
        title: person?.name ?? s.staffMembers,
        strings: s,
        onRefresh: () => ref.refresh(officeStaffProvider.future),
        child: OwnerAsyncView(
            value: staff,
            onRetry: () => ref.invalidate(officeStaffProvider),
            data: (_) => person == null
                ? MNNote(s.personNotFound, tone: MNNoteTone.info)
                : _StaffDetail(person: person)));
  }
}

class _StaffDetail extends ConsumerWidget {
  final OfficeStaff person;
  const _StaffDetail({required this.person});

  void _refresh(WidgetRef ref) {
    ref.invalidate(officeStaffProvider);
    ref.invalidate(staffPlacementDataProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final phoneChanged = await showMNSheet<bool>(context,
        builder: (_) => _EditPersonSheet(
            name: person.name,
            phone: person.phone,
            save: (r, name, phone, reason) => r.updateStaff(person.id,
                name: name, phone: phone, reason: reason)));
    if (phoneChanged == null) return;
    _refresh(ref);
    if (!context.mounted) return;
    _toast(context, ref.read(stringsProvider).changesSaved);
    if (phoneChanged) {
      await _offerCode(context, ref,
          name: person.name, staff: true, issue: (r) => r.staffCode(person.id));
    }
  }

  Future<void> _status(
      BuildContext context, WidgetRef ref, StatusChange change) async {
    final done = await _changeStatus(context,
        name: person.name,
        change: change,
        run: (r, reason) =>
            r.changeStaffStatus(person.id, change, reason: reason));
    if (!done) return;
    _refresh(ref);
    if (!context.mounted) return;
    final s = ref.read(stringsProvider);
    if (change == StatusChange.delete) {
      _toast(context, s.deletedToast);
      context.pop();
    } else {
      _toast(context, s.changesSaved);
    }
  }

  /// The role, and the kitchen a kitchen-staff grant places them at.
  String _grantLabel(
      Strings s, OfficeRoleGrant grant, List<OfficeStockLocation>? places) {
    final kitchen = places?.where((l) => l.id == grant.kitchenId).firstOrNull;
    return kitchen == null
        ? s.roleName(grant.role)
        : '${s.roleName(grant.role)}: ${kitchen.name}';
  }

  Future<void> _revoke(
      BuildContext context, WidgetRef ref, OfficeRoleGrant grant) async {
    final s = ref.read(stringsProvider);
    final done = await showMNSheet<bool>(context,
        builder: (_) => _ReasonSheet(
            name: person.name,
            change: null,
            revoke: _grantLabel(s, grant, ref.read(setupLocationsProvider).valueOrNull),
            run: (r, reason) => r.revokeRole(
                staffId: person.id, roleGrantId: grant.id, reason: reason)));
    if (done != true) return;
    _refresh(ref);
    if (context.mounted) _toast(context, s.changesSaved);
  }

  Future<void> _grant(
      BuildContext context, WidgetRef ref, List<String> roles) async {
    final done = await showMNSheet<bool>(context,
        builder: (_) => _GrantRoleSheet(
            staffId: person.id,
            roles: roles,
            heldKitchens: {
              for (final g in person.roleGrants)
                if (g.role == StaffRole.kitchen && g.kitchenId != null)
                  g.kitchenId!
            }));
    if (done != true) return;
    _refresh(ref);
    if (context.mounted) {
      _toast(context, ref.read(stringsProvider).changesSaved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final me = _me(ref);
    final (status, color) = _statusOf(s,
        activated: person.activated,
        suspended: person.suspended,
        left: person.left);
    final reason = person.statusReason;
    // Nobody changes their own account here; only the owner touches managers.
    final privileged = person.roles.any(_privileged.contains);
    final canManage =
        me.manage && me.id != person.id && (me.owner || !privileged);
    final canAct = canManage && !person.left;
    final grantable = [
      StaffRole.supervisor,
      StaffRole.kitchen,
      if (me.owner) StaffRole.finance,
      if (me.owner) StaffRole.operationsAdmin,
    ].where((r) => r == StaffRole.kitchen || !person.roles.contains(r)).toList();
    final stations = ref.watch(officeStationsProvider).valueOrNull;
    final stationNames = [
      for (final id in person.stationIds)
        stations?.where((st) => st.id == id).firstOrNull?.name ?? id
    ];
    final places = ref.watch(setupLocationsProvider).valueOrNull;
    final kitchenNames = [
      for (final g in person.roleGrants)
        if (g.role == StaffRole.kitchen && g.kitchenId != null)
          places?.where((l) => l.id == g.kitchenId).firstOrNull?.name ??
              g.kitchenId!
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OwnerCard(
          child: _divided([
        _Fact(s.statusLabel,
            _statusText(s, status, person.suspended || person.left, reason),
            color: color),
        _Fact(s.phone, displayPhone(person.phone)),
        if (person.code != null) _Fact(s.staffNumber, person.code!),
        _Fact(
            s.role,
            person.roles.isEmpty
                ? '—'
                : person.roles.map(s.roleName).join(' · ')),
        _Fact(s.workStations,
            stationNames.isEmpty ? s.noStation : stationNames.join(', ')),
        for (final k in kitchenNames) _Fact(s.kitchenPick, k),
        _Fact(s.signInState, person.activated ? s.signInDone : s.signInWaiting),
      ])),
      if (person.left) ...[
        _gap(context),
        MNNote(s.personLeftNote, tone: MNNoteTone.info),
        if (canManage) ...[
          _gap(context),
          OwnerCard(
              child: _divided([
            OwnerMenuRow(
                label: s.returnAccount,
                onTap: () => _status(context, ref, StatusChange.returned)),
            OwnerMenuRow(
                label: s.deleteAccount,
                onTap: () => _status(context, ref, StatusChange.delete)),
          ])),
        ],
      ],
      if (me.owner && person.id != me.id) ...[
        _gap(context),
        OwnerCard(
            child: OwnerMenuRow(
                label: s.opTitle,
                subtitle: s.opPersonPerformance,
                onTap: () =>
                    context.push(MNRoutes.officePerformanceStaff(person.id)))),
      ],
      if (canAct) ...[
        _gap(context),
        OwnerCard(
            child: _divided([
          OwnerMenuRow(label: s.editPerson, onTap: () => _edit(context, ref)),
          OwnerMenuRow(
              label: s.workStations,
              onTap: () async {
                await context.push(MNRoutes.officeStaffStations(person.id));
                _refresh(ref);
              }),
          OwnerMenuRow(
              label: person.activated ? s.resetPinCode : s.newCode,
              onTap: () => _issueCode(context, ref,
                  name: person.name,
                  staff: true,
                  issue: (r) =>
                      r.staffCode(person.id, reset: person.activated))),
          person.suspended
              ? OwnerMenuRow(
                  label: s.reinstateAccount,
                  onTap: () => _status(context, ref, StatusChange.reinstate))
              : OwnerMenuRow(
                  label: s.suspendAccount,
                  onTap: () => _status(context, ref, StatusChange.suspend)),
          OwnerMenuRow(
              label: s.markLeft,
              onTap: () => _status(context, ref, StatusChange.leave)),
          OwnerMenuRow(
              label: s.deleteAccount,
              onTap: () => _status(context, ref, StatusChange.delete)),
        ])),
        _gap(context),
        OwnerCard(
            child: _divided([
          for (final grant in person.roleGrants)
            if (me.owner || !_privileged.contains(grant.role))
              OwnerMenuRow(
                  label: s.revokeRole(_grantLabel(s, grant, places)),
                  onTap: () => _revoke(context, ref, grant)),
          OwnerMenuRow(
              label: s.grantRole, onTap: () => _grant(context, ref, grantable)),
        ])),
      ],
    ]);
  }
}

class _GrantRoleSheet extends ConsumerStatefulWidget {
  final String staffId;
  final List<String> roles;
  final Set<String> heldKitchens;
  const _GrantRoleSheet(
      {required this.staffId,
      required this.roles,
      this.heldKitchens = const {}});
  @override
  ConsumerState<_GrantRoleSheet> createState() => _GrantRoleSheetState();
}

class _GrantRoleSheetState extends ConsumerState<_GrantRoleSheet> {
  final _reason = TextEditingController();
  String? _role, _error, _kitchen;
  bool _busy = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final reason = _reason.text.trim();
    if (_role == null || reason.length < 3) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    if (_role == StaffRole.kitchen && _kitchen == null) {
      setState(() => _error = s.kitchenRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_role == StaffRole.kitchen) {
        await officeSetupCall(
            ref,
            (r) => r.grantKitchenRole(
                staffId: widget.staffId,
                kitchenLocationId: _kitchen!,
                reason: reason));
      } else {
        await ref.read(officeSessionProvider.notifier).guard((r) =>
            r.grantRole(staffId: widget.staffId, role: _role!, reason: reason));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = officeErrorText(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    if (widget.roles.isEmpty) {
      return MNSheet(
          title: s.grantRole,
          children: [MNNote(s.noRoleToGrant, tone: MNNoteTone.info)]);
    }
    return MNSheet(title: s.grantRole, children: [
      for (final role in widget.roles)
        MNPaymentOption(
            icon: MNIconData.user,
            title: s.roleName(role),
            caption: s.roleHint(role),
            selected: _role == role,
            onTap: _busy ? null : () => setState(() => _role = role)),
      if (_role == StaffRole.kitchen)
        KitchenChoice(
            value: _kitchen,
            enabled: !_busy,
            exclude: widget.heldKitchens,
            onChanged: (v) => setState(() => _kitchen = v)),
      MNTextField(
          label: s.changeReason,
          controller: _reason,
          enabled: !_busy,
          inputFormatters: [LengthLimitingTextInputFormatter(500)]),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(s.grantRole, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// A vendor seen from a station ----------------------------------------------------------

/// A vendor as one of a station's people: basic details, the owner's
/// corrections, and ending the placement here. Ending it keeps the account
/// and the sales history.
class StationVendorScreen extends ConsumerWidget {
  final String stationId, vendorId;
  const StationVendorScreen(
      {super.key, required this.stationId, required this.vendorId});

  void _refresh(WidgetRef ref) {
    ref.invalidate(officeVendorsProvider);
    ref.invalidate(officeStationsProvider);
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, OfficeVendor vendor) async {
    final phoneChanged = await showMNSheet<bool>(context,
        builder: (_) => _EditPersonSheet(
            name: vendor.name,
            phone: vendor.phone,
            save: (r, name, phone, reason) => r.updateVendor(vendor.id,
                name: name, phone: phone, reason: reason)));
    if (phoneChanged == null) return;
    _refresh(ref);
    if (!context.mounted) return;
    _toast(context, ref.read(stringsProvider).changesSaved);
    if (phoneChanged) {
      await _offerCode(context, ref,
          name: vendor.name,
          staff: false,
          issue: (r) => r.vendorCode(vendor.id));
    }
  }

  /// Moving the vendor ends this placement, so the page closes after it.
  Future<void> _move(
      BuildContext context, WidgetRef ref, OfficeVendor vendor) async {
    final s = ref.read(stringsProvider);
    try {
      final station = await pickStation(context, ref);
      if (station == null || station.id == stationId) return;
      await ref.read(officeSessionProvider.notifier).guard((r) =>
          r.assignVendor(
              vendorId: vendor.id,
              stationId: station.id,
              reason: s.officeReason));
      _refresh(ref);
      if (!context.mounted) return;
      _toast(context, s.changesSaved);
      context.pop();
    } catch (error) {
      if (context.mounted) _toast(context, officeErrorText(s, error));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, OfficeVendor vendor,
      OfficeStation station) async {
    final done = await showMNSheet<bool>(context,
        builder: (_) => _RemoveFromStation(vendor: vendor, station: station));
    if (done != true) return;
    _refresh(ref);
    if (context.mounted) context.pop();
  }

  void _more(BuildContext context, WidgetRef ref, OfficeVendor vendor,
      ({bool manage, bool owner, bool supervisor, String? id}) me) {
    final s = ref.read(stringsProvider);
    showMNSheet<void>(context, builder: (sheetContext) {
      void then(Future<void> Function() action) {
        Navigator.pop(sheetContext);
        action();
      }

      return MNSheet(children: [
        Row(children: [
          Expanded(
              child: Text(vendor.name,
                  style: OwnerStyle.text(context, 21, weight: 700))),
          IconButton(
              tooltip: s.close,
              onPressed: () => Navigator.pop(sheetContext),
              icon: const MNIcon(MNIconData.x, color: OwnerStyle.muted)),
        ]),
        OwnerCard(
            child: _divided([
          if (me.manage && !vendor.left)
            OwnerMenuRow(
                label: s.editPerson,
                onTap: () => then(() => _edit(context, ref, vendor))),
          if ((me.manage || me.supervisor) && !vendor.left)
            OwnerMenuRow(
                label: vendor.activated ? s.resetPinCode : s.newCode,
                onTap: () => then(() => _issueCode(context, ref,
                    name: vendor.name,
                    staff: false,
                    issue: (r) =>
                        r.vendorCode(vendor.id, reset: vendor.activated)))),
          OwnerMenuRow(
              label: s.personFullProfile,
              onTap: () => then(() async {
                    await context.push(MNRoutes.officeVendor(vendor.id));
                  })),
        ])),
      ]);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final vendors = ref.watch(officeVendorsProvider);
    final stations = ref.watch(officeStationsProvider);
    final vendor =
        vendors.valueOrNull?.where((v) => v.id == vendorId).firstOrNull;
    final station =
        stations.valueOrNull?.where((x) => x.id == stationId).firstOrNull;
    final me = _me(ref);
    double u(double n) => OwnerStyle.px(context, n);
    return OwnerPage(
        title: vendor?.name ?? s.vendors,
        strings: s,
        contentGap: 30,
        onRefresh: () async {
          _refresh(ref);
          await ref.read(officeVendorsProvider.future);
        },
        trailing: vendor == null
            ? null
            : Semantics(
                label: s.personMoreActions,
                button: true,
                child: MNPressable(
                    onTap: () => _more(context, ref, vendor, me),
                    pressedScale: 1,
                    child: SizedBox(
                        width: u(48).clamp(48, 80),
                        height: u(48).clamp(48, 80),
                        child: const Center(
                            child: MNIcon(MNIconData.more,
                                color: OwnerStyle.ink))))),
        header: vendor == null ? null : _StationVendorHeader(vendor: vendor),
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: u(13)),
            child: OwnerAsyncView(
                value: vendors,
                onRetry: () => ref.invalidate(officeVendorsProvider),
                data: (_) {
                  if (vendor == null || station == null) {
                    return MNNote(s.personNotFound, tone: MNNoteTone.info);
                  }
                  final edit = me.manage && !vendor.left;
                  final atStation = vendor.stationId == station.id;
                  final since = vendor.stationSince;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: EdgeInsets.only(left: u(3), bottom: u(10)),
                            child: Semantics(
                                header: true,
                                child: Text(s.personBasics,
                                    style: OwnerStyle.text(context, 19,
                                        weight: 700)))),
                        OwnerCard(
                            child: _stationRows([
                          OwnerMenuRow(
                              label: s.phoneLabel,
                              value: displayPhone(vendor.phone),
                              valueColor: OwnerStyle.muted,
                              valueWeight: 400,
                              valueMaxWidth: 190,
                              showChevron: edit,
                              onTap: edit
                                  ? () => _edit(context, ref, vendor)
                                  : null),
                          OwnerMenuRow(
                              label: s.personDuty,
                              value: s.stationVendorRole,
                              valueColor: OwnerStyle.muted,
                              valueWeight: 400,
                              onTap: () => context
                                  .push(MNRoutes.officeVendor(vendor.id))),
                          OwnerMenuRow(
                              label: s.station,
                              value: '${station.name} (${station.code})',
                              valueColor: OwnerStyle.muted,
                              valueWeight: 400,
                              valueMaxWidth: 190,
                              showChevron: edit,
                              onTap: edit
                                  ? () => _move(context, ref, vendor)
                                  : null),
                          OwnerMenuRow(
                              label: s.personStarted,
                              value: atStation && since != null
                                  ? s.date(since)
                                  : '—',
                              valueColor: OwnerStyle.muted,
                              valueWeight: 400,
                              onTap: () => context
                                  .push(MNRoutes.officeVendor(vendor.id))),
                        ])),
                        if (edit && atStation) ...[
                          SizedBox(height: u(28)),
                          OwnerCard(
                              child: OwnerMenuRow(
                                  label: s.stationRemovePerson,
                                  labelColor: OwnerStyle.red,
                                  onTap: () =>
                                      _remove(context, ref, vendor, station))),
                        ],
                      ]);
                })));
  }
}

Widget _stationRows(List<Widget> rows) => Column(children: [
      for (final (i, row) in rows.indexed) ...[
        if (i > 0)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: OwnerStyle.line)),
        row,
      ]
    ]);

class _StationVendorHeader extends StatelessWidget {
  final OfficeVendor vendor;
  const _StationVendorHeader({required this.vendor});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    final words = vendor.name.trim().split(RegExp(r'\s+'));
    final initials = words.length > 1
        ? '${words.first.characters.first}${words.last.characters.first}'
        : words.first.characters.take(2).toString();
    return Consumer(
        builder: (context, ref, _) => Padding(
            padding: EdgeInsets.symmetric(horizontal: u(23)),
            child: Row(children: [
              MNPersonPhoto(
                  imageUrl: vendor.imageUrl,
                  size: u(72),
                  color: OwnerStyle.avatar,
                  initials: Text(initials.toUpperCase(),
                      style: OwnerStyle.text(context, 26, weight: 600))),
              SizedBox(width: u(18)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Semantics(
                        header: true,
                        child: Text(vendor.name,
                            style: OwnerStyle.text(context, 28,
                                weight: 700, spacing: -.6))),
                    SizedBox(height: u(2)),
                    Text(ref.watch(stringsProvider).stationVendorRole,
                        style: OwnerStyle.text(context, 18,
                            color: OwnerStyle.muted)),
                  ])),
            ])));
  }
}

class _RemoveFromStation extends ConsumerStatefulWidget {
  final OfficeVendor vendor;
  final OfficeStation station;
  const _RemoveFromStation({required this.vendor, required this.station});
  @override
  ConsumerState<_RemoveFromStation> createState() => _RemoveFromStationState();
}

class _RemoveFromStationState extends ConsumerState<_RemoveFromStation> {
  bool _busy = false;
  String? _error;

  Future<void> _remove() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await stationGuard(
          ref,
          (r) => r.endVendorStation(widget.vendor.id,
              s.stationRemoveTitle(widget.vendor.name, widget.station.name)));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = officeErrorText(s, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    Widget action(String label,
            {required bool primary, required VoidCallback? onTap}) =>
        MNPressable(
            onTap: onTap,
            semanticLabel: label,
            color: primary ? OwnerStyle.red : OwnerStyle.line,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: primary && _busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: OwnerStyle.white))
                            : ExcludeSemantics(
                                child: Text(label,
                                    textAlign: TextAlign.center,
                                    style: OwnerStyle.text(context, 18,
                                        weight: primary ? 600 : 500,
                                        color: primary
                                            ? OwnerStyle.white
                                            : OwnerStyle.navMuted)))))));
    return PopScope(
        canPop: !_busy,
        child: MNSheet(children: [
          Semantics(
              header: true,
              child: Text(
                  s.stationRemoveTitle(widget.vendor.name, widget.station.name),
                  textAlign: TextAlign.center,
                  style: OwnerStyle.text(context, 21, weight: 700))),
          Text(s.stationRemoveBody,
              textAlign: TextAlign.center,
              style: OwnerStyle.text(context, 16,
                  color: OwnerStyle.muted, height: 1.45)),
          if (_error != null)
            Text(_error!,
                textAlign: TextAlign.center,
                style: OwnerStyle.text(context, 15, color: OwnerStyle.red)),
          action(s.stationRemovePerson,
              primary: true, onTap: _busy ? null : _remove),
          action(s.cancel,
              primary: false,
              onTap: _busy ? null : () => Navigator.of(context).pop(false)),
        ]));
  }
}
