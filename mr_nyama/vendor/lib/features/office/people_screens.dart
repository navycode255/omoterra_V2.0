import 'owner_widgets.dart';
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
import '../../shared/widgets/contact_phone_picker.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/payment_option.dart';
import '../../shared/widgets/sheet.dart';
import 'owner_reference.dart';
import 'office_errors.dart';
import 'setup_screens.dart';

export 'office_errors.dart';

// Data ---------------------------------------------------------------------------------

final officeVendorsProvider = FutureProvider.autoDispose<List<OfficeVendor>>(
    (ref) =>
        ref.read(officeSessionProvider.notifier).guard((r) => r.vendors()));

final officeStaffProvider = FutureProvider.autoDispose<List<OfficeStaff>>(
    (ref) => ref.read(officeSessionProvider.notifier).guard((r) => r.staff()));

final officeStationsProvider = FutureProvider.autoDispose<List<OfficeStation>>(
    (ref) =>
        ref.read(officeSessionProvider.notifier).guard((r) => r.stations()));

/// What the code screen shows, passed as the route's `extra`.
class IssuedCodeArgs {
  final String name;
  final IssuedCode code;
  final bool staff;
  const IssuedCodeArgs(
      {required this.name, required this.code, required this.staff});
}

String _errorText(Strings strings, Object error) =>
    officeErrorText(strings, error);

// Vendors ------------------------------------------------------------------------------

class OfficeVendorsScreen extends ConsumerWidget {
  const OfficeVendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final vendors = ref.watch(officeVendorsProvider);
    final count =
        vendors.valueOrNull?.where((v) => v.stationName == null).length;
    return OwnerPage(
        title: strings.vendors,
        strings: strings,
        onRefresh: () => ref.refresh(officeVendorsProvider.future),
        vendorSpacing: true,
        onAdd: () => context.push(MNRoutes.officeNewVendor),
        addLabel: strings.addVendor,
        subtitle: Text(
            count == null
                ? strings.ownerUnassigned(0).replaceFirst('0', '—')
                : strings.ownerUnassigned(count),
            style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
        child: OwnerAsyncView(
          value: vendors,
          onRetry: () => ref.invalidate(officeVendorsProvider),
          data: (items) => Column(children: [
            for (final vendor in items)
              Padding(
                  padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 12), 0,
                      OwnerStyle.px(context, 12), OwnerStyle.px(context, 12)),
                  child: _ApprovedPersonRow(
                      name: vendor.name,
                      imageUrl: vendor.imageUrl,
                      subtitle:
                          '${vendor.left ? strings.statusLeft : vendor.suspended ? strings.statusSuspended : strings.ownerVendorActive}, ${vendor.stationName ?? strings.ownerVendorUnassigned}',
                      action: vendor.stationName == null && !vendor.left
                          ? strings.ownerAssignStation
                          : null,
                      onTap: () =>
                          context.push(MNRoutes.officeVendor(vendor.id)),
                      // Someone who has left is read-only.
                      onLongPress: vendor.left
                          ? null
                          : () => _vendorActions(context, ref, vendor))),
            Padding(
                padding: EdgeInsets.only(top: OwnerStyle.px(context, 4)),
                child: Text(strings.ownerAddVendorHint,
                    textAlign: TextAlign.center,
                    style:
                        OwnerStyle.text(context, 13, color: OwnerStyle.muted))),
          ]),
        ));
  }

  Future<void> _vendorActions(
      BuildContext context, WidgetRef ref, OfficeVendor vendor) {
    final strings = ref.read(stringsProvider);
    return showMNSheet<void>(context,
        builder: (sheet) => MNSheet(title: vendor.name, children: [
              MNButton(
                  vendor.activated ? strings.resetPinCode : strings.newCode,
                  icon: MNIconData.key,
                  onPressed: () => _run(context, ref, sheet, () async {
                        final code = await ref
                            .read(officeSessionProvider.notifier)
                            .guard((r) => r.vendorCode(vendor.id,
                                reset: vendor.activated));
                        if (context.mounted) {
                          context.push(MNRoutes.officeIssuedCode,
                              extra: IssuedCodeArgs(
                                  name: vendor.name, code: code, staff: false));
                        }
                      })),
              MNButton.secondary(strings.changeStation,
                  onPressed: () => _run(context, ref, sheet, () async {
                        final station = await pickStation(context, ref);
                        if (station == null) return;
                        await ref.read(officeSessionProvider.notifier).guard(
                            (r) => r.assignVendor(
                                vendorId: vendor.id,
                                stationId: station.id,
                                reason: strings.officeReason));
                        ref.invalidate(officeVendorsProvider);
                      })),
            ]));
  }
}

