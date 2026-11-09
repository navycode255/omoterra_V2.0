import '../../core/auth/biometrics.dart';
import '../../shared/widgets/biometric_lock.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/providers.dart';
import '../../core/api/vendor_repository.dart';
import '../../core/auth/auth_flow.dart';
import '../../core/auth/session.dart';
import '../../core/l10n/language.dart';
import '../../core/l10n/strings.dart';
import '../../core/routing/routes.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/account.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/sync_indicator.dart';
import '../../shared/widgets/workflow_header.dart';
import '../home/dashboard.dart';

final pickProfilePhotoProvider =
    Provider<Future<Uint8List?> Function()>((ref) => () async {
          final file = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 88,
              requestFullMetadata: false);
          if (file == null) return null;
          if (await file.length() > 5 * 1024 * 1024) {
            throw const FormatException();
          }
          return file.readAsBytes();
        });

/// Vendor account: the same settings/sign-out pattern as office, retaining
/// vendor typography and only the vendor's own account/operational details.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _photoBusy = false;
  String? _photoError;

  Future<void> _changePhoto(VendorProfile profile) async {
    if (_photoBusy) return;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    final strings = ref.read(stringsProvider);
    try {
      final bytes = await ref.read(pickProfilePhotoProvider)();
      if (bytes == null) return;
      final repository = ref.read(vendorRepositoryProvider);
      final mediaRepository = repository is VendorMediaRepository
          ? repository as VendorMediaRepository
          : null;
      if (mediaRepository == null) {
        throw const AuthFailure(AuthFailureKind.notConfigured);
      }
      final url = await ref.read(sessionProvider.notifier).authorised(
          (token) => mediaRepository.uploadProfileImage(token, bytes));
      await ref
          .read(sessionProvider.notifier)
          .updateProfile(profile.copyWith(profileImageUrl: url));
    } catch (_) {
      if (mounted) setState(() => _photoError = strings.photoFailed);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final s = ref.watch(stringsProvider);
    final auth = ref.watch(sessionProvider).valueOrNull;
    if (auth is! SignedIn) {
      return Scaffold(appBar: MNWorkflowHeader(title: s.ownerAccount));
    }
    final profile = auth.profile;
    ref.watch(queueCountsProvider);
    return Scaffold(
      backgroundColor: MNColors.pageBackground,
      appBar: MNWorkflowHeader(title: s.ownerAccount),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MNAccountIdentity(
            name: profile.name,
            subtitle: profile.station,
            detail: displayPhone(profile.phone),
            imageUrl: profile.profileImageUrl),
        const SizedBox(height: MNSpace.x3),
        MNButton.secondary(s.changeProfilePhoto,
            busy: _photoBusy,
            onPressed: _photoBusy ? null : () => _changePhoto(profile)),
        if (_photoError != null) ...[
          const SizedBox(height: MNSpace.x2),
          MNNote(_photoError!, error: true),
        ],
        MNAccountSectionTitle(s.accountSettings),
        MNAccountGroup(children: [
          MNAccountRow(
              title: s.language,
              subtitle: s.accountLanguageCaption,
              value: s.languageName(s.code),
              icon: MNIconData.accountGlobe,
              onTap: () => showLanguageSheet(context, ref)),
          BiometricSetting(account: biometricAccount('vendor', profile.id)),
          MNAccountRow(
              title: s.changePin,
              icon: MNIconData.lock,
              onTap: () => context.push(MNRoutes.changePin)),
          MNAccountRow(
              title: s.handoversTitle,
              icon: MNIconData.cash,
              onTap: () => context.push(MNRoutes.handovers)),
          MNAccountRow(
              title: s.syncTitle,
              icon: MNIconData.sync,
              trailing: MNSyncIndicator(
                  status: ref.watch(syncStatusProvider),
                  compact: true,
                  pendingCount: ref.watch(syncOutstandingCountProvider)),
              onTap: () => context.push(MNRoutes.sync)),
          MNAccountRow(
              title: s.help,
              icon: MNIconData.help,
              onTap: () => showMNSheet<void>(context,
                  builder: (_) => MNSheet(title: s.help, children: [
                        for (final step in s.helpSteps)
                          Text(step, style: MNText.body),
                        MNButton.secondary(s.close,
                            onPressed: () => Navigator.of(context).pop()),
                      ]))),
        ]),
        const SizedBox(height: 32),
        MNAccountSignOut(
            warning: () {
              final unsent =
                  ref.read(queueCountsProvider).valueOrNull?.pending ?? 0;
              return unsent > 0 ? s.logoutUnsent(unsent) : null;
            },
            onSignOut: () => ref.read(sessionProvider.notifier).signOut()),
        const SizedBox(height: 24),
      ]),
    );
  }
}
