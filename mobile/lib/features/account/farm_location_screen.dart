import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/farm_location.dart';

/// The supplier's farm pin and pickup directions, changed from Account
/// without sending their whole registration back for review.
class FarmLocationScreen extends ConsumerWidget {
  const FarmLocationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.s;
    return Scaffold(
        appBar: OmoterraAppBar(title: Text(s.farmLocation)),
        body: ResourceView('/supplier/profile',
            builder: (profile) => profile == null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyState(s.registerSupplierFirst,
                        s.farmLocationPartOfRegistration))
                : _FarmLocationForm(Map<String, dynamic>.from(profile))));
  }
}

class _FarmLocationForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const _FarmLocationForm(this.profile);
  @override
  ConsumerState<_FarmLocationForm> createState() => _FarmLocationFormState();
}

class _FarmLocationFormState extends ConsumerState<_FarmLocationForm> {
  final _form = GlobalKey<FormState>();
  late final _pickup = TextEditingController(
      text: '${widget.profile['internal_pickup_address'] ?? ''}');
  late FarmLocation? farm = _saved();
  bool busy = false;
  Object? error;

  FarmLocation? _saved() {
    final lat = double.tryParse('${widget.profile['farm_latitude']}');
    final lng = double.tryParse('${widget.profile['farm_longitude']}');
    if (lat == null || lng == null) return null;
    final url = '${widget.profile['farm_map_url'] ?? ''}';
    return url.isEmpty || url == 'null'
        ? FarmLocation.pinned(FarmLocation(lat, lng, '').point)
        : FarmLocation(lat, lng, url);
  }

  @override
  void dispose() {
    _pickup.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (farm == null) {
      setState(() =>
          error = ApiFailure(ref.read(stringsProvider).addFarmLocationFull));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).write('/supplier/farm-location',
          {...farm!.toJson(), 'internal_pickup_address': _pickup.text.trim()},
          method: 'PUT');
      ref.invalidate(resourceProvider('/supplier/profile'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).farmLocationSaved)));
      context.canPop() ? context.pop() : context.go('/account');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.s;
    return Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(s.farmLocationIntro,
              style: const TextStyle(color: OColors.secondary, height: 1.4)),
          const SizedBox(height: 18),
          FarmLocationField(
              value: farm, onChanged: (v) => setState(() => farm = v)),
          const SizedBox(height: 16),
          TextFormField(
              key: const Key('farm_pickup'),
              controller: _pickup,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: s.pickupDirections,
                  hintText: s.pickupDirectionsHint),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? s.addDirections : null),
          const SizedBox(height: 10),
          Text(s.movingPinNote,
              style: const TextStyle(fontSize: 12.5, color: OColors.secondary)),
          const SizedBox(height: 20),
          if (error != null) ErrorState(error!),
          OmoterraButton(s.saveFarmLocation, busy: busy, onPressed: _save),
        ]));
  }
}