/// Shared geometry keeps Wauzaji and Wafanyakazi visually identical.
class _ApprovedPersonRow extends StatelessWidget {
  final String name, subtitle;
  final String? action, imageUrl;
  final Color? actionColor;
  final Widget? leading;
  final double minHeight,
      horizontalPadding,
      verticalPadding,
      nameSize,
      subtitleSize,
      actionSize,
      chevronSize,
      avatarGap;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ApprovedPersonRow(
      {required this.name,
      required this.subtitle,
      this.action,
      this.imageUrl,
      this.actionColor,
      this.leading,
      this.minHeight = 78,
      this.horizontalPadding = 18,
      this.verticalPadding = 16,
      this.nameSize = 14.5,
      this.subtitleSize = 12.5,
      this.actionSize = 12.5,
      this.chevronSize = 14,
      this.avatarGap = 16,
      required this.onTap,
      this.onLongPress});
  @override
  Widget build(BuildContext context) {
    double u(double n) => OwnerStyle.px(context, n);
    return OwnerCard(
        child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: u(minHeight)),
                child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: u(horizontalPadding),
                        vertical: u(verticalPadding)),
                    child: Row(children: [
                      leading ??
                          MNPersonPhoto(
                              imageUrl: imageUrl,
                              size: u(46),
                              color: OwnerStyle.avatar,
                              initials: Text(MNAvatar.initials(name),
                                  style: OwnerStyle.text(context, 15))),
                      SizedBox(width: u(avatarGap)),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: OwnerStyle.text(context, nameSize),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text(subtitle,
                                style: OwnerStyle.text(context, subtitleSize,
                                    color: OwnerStyle.muted)),
                          ])),
                      if (action != null) ...[
                        SizedBox(width: u(8)),
                        Text(action!,
                            style: OwnerStyle.text(context, actionSize,
                                weight: 500,
                                color: actionColor ?? OwnerStyle.assignAction,
                                spacing: -.2)),
                      ],
                      SizedBox(width: u(15)),
                      OwnerGlyph('vendor-chevron', size: chevronSize),
                    ])))));
  }
}

/// Closes [sheet], runs [action] and explains any refusal in a toast.
Future<void> _run(BuildContext context, WidgetRef ref, BuildContext sheet,
    Future<void> Function() action) async {
  final strings = ref.read(stringsProvider);
  Navigator.of(sheet).pop();
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorText(strings, error))));
    }
  }
}

/// Lets the user choose a station; null when dismissed.
Future<OfficeStation?> pickStation(BuildContext context, WidgetRef ref) async {
  final strings = ref.read(stringsProvider);
  final stations =
      await ref.read(officeSessionProvider.notifier).guard((r) => r.stations());
  if (!context.mounted) return null;
  return showMNSheet<OfficeStation>(context,
      builder: (sheet) => MNSheet(title: strings.chooseStation, children: [
            if (stations.isEmpty)
              MNNote(strings.noStations, tone: MNNoteTone.info),
            for (final s in stations)
              MNPaymentOption(
                  icon: MNIconData.store,
                  title: s.name,
                  // Several vendors may share one station.
                  caption:
                      '${s.code} · ${strings.stationVendorCount(s.vendorCount)}',
                  selected: false,
                  onTap: () => Navigator.of(sheet).pop(s)),
          ]));
}

class OfficeNewVendorScreen extends ConsumerStatefulWidget {
  const OfficeNewVendorScreen({super.key});

  @override
  ConsumerState<OfficeNewVendorScreen> createState() => _NewVendorState();
}

