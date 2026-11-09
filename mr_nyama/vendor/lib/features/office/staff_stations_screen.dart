import 'owner_reference.dart';
import 'owner_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/note.dart';
import '../../shared/widgets/states.dart';
import 'people_screens.dart';

final staffPlacementDataProvider = FutureProvider.autoDispose((ref) async {
  final office = ref.read(officeSessionProvider.notifier);
  final staff = await office.guard((r) => r.staff());
  final stations = await office.guard((r) => r.stations());
  return (staff, stations);
});

class StaffStationsScreen extends ConsumerWidget {
  final String staffId;
  const StaffStationsScreen({super.key, required this.staffId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return OwnerPage(
        title: s.workStations,
        strings: s,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: OwnerAsyncView(
                value: ref.watch(staffPlacementDataProvider),
                onRetry: () => ref.invalidate(staffPlacementDataProvider),
                data: (data) {
                  final person =
                      data.$1.where((p) => p.id == staffId).firstOrNull;
                  if (person == null) {
                    return MNEmptyState(
                        icon: MNIconData.user, title: s.noStaff);
                  }
                  return _Placements(person: person, stations: data.$2);
                })));
  }
}

class _Placements extends ConsumerStatefulWidget {
  final OfficeStaff person;
  final List<OfficeStation> stations;
  const _Placements({required this.person, required this.stations});
  @override
  ConsumerState<_Placements> createState() => _PlacementsState();
}

class _PlacementsState extends ConsumerState<_Placements> {
  late final _selected = widget.person.stationIds.toSet();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    if (_reason.text.trim().length < 3) {
      setState(() => _error = s.detailsInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(officeSessionProvider.notifier).guard((r) => r.placeStaff(
          widget.person.id,
          stationIds: _selected.toList(),
          reason: _reason.text.trim()));
      ref.invalidate(officeStaffProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.changesSaved)));
        context.pop();
      }
    } catch (_) {
      if (mounted) setState(() => _error = s.assignmentFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return OwnerFormSection(children: [
      Text(widget.person.name, style: MNText.resolve(context, MNText.heading)),
      const SizedBox(height: 8),
      OwnerHelp(message: s.workStationsHelp),
      const SizedBox(height: 16),
      if (widget.stations.isEmpty) MNNote(s.noStations),
      for (final station in widget.stations)
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(station.name),
            subtitle: Text(station.code),
            value: _selected.contains(station.id),
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      if (v == true) {
                        _selected.add(station.id);
                      } else {
                        _selected.remove(station.id);
                      }
                    })),
      const SizedBox(height: 16),
      MNTextField(label: s.changeReason, controller: _reason, enabled: !_busy),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: MNNote(_error!, error: true)),
      const SizedBox(height: 16),
      MNButton(s.saveChanges, busy: _busy, onPressed: _busy ? null : _save),
    ]);
  }
}
