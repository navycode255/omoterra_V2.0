import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart';
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/date_sheet.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/icon.dart';
import '../../shared/widgets/radio_mark.dart';
import '../../shared/widgets/sheet.dart';
import 'people_screens.dart';

enum VendorPayFormKind { contract, attendance, payment, reversal }

Future<bool?> showVendorPayForm(BuildContext context,
        {required String vendor,
        required VendorPayFormKind kind,
        required DateTime from,
        required DateTime to,
        Map<String, dynamic>? attendance,
        String? paymentId}) =>
    showMNSheet<bool>(context,
        builder: (_) => _PayForm(
            vendor: vendor,
            kind: kind,
            from: from,
            to: to,
            attendance: attendance,
            paymentId: paymentId));

class _PayForm extends ConsumerStatefulWidget {
  final String vendor;
  final VendorPayFormKind kind;
  final DateTime from, to;
  final Map<String, dynamic>? attendance;
  final String? paymentId;
  const _PayForm(
      {required this.vendor,
      required this.kind,
      required this.from,
      required this.to,
      this.attendance,
      this.paymentId});
  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  final _id = const Uuid().v4();
  final _rate = TextEditingController(),
      _commission = TextEditingController(),
      _reference = TextEditingController(),
      _terms = TextEditingController(),
      _amount = TextEditingController(),
      _note = TextEditingController(),
      _reason = TextEditingController();
  late DateTime _day = widget.attendance == null
      ? businessDate(ref.read(clockProvider)())
      : DateTime.parse(widget.attendance!['business_date'] as String);
  late DateTime _from = widget.from, _to = widget.to;
  late DateTime _paidAt = ref.read(clockProvider)();
  String? _frequency, _station, _method, _error;
  int? _weekday, _monthday;
  bool? _present;
  bool _busy = false;
  Map<String, dynamic>? _attempt;
  bool get locked => _busy || _attempt != null;
  @override
  void initState() {
    super.initState();
    _station = widget.attendance?['station_id'] as String?;
    _present = widget.attendance?['present'] as bool?;
    if (widget.kind == VendorPayFormKind.contract) {
      _reference.text = 'CT-${_id.substring(0, 8).toUpperCase()}';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _rate,
      _commission,
      _reference,
      _terms,
      _amount,
      _note,
      _reason,
      _monthdayController
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _bps(String value) {
    final match =
        RegExp(r'^(\d{1,3})(?:[.,](\d{1,2}))?$').firstMatch(value.trim());
    if (match == null) return null;
    final n = int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '').padRight(2, '0'));
    return n <= 10000 ? n : null;
  }