class _NewVendorState extends ConsumerState<OfficeNewVendorScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  OfficeStation? _station;
  String? _nameError, _phoneError, _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final name = _name.text.trim();
    final phone = normaliseTanzanianPhone(_phone.text);
    setState(() {
      _nameError = name.length < 2 ? strings.nameRequired : null;
      _phoneError = phone == null ? strings.phoneInvalid : null;
      _error = null;
    });
    if (_nameError != null || _phoneError != null) return;
    setState(() => _busy = true);
    final office = ref.read(officeSessionProvider.notifier);
    try {
      final id =
          await office.guard((r) => r.addVendor(name: name, phone: phone!));
      if (_station != null) {
        await office.guard((r) => r.assignVendor(
            vendorId: id,
            stationId: _station!.id,
            reason: strings.officeReason));
      }
      final code = await office.guard((r) => r.vendorCode(id));
      ref.invalidate(officeVendorsProvider);
      if (mounted) {
        context.pushReplacement(MNRoutes.officeIssuedCode,
            extra: IssuedCodeArgs(name: name, code: code, staff: false));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(strings, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return OwnerPage(
      title: strings.addVendor,
      strings: strings,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
          child: MNButton(strings.register,
              busy: _busy, onPressed: _busy ? null : _save),
        ),
      ),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: OwnerFormSection(children: [
            MNTextField(
                label: strings.fullName,
                controller: _name,
                icon: MNIconData.user,
                textInputAction: TextInputAction.next,
                error: _nameError),
            const SizedBox(height: MNSpace.x4),
            OfficePhoneInput(controller: _phone, error: _phoneError),
            const SizedBox(height: MNSpace.x4),
            Text(strings.station, style: MNText.resolve(context, MNText.label)),
            const SizedBox(height: 6),
            MNPaymentOption(
                icon: MNIconData.store,
                title: _station?.name ?? strings.chooseStation,
                caption: _station?.code ?? strings.noStation,
                selected: _station != null,
                onTap: () async {
                  final station = await pickStation(context, ref);
                  if (station != null) setState(() => _station = station);
                }),
            if (_error != null) ...[
              const SizedBox(height: MNSpace.x4),
              MNNote(_error!, error: true),
            ],
          ])),
    );
  }
}

class OfficePhoneInput extends ConsumerWidget {
  final TextEditingController controller;
  final String? error;
  final bool enabled;
  const OfficePhoneInput(
      {super.key, required this.controller, this.error, this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return MNTextField(
      label: strings.phoneLabel,
      controller: controller,
      icon: MNIconData.phone,
      prefix: Text(strings.countryCode,
          style: MNText.resolve(context, MNText.input)),
      hint: '712 345 678',
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      error: error,
      enabled: enabled,
      // Pick from the phone's contacts, or keep typing the number.
      suffix: MNContactPickButton(
          enabled: enabled,
          onPicked: (phone) => controller.text = phone.replaceFirst('+255', '')),
    );
  }
}

// Staff --------------------------------------------------------------------------------

class OfficeStaffScreen extends ConsumerWidget {
  const OfficeStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final staff = ref.watch(officeStaffProvider);
    return OwnerPage(
        title: strings.staffMembers,
        strings: strings,
        vendorSpacing: true,
        onRefresh: () => ref.refresh(officeStaffProvider.future),
        onAdd: () => context.push(MNRoutes.officeNewStaff),
        addLabel: strings.addStaff,
        contentGap: 19.3,
        headingTopGap: 9,
        addIcon: 'product-plus',
        child: OwnerAsyncView(
          value: staff,
          onRetry: () => ref.invalidate(officeStaffProvider),
          data: (items) => Column(children: [
            for (final person in items)
              Padding(
                  padding: EdgeInsets.fromLTRB(OwnerStyle.px(context, 13.5), 0,
                      OwnerStyle.px(context, 13.5), OwnerStyle.px(context, 12)),
                  child: _ApprovedPersonRow(
                      minHeight: 71,
                      verticalPadding: 12.5,
                      horizontalPadding: 15,
                      avatarGap: 15,
                      chevronSize: 17,
                      name: person.name,
                      imageUrl: person.imageUrl,
                      subtitle: person.roles.map(strings.roleName).join(', '),
                      action: person.left
                          ? strings.statusLeft
                          : person.suspended
                              ? strings.statusSuspended
                              : person.activated
                                  ? strings.ownerVendorActive
                                  : strings.statusPending,
                      actionColor: person.left || person.suspended
                          ? MNColors.error
                          : person.activated
                              ? MNColors.success
                              : MNColors.warning,
                      onTap: () =>
                          context.push(MNRoutes.officeStaffMember(person.id)),
                      onLongPress:
                          person.roles.contains(StaffRole.owner) || person.left
                              ? null
                              : () => _staffActions(context, ref, person))),
            Padding(
                padding: EdgeInsets.only(top: OwnerStyle.px(context, 11.5)),
                child: Text(strings.ownerAddStaffHint,
                    textAlign: TextAlign.center,
                    style:
                        OwnerStyle.text(context, 13, color: OwnerStyle.muted))),
          ]),
        ));
  }

