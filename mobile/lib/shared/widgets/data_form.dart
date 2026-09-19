import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/repository.dart';
import 'components.dart';

class FormFieldSpec {
  final String key, title;
  final List<String>? options;
  final bool optional, numeric, multiline, date;
  final String initial;
  const FormFieldSpec(this.key, this.title,
      {this.options,
      this.optional = false,
      this.numeric = false,
      this.multiline = false,
      this.date = false,
      this.initial = ''});
}

class DataForm extends ConsumerStatefulWidget {
  final List<FormFieldSpec> fields;
  final String path, method, button;
  final String? reviewTitle, reviewCopy;
  final Map<String, dynamic> fixed;
  final Map<String, dynamic> Function(Map<String, dynamic>)? transform;
  final void Function(dynamic) onSuccess;
  const DataForm(
      {super.key,
      required this.fields,
      required this.path,
      required this.onSuccess,
      this.reviewTitle,
      this.reviewCopy,
      this.method = 'POST',
      this.button = 'Submit',
      this.fixed = const {},
      this.transform});
  @override
  ConsumerState<DataForm> createState() => _DataFormState();
}

class _DataFormState extends ConsumerState<DataForm> {
  final form = GlobalKey<FormState>();
  final key = newKey();
  final Map<String, TextEditingController> controllers = {};
  final Map<String, String> selections = {};
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      controllers[field.key] = TextEditingController(text: field.initial);
      if (field.options != null) {
        selections[field.key] =
            field.initial.isNotEmpty ? field.initial : field.options!.first;
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (widget.reviewTitle != null) {
      final approved = await omoterraSheet<bool>(
          context,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.reviewTitle!,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(widget.reviewCopy ?? ''),
            const SizedBox(height: 16),
            MoneySummary({
              for (final f in widget.fields)
                if (controllers[f.key]!.text.isNotEmpty)
                  f.title: controllers[f.key]!.text
            }),
            const SizedBox(height: 24),
            OmoterraButton(widget.button,
                onPressed: () => Navigator.pop(context, true)),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go back'))
          ]));
      if (approved != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      var data = <String, dynamic>{
        ...widget.fixed,
        for (final f in widget.fields)
          f.key: f.options != null
              ? selections[f.key]
              : controllers[f.key]!.text.trim()
      };
      data = widget.transform?.call(data) ?? data;
      final response = await ref
          .read(repositoryProvider)
          .write(widget.path, data, method: widget.method, key: key);
      if (mounted) widget.onSuccess(response);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final field in widget.fields)
          if (field.options != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                    initialValue: selections[field.key],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: field.title),
                    items: field.options!
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text(label(v))))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => selections[field.key] = v!)))
          else if (field.date || field.key.endsWith('_date'))
            OmoterraDateField(field.title, controllers[field.key]!,
                pastAllowed: field.key == 'sold_on')
          else
            OmoterraTextField(
                field.key == 'quantity' && selections.containsKey('category')
                    ? '${field.title} (${unitFor(selections['category']!)})'
                    : field.title,
                controllers[field.key]!,
                keyboard: field.numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                lines: field.multiline ? 3 : 1,
                requiredField: !field.optional),
        if (error != null) ErrorState(error!),
        OmoterraButton(widget.button, busy: busy, onPressed: submit)
      ]));
}