  Future<void> save() async {
    if (_busy) return;
    final s = ref.read(stringsProvider);
    final kind = widget.kind;
    String command;
    try {
      if (_attempt == null) {
        final body = <String, dynamic>{'client_id': _id};
        switch (kind) {
          case VendorPayFormKind.contract:
            final rate = int.tryParse(_rate.text), bps = _bps(_commission.text);
            if (rate == null ||
                rate < 0 ||
                rate > 100000000 ||
                bps == null ||
                (rate == 0 && bps == 0) ||
                _frequency == null ||
                (_frequency == 'weekly' && _weekday == null) ||
                (_frequency == 'monthly' &&
                    (_monthday == null || _monthday! < 1 || _monthday! > 31)) ||
                _reference.text.trim().length < 2 ||
                _terms.text.trim().length < 3) {
              throw const FormatException();
            }
            body.addAll({
              'effective_from': moneyDateKey(_day),
              'daily_rate': rate,
              'commission_bps': bps,
              'frequency': _frequency,
              'pay_weekday': _frequency == 'weekly' ? _weekday : null,
              'pay_monthday': _frequency == 'monthly' ? _monthday : null,
              'reference': _reference.text.trim(),
              'terms': _terms.text.trim()
            });
          case VendorPayFormKind.attendance:
            if (_station == null ||
                _present == null ||
                (widget.attendance != null && _reason.text.trim().length < 3)) {
              throw const FormatException();
            }
            body.addAll({
              'business_date': moneyDateKey(_day),
              'station_id': _station,
              'present': _present,
              'replaces_id': widget.attendance?['id'],
              'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
              'reason': widget.attendance == null ? null : _reason.text.trim()
            });
          case VendorPayFormKind.payment:
            final amount = int.tryParse(_amount.text);
            if (amount == null ||
                amount <= 0 ||
                amount > 100000000 ||
                _method == null ||
                _reference.text.trim().length < 2 ||
                _to.isBefore(_from)) {
              throw const FormatException();
            }
            body.addAll({
              'amount': amount,
              'method': _method,
              'reference': _reference.text.trim(),
              'period_from': moneyDateKey(_from),
              'period_to': moneyDateKey(_to),
              'paid_at': _paidAt.toUtc().toIso8601String()
            });
          case VendorPayFormKind.reversal:
            if (_reason.text.trim().length < 3) throw const FormatException();
            body['reason'] = _reason.text.trim();
        }
        _attempt = body;
      }
      command = switch (kind) {
        VendorPayFormKind.contract => 'contracts',
        VendorPayFormKind.attendance => 'attendance',
        VendorPayFormKind.payment => 'payments',
        VendorPayFormKind.reversal =>
          'payments/${Uri.encodeComponent(widget.paymentId!)}/reverse'
      };
      setState(() {
        _busy = true;
        _error = null;
      });
      await ref.read(officeSessionProvider.notifier).guard((repo) {
        if (repo is! OfficeVendorPayRepository) {
          throw const OfficeError(OfficeErrorKind.notFound);
        }
        return (repo as OfficeVendorPayRepository)
            .vendorPayCommand(widget.vendor, command, _attempt!);
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is FormatException) {
            _attempt = null;
            _error = s.detailsInvalid;
          } else if (e is OfficeError &&
              (e.kind == OfficeErrorKind.invalid ||
                  e.kind == OfficeErrorKind.refused)) {
            _attempt = null;
            _error = s.paySaveRefused;
          } else {
            _error = s.payRetrySame;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DateTime?> pickDate(DateTime initial,
          {bool future = false, String? title}) =>
      showMNDateSheet(context,
          title: title,
          titleStyle: OwnerStyle.text(context, 22, weight: 700),
          initial: initial,
          first: DateTime.utc(2020),
          last: businessDate(ref.read(clockProvider)())
              .add(Duration(days: future ? 3650 : 0)));

  Widget dayField(String label, DateTime value, ValueChanged<DateTime> changed,
          {bool enabled = true, bool future = false}) =>
      PayChoiceField(
          label: label,
          text: ref.read(stringsProvider).date(value),
          onTap: locked || !enabled
              ? null
              : () async {
                  final day =
                      await pickDate(value, future: future, title: label);
                  if (day != null && mounted) {
                    changed(DateTime.utc(day.year, day.month, day.day));
                  }
                });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider), kind = widget.kind;
    final title = switch (kind) {
      VendorPayFormKind.contract => s.paySetContract,
      VendorPayFormKind.attendance => s.payRecordAttendance,
      VendorPayFormKind.payment => s.payRecordPayment,
      VendorPayFormKind.reversal => s.payReverse
    };
    Widget input(String label, TextEditingController c,
            {bool number = false,
            int max = 150,
            int lines = 1,
            bool decimal = false}) =>
        PayTextField(
            label: label,
            controller: c,
            enabled: !locked,
            number: number,
            decimal: decimal,
            max: max,
            lines: lines);
    final stations = kind == VendorPayFormKind.attendance
        ? ref.watch(officeStationsProvider)
        : null;
    return MNSheet(
        title: title,
        titleStyle: OwnerStyle.text(context, 22, weight: 700),
        children: [
          if (kind == VendorPayFormKind.contract) ...[
            dayField(s.payEffectiveFrom, _day, (v) => setState(() => _day = v),
                future: true),
            input(s.payDailyRate, _rate, number: true, max: 9),
            input(s.payCommissionPercent, _commission,
                number: true, decimal: true, max: 6),
            PayChoiceField(
                label: s.payFrequency,
                text: _frequency == null
                    ? s.selectPlaceholder
                    : switch (_frequency) {
                        'daily' => s.payDaily,
                        'weekly' => s.payWeekly,
                        _ => s.payMonthly
                      },
                onTap: locked
                    ? null
                    : () async {
                        final v = await payPick(
                            context,
                            s.payFrequency,
                            {
                              'daily': s.payDaily,
                              'weekly': s.payWeekly,
                              'monthly': s.payMonthly
                            },
                            _frequency);
                        if (v != null && mounted) {
                          setState(() => _frequency = v);
                        }
                      }),
            if (_frequency == 'weekly')
              PayChoiceField(
                  label: s.payWeekday,
                  text: _weekday == null
                      ? s.selectPlaceholder
                      : s.payWeekdayName(_weekday!),
                  onTap: locked
                      ? null
                      : () async {
                          final v = await payPick(
                              context,
                              s.payWeekday,
                              {
                                for (var i = 0; i < 7; i++)
                                  '$i': s.payWeekdayName(i)
                              },
                              _weekday?.toString());
                          if (v != null && mounted) {
                            setState(() => _weekday = int.parse(v));
                          }
                        }),
            if (_frequency == 'monthly')
              input(s.payMonthday, _monthdayController, number: true, max: 2),
            input(s.reference, _reference),
            input(s.payAgreedTerms, _terms, max: 1000, lines: 4),
          ],
          if (kind == VendorPayFormKind.attendance) ...[
            dayField(s.dateLabel, _day, (v) => setState(() => _day = v),
                enabled: widget.attendance == null),
            if (stations?.hasError == true)
              Text(s.payLoadFailed,
                  style: OwnerStyle.text(context, 14, color: MNColors.error)),
            PayChoiceField(
                label: s.stationName,
                text: stations?.valueOrNull
                        ?.where((r) => r.id == _station)
                        .firstOrNull
                        ?.name ??
                    s.selectPlaceholder,
                onTap: locked || stations?.hasValue != true
                    ? null
                    : () async {
                        final v = await payPick(
                            context,
                            s.stationName,
                            {
                              for (final station in stations!.value!)
                                station.id: station.name
                            },
                            _station);
                        if (v != null && mounted) setState(() => _station = v);
                      }),
            PayChoiceField(
                label: s.payAttendance,
                text: _present == null
                    ? s.selectPlaceholder
                    : _present!
                        ? s.payPresent
                        : s.payAbsent,
                onTap: locked
                    ? null
                    : () async {
                        final v = await payPick(
                            context,
                            s.payAttendance,
                            {'yes': s.payPresent, 'no': s.payAbsent},
                            _present == null
                                ? null
                                : _present!
                                    ? 'yes'
                                    : 'no');
                        if (v != null && mounted) {
                          setState(() => _present = v == 'yes');
                        }
                      }),
            input(s.noteOptional, _note, max: 300, lines: 2),
            if (widget.attendance != null)
              input(s.changeReason, _reason, max: 500, lines: 2),
          ],
          if (kind == VendorPayFormKind.payment) ...[
            Text(s.payActualPaymentHelp,
                style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
            dayField(s.payPeriodFrom, _from, (v) => setState(() => _from = v)),
            dayField(s.payPeriodTo, _to, (v) => setState(() => _to = v)),
            input(s.moneyAmount, _amount, number: true, max: 9),
            PayChoiceField(
                label: s.payMethod,
                text: _method == null
                    ? s.selectPlaceholder
                    : switch (_method) {
                        'cash' => s.cash,
                        'mpesa' => s.mpesaShort,
                        _ => s.payOtherMethod
                      },
                onTap: locked
                    ? null
                    : () async {
                        final v = await payPick(
                            context,
                            s.payMethod,
                            {
                              'cash': s.cash,
                              'mpesa': s.mpesaShort,
                              'other': s.payOtherMethod
                            },
                            _method);
                        if (v != null && mounted) setState(() => _method = v);
                      }),
            input(s.reference, _reference),
            PayChoiceField(
                label: s.payPaidAt,
                text:
                    '${s.date(businessDate(_paidAt))} · ${s.hhmm(eatClock(_paidAt))}',
                onTap: locked
                    ? null
                    : () async {
                        final d = await pickDate(businessDate(_paidAt),
                            title: s.payPaidAt);
                        if (d == null || !context.mounted) return;
                        final time = await showMNTimeSheet(context,
                            title: s.payPaidAt,
                            titleStyle:
                                OwnerStyle.text(context, 22, weight: 700),
                            hour: eatClock(_paidAt).hour,
                            minute: eatClock(_paidAt).minute);
                        if (time != null && mounted) {
                          setState(() => _paidAt = businessDayRange(d).$1.add(
                              Duration(
                                  hours: time.hour, minutes: time.minute)));
                        }
                      }),
          ],
          if (kind == VendorPayFormKind.reversal) ...[
            Text(s.payReversalHelp,
                style: OwnerStyle.text(context, 14, color: OwnerStyle.muted)),
            input(s.changeReason, _reason, max: 500, lines: 3),
          ],
          if (_error != null)
            Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style:
                        OwnerStyle.text(context, 14, color: MNColors.error))),
          PayAction(
              label: _attempt == null ? s.saveWorkflow : s.retry,
              busy: _busy,
              onTap: _busy
                  ? null
                  : () {
                      if (_frequency == 'monthly') {
                        _monthday = int.tryParse(_monthdayController.text);
                      }
                      save();
                    }),
        ]);
  }

  final _monthdayController = TextEditingController();
}

class PayTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled, number, decimal;
  final int max, lines;
  const PayTextField(
      {super.key,
      required this.label,
      required this.controller,
      this.enabled = true,
      this.number = false,
      this.decimal = false,
      this.max = 150,
      this.lines = 1});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
        const SizedBox(height: 6),
        TextField(
            controller: controller,
            enabled: enabled,
            maxLines: lines,
            style: OwnerStyle.text(context, 16),
            keyboardType: number
                ? TextInputType.numberWithOptions(decimal: decimal)
                : TextInputType.text,
            inputFormatters: [
              if (number)
                decimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    : FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(max)
            ],
            decoration: InputDecoration(
                filled: true,
                fillColor: enabled ? OwnerStyle.white : MNColors.disabled,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: MNColors.borderStrong, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: OwnerStyle.ink, width: 2)),
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: MNColors.borderStrong, width: 1.5)))),
      ]);
}