  Future<void> _staffActions(
      BuildContext context, WidgetRef ref, OfficeStaff staff) {
    final strings = ref.read(stringsProvider);
    return showMNSheet<void>(context,
        builder: (sheet) => MNSheet(title: staff.name, children: [
              MNButton.secondary(strings.workStations, icon: MNIconData.store,
                  onPressed: () {
                Navigator.of(sheet).pop();
                context.push(MNRoutes.officeStaffStations(staff.id));
              }),
              MNButton(staff.activated ? strings.resetPinCode : strings.newCode,
                  icon: MNIconData.key, onPressed: () async {
                Navigator.of(sheet).pop();
                try {
                  final code = await ref
                      .read(officeSessionProvider.notifier)
                      .guard(
                          (r) => r.staffCode(staff.id, reset: staff.activated));
                  if (context.mounted) {
                    context.push(MNRoutes.officeIssuedCode,
                        extra: IssuedCodeArgs(
                            name: staff.name, code: code, staff: true));
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_errorText(strings, error))));
                  }
                }
              }),
            ]));
  }
}

class OfficeNewStaffScreen extends ConsumerStatefulWidget {
  const OfficeNewStaffScreen({super.key});

  @override
  ConsumerState<OfficeNewStaffScreen> createState() => _NewStaffState();
}

