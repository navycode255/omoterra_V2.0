import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/repository.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/components.dart';
import '../../shared/widgets/data_form.dart';

class SupplierBatchScreen extends ConsumerWidget {
  const SupplierBatchScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar:
            const OmoterraAppBar(title: Text('Register a production batch')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Record future supply',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
              'Growing batches can be offered for upcoming buyer demand. Registration does not publish them for immediate purchase.'),
          const SizedBox(height: 24),
          ResourceView('/supplier/profile', builder: (profile) {
            if (profile == null) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Save your private pickup details before registering a batch.'),
                    const SizedBox(height: 16),
                    DataForm(
                        path: '/supplier/profile',
                        method: 'PUT',
                        fields: const [
                          FormFieldSpec('legal_name', 'Legal name'),
                          FormFieldSpec('internal_pickup_address',
                              'Private pickup address',
                              multiline: true),
                        ],
                        button: 'Save supplier details',
                        onSuccess: (_) => ref
                            .invalidate(resourceProvider('/supplier/profile'))),
                  ]);
            }
            final tomorrow = DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String()
                .split('T')
                .first;
            return DataForm(
                path: '/supplier/batches',
                fields: [
                  const FormFieldSpec('category', 'Product',
                      options: categories),
                  const FormFieldSpec('subtype', 'Breed / subtype',
                      optional: true),
                  const FormFieldSpec('initial_quantity', 'Batch quantity',
                      numeric: true),
                  const FormFieldSpec('current_age', 'Current age',
                      numeric: true, optional: true),
                  const FormFieldSpec('age_unit', 'Age unit',
                      options: ['days', 'weeks', 'months']),
                  FormFieldSpec('expected_ready_date', 'Expected ready date',
                      initial: tomorrow),
                  const FormFieldSpec(
                      'expected_min_weight_kg', 'Expected minimum weight (kg)',
                      numeric: true, optional: true),
                  const FormFieldSpec(
                      'expected_max_weight_kg', 'Expected maximum weight (kg)',
                      numeric: true, optional: true),
                  const FormFieldSpec('form', 'Form',
                      options: ['live', 'dressed', 'chilled', 'frozen']),
                  const FormFieldSpec(
                      'asking_price_per_unit', 'Asking price per unit (TZS)',
                      numeric: true, optional: true),
                  const FormFieldSpec('region', 'General region'),
                  const FormFieldSpec(
                      'private_pickup_location', 'Private pickup location',
                      optional: true, multiline: true),
                ],
                button: 'Submit batch for review',
                onSuccess: (row) {
                  ref.invalidate(resourceProvider('/supplier/batches'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Batch registered for Omoterra review.')));
                  context.go('/stock');
                });
          }),
        ]),
      );
}

String _batchUnit(Map<String, dynamic> row) {
  final category = row['category'];
  if (category == 'broilers' || category == 'local_chicken') return 'birds';
  if (category == 'eggs') return 'trays';
  if (category == 'goats' || category == 'cattle') return 'animals';
  return 'kg';
}

String _batchDate(Object? value) {
  final date = DateTime.tryParse('$value');
  return date == null
      ? 'Date to be confirmed'
      : DateFormat('d MMM yyyy').format(date);
}

class SupplierBatchList extends ConsumerWidget {
  const SupplierBatchList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ResourceView('/supplier/batches', builder: (data) {
        final batches = (data as List)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        if (batches.isEmpty) {
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No production batches registered.',
                  style: TextStyle(color: OColors.secondary)));
        }
        final groups = <String, List<Map<String, dynamic>>>{
          'Growing': batches.where((r) => r['status'] == 'growing').toList(),
          'Ready': batches.where((r) => r['status'] == 'ready').toList(),
          'Reserved': batches
              .where((r) => ['partially_reserved', 'fully_reserved']
                  .contains(r['status']))
              .toList(),
          'Completed':
              batches.where((r) => r['status'] == 'completed').toList(),
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty) ...[
              SectionHeader(entry.key),
              for (final row in entry.value)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: OColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(label('${row['category']}'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700))),
                          Text(
                              '${amount(row['current_quantity'])} ${label(_batchUnit(row))}'),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                            'Age ${row['current_age'] ?? '—'} ${row['age_unit']} · Ready ${_batchDate(row['expected_ready_date'])}',
                            style: const TextStyle(
                                color: OColors.secondary, fontSize: 13)),
                        Text(
                            'Expected weight ${row['expected_min_weight_kg'] ?? '—'}–${row['expected_max_weight_kg'] ?? '—'} kg',
                            style: const TextStyle(
                                color: OColors.secondary, fontSize: 13)),
                        Text(
                            '${amount(row['reserved_quantity'])} reserved · ${amount(row['available_to_commit'])} available to commit',
                            style: const TextStyle(fontSize: 13)),
                        Text(
                            '${amount(row['externally_sold_quantity'])} externally sold',
                            style: const TextStyle(
                                color: OColors.secondary, fontSize: 12)),
                        if ((num.tryParse('${row['available_to_commit']}') ??
                                0) >
                            0)
                          Material(
                            color: Colors.transparent,
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Record external sale'),
                              children: [
                                DataForm(
                                  path:
                                      '/supplier/batches/${row['id']}/external-sales',
                                  fields: const [
                                    FormFieldSpec('quantity',
                                        'Quantity sold outside Omoterra',
                                        numeric: true),
                                    FormFieldSpec('notes', 'Note (optional)',
                                        optional: true),
                                  ],
                                  button: 'Confirm external sale',
                                  onSuccess: (_) => ref.invalidate(
                                      resourceProvider('/supplier/batches')),
                                ),
                              ],
                            ),
                          ),
                        if (row['approved_at'] == null)
                          const Text('Awaiting Omoterra review',
                              style: TextStyle(
                                  color: OColors.secondary, fontSize: 12)),
                      ]),
                ),
            ],
        ]);
      });
}