class PayChoiceField extends StatelessWidget {
  final String label, text;
  final VoidCallback? onTap;
  const PayChoiceField(
      {super.key,
      required this.label,
      required this.text,
      required this.onTap});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: OwnerStyle.text(context, 13, color: OwnerStyle.muted)),
        const SizedBox(height: 6),
        MNPressable(
            onTap: onTap,
            color: onTap == null ? MNColors.disabled : OwnerStyle.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MNColors.borderStrong, width: 1.5),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(
                          child:
                              Text(text, style: OwnerStyle.text(context, 16))),
                      const SizedBox(width: 8),
                      const MNIcon(MNIconData.down,
                          size: 22, color: OwnerStyle.muted),
                    ])))),
      ]);
}

Future<String?> payPick(BuildContext context, String title,
    Map<String, String> options, String? selected) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showMNSheet<String>(context,
      builder: (sheet) => MNSheet(
              title: title,
              titleStyle: OwnerStyle.text(sheet, 22, weight: 700),
              children: [
                for (final e in options.entries)
                  MNPressable(
                      onTap: () => Navigator.pop(sheet, e.key),
                      selected: e.key == selected,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Expanded(
                                    child: Text(e.value,
                                        style: OwnerStyle.text(sheet, 16))),
                                const SizedBox(width: 12),
                                MNRadioMark(selected: e.key == selected),
                              ])))),
              ]));
}

class PayAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool secondary;
  const PayAction(
      {super.key,
      required this.label,
      required this.onTap,
      this.busy = false,
      this.secondary = false});
  @override
  Widget build(BuildContext context) => MNPressable(
      onTap: onTap,
      color: onTap == null
          ? MNColors.disabled
          : secondary
              ? OwnerStyle.white
              : OwnerStyle.red,
      border: secondary ? Border.all(color: OwnerStyle.ink) : null,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: busy
                  ? const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: OwnerStyle.white, strokeWidth: 2)))
                  : Text(label,
                      textAlign: TextAlign.center,
                      style: OwnerStyle.text(context, 16,
                          weight: 700,
                          color: onTap == null
                              ? MNColors.disabledText
                              : OwnerStyle.white)))));
}