class _NewStaffState extends ConsumerState<OfficeNewStaffScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _role = StaffRole.supervisor;
  OfficeStation? _station;
  String? _kitchen;
  String? _nameError, _phoneError, _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final name = _name.text.trim();
    final phone = normaliseTanzanianPhone(_phone.text);
    setState(() {
      _nameError = name.length < 2 ? strings.nameRequired : null;
      _phoneError = phone == null ? strings.phoneInvalid : null;
      _error = null;
    });
    if (_role == StaffRole.kitchen && _kitchen == null) {
      setState(() => _error = strings.kitchenRequired);
      return;
    }
    if (_nameError != null || _phoneError != null) return;
    setState(() => _busy = true);
    final office = ref.read(officeSessionProvider.notifier);
    try {
      final id =
          await office.guard((r) => r.addStaff(name: name, phone: phone!));
      if (_role == StaffRole.kitchen) {
        await officeSetupCall(
            ref,
            (r) => r.grantKitchenRole(
                staffId: id,
                kitchenLocationId: _kitchen!,
                reason: strings.officeReason));
      } else {
        await office.guard((r) => r.grantRole(
            staffId: id, role: _role, reason: strings.officeReason));
      }
      if (_role == StaffRole.supervisor && _station != null) {
        await office.guard((r) => r.assignSupervisor(
            stationId: _station!.id,
            staffId: id,
            reason: strings.officeReason));
      }
      final code = await office.guard((r) => r.staffCode(id));
      ref.invalidate(officeStaffProvider);
      if (mounted) {
        context.pushReplacement(MNRoutes.officeIssuedCode,
            extra: IssuedCodeArgs(name: name, code: code, staff: true));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(strings, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final me = ref.watch(officeSessionProvider).valueOrNull;
    final owner = me is OfficeSignedIn && me.profile.isOwner;
    // Only the owner may appoint managers; an operations manager adds supervisors.
    final roles = [
      StaffRole.supervisor,
      StaffRole.kitchen,
      if (owner) StaffRole.finance,
      if (owner) StaffRole.operationsAdmin,
    ];
    return OwnerPage(
      title: strings.addStaff,
      strings: strings,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              MNSpace.x4, MNSpace.x2, MNSpace.x4, MNSpace.x4),
          child: MNButton(strings.register,
              busy: _busy, onPressed: _busy ? null : _save),
        ),
      ),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: OwnerFormSection(children: [
            MNTextField(
                label: strings.fullName,
                controller: _name,
                icon: MNIconData.user,
                textInputAction: TextInputAction.next,
                error: _nameError),
            const SizedBox(height: MNSpace.x4),
            OfficePhoneInput(controller: _phone, error: _phoneError),
            const SizedBox(height: MNSpace.x4),
            Text(strings.role, style: MNText.resolve(context, MNText.label)),
            const SizedBox(height: 6),
            for (final role in roles) ...[
              MNPaymentOption(
                  icon: MNIconData.user,
                  title: strings.roleName(role),
                  caption: _role == role ? strings.roleHint(role) : '',
                  selected: _role == role,
                  onTap: () => setState(() => _role = role)),
              const SizedBox(height: MNSpace.x2),
            ],
            if (_role == StaffRole.kitchen) ...[
              const SizedBox(height: MNSpace.x2),
              KitchenChoice(
                  value: _kitchen,
                  enabled: !_busy,
                  onChanged: (v) => setState(() => _kitchen = v)),
            ],
            if (_role == StaffRole.supervisor) ...[
              const SizedBox(height: MNSpace.x2),
              Text(strings.station,
                  style: MNText.resolve(context, MNText.label)),
              const SizedBox(height: 6),
              MNPaymentOption(
                  icon: MNIconData.store,
                  title: _station?.name ?? strings.chooseStation,
                  caption: _station?.code ?? strings.noStation,
                  selected: _station != null,
                  onTap: () async {
                    final station = await _anyStation(context);
                    if (station != null) setState(() => _station = station);
                  }),
            ],
            if (_error != null) ...[
              const SizedBox(height: MNSpace.x4),
              MNNote(_error!, error: true),
            ],
          ])),
    );
  }

  /// Any station; several vendors may share one.
  Future<OfficeStation?> _anyStation(BuildContext context) async {
    final strings = ref.read(stringsProvider);
    final stations = await ref
        .read(officeSessionProvider.notifier)
        .guard((r) => r.stations());
    if (!context.mounted) return null;
    return showMNSheet<OfficeStation>(context,
        builder: (sheet) => MNSheet(title: strings.chooseStation, children: [
              if (stations.isEmpty)
                MNNote(strings.noStations, tone: MNNoteTone.info),
              for (final s in stations)
                MNPaymentOption(
                    icon: MNIconData.store,
                    title: s.name,
                    caption:
                        '${s.code} · ${strings.stationVendorCount(s.vendorCount)}',
                    selected: s.id == _station?.id,
                    onTap: () => Navigator.of(sheet).pop(s)),
            ]));
  }
}

// Stations -----------------------------------------------------------------------------

class OfficeStationsScreen extends ConsumerWidget {
  final bool showBack;
  const OfficeStationsScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final stations = ref.watch(officeStationsProvider);
    final auth = ref.watch(officeSessionProvider).valueOrNull;
    final manage = auth is OfficeSignedIn && auth.profile.canManagePeople;
    final count = stations.valueOrNull?.where((s) => !s.hasVendor).length;
    return OwnerPage(
        title: strings.stations,
        strings: strings,
        showBack: showBack,
        vendorSpacing: true,
        onRefresh: () => ref.refresh(officeStationsProvider.future),
        onAdd: manage ? () => showOwnerStationForm(context) : null,
        addLabel: strings.addStation,
        subtitle: Text(strings.ownerStationsWithoutVendor(count),
            style: OwnerStyle.text(context, 15, color: OwnerStyle.secondary)),
        contentGap: 29,
        headingSize: 36,
        headingTopGap: 13,
        addIcon: 'product-plus',
        child: OwnerAsyncView(
            value: stations,
            onRetry: () => ref.invalidate(officeStationsProvider),
            data: (items) => Column(children: [
                  for (final station in items)
                    Padding(
                        padding: EdgeInsets.fromLTRB(
                            OwnerStyle.px(context, 16),
                            0,
                            OwnerStyle.px(context, 16),
                            OwnerStyle.px(context, 12)),
                        child: _ApprovedPersonRow(
                            nameSize: 17,
                            subtitleSize: 13.5,
                            actionSize: 13.5,
                            chevronSize: 17,
                            name: station.name,
                            subtitle: station.hasVendor
                                ? '${station.code} · '
                                    '${strings.stationVendorCount(station.vendorCount)}'
                                : station.code,
                            leading: SizedBox(
                                width: OwnerStyle.px(context, 30),
                                child: const OwnerGlyph('store', size: 27)),
                            action: station.hasVendor
                                ? null
                                : strings.ownerAssignVendor,
                            onTap: () => context
                                .push(MNRoutes.officeStation(station.id)))),
                  Padding(
                      padding: EdgeInsets.only(top: OwnerStyle.px(context, 7)),
                      child: Text(strings.ownerAddStationHint,
                          textAlign: TextAlign.center,
                          style: OwnerStyle.text(context, 13,
                              color: OwnerStyle.muted))),
                ])));
  }
}

Future<void> showOwnerStationForm(BuildContext context) =>
    showMNSheet<void>(context, builder: (_) => const _NewStationSheet());

class _NewStationSheet extends ConsumerStatefulWidget {
  const _NewStationSheet();

  @override
  ConsumerState<_NewStationSheet> createState() => _NewStationSheetState();
}

class _NewStationSheetState extends ConsumerState<_NewStationSheet> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  String? _nameError, _codeError, _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final name = _name.text.trim();
    final code = _code.text.trim().toUpperCase();
    setState(() {
      _nameError = name.length < 2 ? strings.nameRequired : null;
      _codeError = RegExp(r'^[A-Z0-9][A-Z0-9-]{1,19}$').hasMatch(code)
          ? null
          : strings.stationCodeInvalid;
      _error = null;
    });
    if (_nameError != null || _codeError != null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(officeSessionProvider.notifier)
          .guard((r) => r.addStation(code: code, name: name));
      ref.invalidate(officeStationsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is OfficeError && error.kind == OfficeErrorKind.duplicate
                ? strings.duplicateStation
                : _errorText(strings, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return MNSheet(title: strings.addStation, children: [
      MNTextField(
          label: strings.stationName,
          controller: _name,
          icon: MNIconData.store,
          textInputAction: TextInputAction.next,
          error: _nameError),
      MNTextField(
          label: strings.stationCode,
          controller: _code,
          hint: strings.stationCodeHint,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
            LengthLimitingTextInputFormatter(20),
          ],
          error: _codeError),
      if (_error != null) MNNote(_error!, error: true),
      MNButton(strings.addStation,
          busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}

// The issued code ----------------------------------------------------------------------

/// Shows a one-time code once, large, with how to use it. Nothing stores it.
class OfficeIssuedCodeScreen extends ConsumerStatefulWidget {
  final IssuedCodeArgs args;
  const OfficeIssuedCodeScreen({super.key, required this.args});
  @override
  ConsumerState<OfficeIssuedCodeScreen> createState() =>
      _OfficeIssuedCodeState();
}

class _OfficeIssuedCodeState extends ConsumerState<OfficeIssuedCodeScreen> {
  bool _copied = false;
  String? _error;
  Future<void> _copyCode() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.args.code.code));
      HapticFeedback.selectionClick();
      if (mounted) {
        setState(() {
          _copied = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = ref.read(stringsProvider).copyFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final args = widget.args;
    double u(double n) => OwnerStyle.px(context, n);
    TextStyle text(double size,
            {double weight = 400, Color color = OwnerStyle.ink}) =>
        OwnerStyle.text(context, size,
            weight: weight, color: color, height: 1.3);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: OwnerStyle.white,
          systemNavigationBarColor: OwnerStyle.white),
      child: Scaffold(
        backgroundColor: OwnerStyle.white,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: EdgeInsets.fromLTRB(u(20), u(8), u(20), u(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OwnerIconButton('back',
                          label: s.back, onTap: () => context.pop()),
                      SizedBox(height: u(6)),
                      Text(s.codeTitle, style: text(28, weight: 750)),
                    ])),
            const Divider(color: OwnerStyle.line),
            Expanded(
                child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(u(30), u(24), u(30), u(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(s.codeFor(args.name),
                              textAlign: TextAlign.center,
                              style: text(21, weight: 700)),
                          SizedBox(height: u(20)),
                          Semantics(
                              label: args.code.code.split('').join(' '),
                              child: ExcludeSemantics(
                                  child: GestureDetector(
                                      onTap: _copyCode,
                                      child: Row(children: [
                                        for (final (i, digit) in args.code.code
                                            .split('')
                                            .indexed) ...[
                                          if (i > 0) SizedBox(width: u(5)),
                                          Expanded(
                                              child: Container(
                                                  height: u(61),
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                      color: MNColors.surface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              u(12))),
                                                  child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(digit,
                                                          style: text(34,
                                                              weight: 750))))),
                                        ],
                                      ])))),
                          SizedBox(height: u(20)),
                          Center(
                              child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: u(178)),
                                  child: MNPressable(
                                      onTap: _copyCode,
                                      semanticLabel: s.copyCode,
                                      color: MNColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(u(12)),
                                      child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: u(24),
                                              vertical: u(12)),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const MNIcon(MNIconData.copy,
                                                    size: 24),
                                                SizedBox(width: u(10)),
                                                ExcludeSemantics(
                                                    child: Text(s.copyCode,
                                                        style: text(16,
                                                            weight: 600))),
                                              ]))))),
                          SizedBox(height: u(10)),
                          if (_copied)
                            Semantics(
                                liveRegion: true,
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                              color: MNColors.success,
                                              shape: BoxShape.circle),
                                          child: const Center(
                                              child: MNIcon(MNIconData.check,
                                                  color: MNColors.white,
                                                  size: 13))),
                                      SizedBox(width: u(8)),
                                      Flexible(
                                          child: Text(s.codeCopied,
                                              style: text(14,
                                                  color: MNColors.success))),
                                    ])),
                          if (_error != null) MNNote(_error!, error: true),
                          SizedBox(height: u(24)),
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: u(20), vertical: u(14)),
                              decoration: BoxDecoration(
                                  color: MNColors.surface,
                                  borderRadius: BorderRadius.circular(u(12))),
                              child: Row(children: [
                                const MNIcon(MNIconData.info,
                                    size: 28, color: MNColors.ink2),
                                SizedBox(width: u(18)),
                                Container(
                                    width: 1,
                                    height: u(54),
                                    color: OwnerStyle.line),
                                SizedBox(width: u(16)),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(s.codeOneUse,
                                          style: text(15, weight: 700)),
                                      Text(s.codeExpiry(args.code.validHours),
                                          style:
                                              text(14, color: MNColors.ink2)),
                                      Text(s.codeNotShownAgain,
                                          style:
                                              text(14, color: MNColors.ink2)),
                                    ])),
                              ])),
                          SizedBox(height: u(20)),
                          Text(args.staff ? s.codeHowStaff : s.codeHowVendor,
                              textAlign: TextAlign.center,
                              style: text(15, color: MNColors.ink2)),
                        ]))),
            Padding(
                padding: EdgeInsets.fromLTRB(u(20), u(12), u(20), u(24)),
                child: MNPressable(
                    onTap: () => context.pop(),
                    semanticLabel: s.done,
                    color: OwnerStyle.red,
                    borderRadius: BorderRadius.circular(u(12)),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                            padding: EdgeInsets.all(u(14)),
                            child: Text(s.done,
                                textAlign: TextAlign.center,
                                style: text(20,
                                    weight: 700, color: OwnerStyle.white)))))),
          ]),
        ))),
      ),
    );
  }
}
