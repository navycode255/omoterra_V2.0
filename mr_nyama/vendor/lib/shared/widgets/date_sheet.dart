import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'filter_sheet.dart';
import 'icon.dart';
import 'number_sheet.dart';
import 'pressable.dart';
import 'quantity.dart';
import 'sheet.dart';

/// The app's one date sheet (never the platform date picker): month header
/// with previous / next, Monday-first weekday initials, a day grid with
/// today ringed and the choice in brand red, days outside [first]..[last]
/// disabled, "Leo" / "Jana" chips when they are in range, and a confirm
/// button. Dates are date-only UTC midnight values, like `businessDate()`;
/// the result is one too. Returns null when dismissed. [titleStyle] lets a
/// caller whose sheets use another heading style (office forms) keep it.
Future<DateTime?> showMNDateSheet(BuildContext context,
    {required DateTime initial,
    required DateTime first,
    required DateTime last,
    String? title,
    TextStyle? titleStyle}) {
  final lo = _dateOnly(first), hi = _dateOnly(last);
  assert(!hi.isBefore(lo), 'last must not be before first');
  return showMNSheet<DateTime>(context,
      builder: (_) => _DateSheet(
          first: lo,
          last: hi,
          start: _clamp(_dateOnly(initial), lo, hi),
          end: null,
          range: false,
          title: title,
          titleStyle: titleStyle));
}

/// The same sheet choosing a period: the first tap is the first day, the
/// second the last. Returns `(from, to)` as UTC dates (`to` equals `from`
/// for a single day), or null when dismissed.
Future<(DateTime, DateTime)?> showMNDateRangeSheet(BuildContext context,
    {required DateTime start,
    required DateTime end,
    required DateTime first,
    required DateTime last,
    String? title,
    TextStyle? titleStyle}) async {
  final lo = _dateOnly(first), hi = _dateOnly(last);
  assert(!hi.isBefore(lo), 'last must not be before first');
  final from = _clamp(_dateOnly(start), lo, hi);
  var to = _clamp(_dateOnly(end), lo, hi);
  if (to.isBefore(from)) to = from;
  final picked = await showMNSheet<List<DateTime>>(context,
      builder: (_) => _DateSheet(
          first: lo,
          last: hi,
          start: from,
          end: to,
          range: true,
          title: title,
          titleStyle: titleStyle));
  return picked == null ? null : (picked[0], picked[1]);
}

/// "Tarehe maalum" from the filter reference (28 October 2026): one wheel
/// of days, each row reading weekday, day, month and year, the centre row
/// bold on a grey band. Used by the filter sheets; forms keep the calendar
/// of [showMNDateSheet]. Same date-only UTC values; null when dismissed.
Future<DateTime?> showMNDateWheelSheet(BuildContext context,
    {required DateTime initial,
    required DateTime first,
    required DateTime last,
    String? title}) {
  final lo = _dateOnly(first), hi = _dateOnly(last);
  assert(!hi.isBefore(lo), 'last must not be before first');
  return showMNSheet<DateTime>(context,
      builder: (_) => _DateWheelSheet(
          first: lo,
          last: hi,
          initial: _clamp(_dateOnly(initial), lo, hi),
          title: title));
}

/// Asks for a 24-hour time (HH:MM) with two steppers; tapping the hours or
/// minutes types them on the keypad. Returns null when dismissed.
Future<({int hour, int minute})?> showMNTimeSheet(BuildContext context,
        {required int hour,
        required int minute,
        String? title,
        TextStyle? titleStyle}) =>
    showMNSheet<({int hour, int minute})>(context,
        builder: (_) => _TimeSheet(
            hour: hour.clamp(0, 23),
            minute: minute.clamp(0, 59),
            title: title,
            titleStyle: titleStyle));

DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime _clamp(DateTime d, DateTime lo, DateTime hi) =>
    d.isBefore(lo) ? lo : (d.isAfter(hi) ? hi : d);

DateTime _monthOf(DateTime d) => DateTime.utc(d.year, d.month);

class _DateSheet extends ConsumerStatefulWidget {
  final DateTime first;
  final DateTime last;
  final DateTime start;
  final DateTime? end;
  final bool range;
  final String? title;
  final TextStyle? titleStyle;
  const _DateSheet(
      {required this.first,
      required this.last,
      required this.start,
      required this.end,
      required this.range,
      required this.title,
      required this.titleStyle});

  @override
  ConsumerState<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends ConsumerState<_DateSheet> {
  late DateTime? _start = widget.start;
  late DateTime? _end = widget.end;
  late DateTime _month = _monthOf(widget.start);
  late final DateTime _today = businessDate(ref.read(clockProvider)());

  bool _inRange(DateTime d) =>
      !d.isBefore(widget.first) && !d.isAfter(widget.last);

  bool get _canPrev => _month.isAfter(_monthOf(widget.first));
  bool get _canNext => _month.isBefore(_monthOf(widget.last));

  void _shift(int months) =>
      setState(() => _month = DateTime.utc(_month.year, _month.month + months));

  void _tap(DateTime d) => setState(() {
        if (!widget.range) {
          _start = d;
        } else if (_start == null || _end != null || d.isBefore(_start!)) {
          _start = d;
          _end = null;
        } else {
          _end = d;
        }
        _month = _monthOf(d);
      });

  void _confirm() {
    if (_start == null) return;
    Navigator.of(context)
        .pop(widget.range ? [_start!, _end ?? _start!] : _start);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final yesterday = _today.subtract(const Duration(days: 1));
    final chips = widget.range
        ? const <(String, DateTime)>[]
        : [
            if (_inRange(_today)) (s.todayLabel, _today),
            if (_inRange(yesterday)) (s.yesterdayLabel, yesterday),
          ];
    return MNSheet(
        title: widget.title ??
            (widget.range ? s.chooseDateRange : s.moneyChooseDate),
        titleStyle: widget.titleStyle,
        children: [
          if (chips.isNotEmpty)
            Wrap(spacing: MNSpace.x2, runSpacing: MNSpace.x2, children: [
              for (final (label, day) in chips)
                _Chip(
                    label: label,
                    selected: _start == day,
                    onTap: () => _tap(day)),
            ]),
          if (widget.range)
            Semantics(
                liveRegion: true,
                child: Text(
                    _start == null
                        ? s.dateRangeHint
                        : s.stockRange(
                            s.date(_start!), s.date(_end ?? _start!)),
                    style: MNText.resolve(context, MNText.secondary))),
          Row(children: [
            _NavButton(
                label: s.previousMonth,
                flip: true,
                onTap: _canPrev ? () => _shift(-1) : null),
            Expanded(
                child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(s.monthYear(_month),
                        textAlign: TextAlign.center,
                        style: MNText.resolve(context, MNText.title)))),
            _NavButton(
                label: s.nextMonth,
                flip: false,
                onTap: _canNext ? () => _shift(1) : null),
          ]),
          AnimatedSwitcher(
              duration: MNMotion.of(context, MNMotion.small),
              switchInCurve: MNMotion.easeOut,
              switchOutCurve: MNMotion.easeIn,
              layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current]),
              child: KeyedSubtree(
                  key: ValueKey(_month), child: _grid(context, s))),
          MNButton(widget.range ? s.useThisPeriod : s.useThisDate,
              onPressed: _start == null ? null : _confirm),
        ]);
  }

  Widget _grid(BuildContext context, Strings s) {
    final lead = _month.weekday - 1;
    final days = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ExcludeSemantics(
        child: Row(children: [
          for (final w in s.weekdayInitials)
            Expanded(
                child: SizedBox(
                    height: MNSpace.x6,
                    child: Center(
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(w,
                                style:
                                    MNText.resolve(context, MNText.meta)))))),
        ]),
      ),
      const SizedBox(height: MNSpace.x1),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(child: _cell(s, r * 7 + c - lead + 1, days)),
        ]),
    ]);
  }

  Widget _cell(Strings s, int n, int days) {
    if (n < 1 || n > days) return const SizedBox(height: MNSize.minTouch);
    final d = DateTime.utc(_month.year, _month.month, n);
    final enabled = _inRange(d);
    final isToday = d == _today;
    final edge = d == _start || (widget.range && d == _end);
    final between = widget.range &&
        _start != null &&
        _end != null &&
        d.isAfter(_start!) &&
        d.isBefore(_end!);
    final color = edge
        ? MNColors.white
        : enabled
            ? MNColors.ink
            : MNColors.disabledText;
    return MNPressable(
      key: ValueKey('mn-date-${d.year}-${d.month}-${d.day}'),
      onTap: enabled ? () => _tap(d) : null,
      pressedScale: MNMotion.pressChip,
      selected: edge || between,
      semanticLabel: isToday ? '${s.date(d)}, ${s.todayLabel}' : s.date(d),
      child: SizedBox(
        height: MNSize.minTouch,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 42, maxHeight: 42),
            child: AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: MNMotion.of(context, MNMotion.instant),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: edge
                        ? MNColors.red
                        : between
                            ? MNColors.roseSurface
                            : null,
                    border: isToday && !edge
                        ? Border.all(
                            color: enabled ? MNColors.ink : MNColors.border,
                            width: MNSize.borderWidth)
                        : null),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(2),
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$n',
                        style: MNText.withWeight(
                                MNText.resolve(context, MNText.body),
                                edge || isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500)
                            .copyWith(color: color)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Previous / next month: a 48 px round button with the line chevron.
class _NavButton extends StatelessWidget {
  final String label;
  final bool flip;
  final VoidCallback? onTap;
  const _NavButton(
      {required this.label, required this.flip, required this.onTap});

  @override
  Widget build(BuildContext context) => MNPressable(
        onTap: onTap,
        pressedScale: MNMotion.pressChip,
        color: MNColors.white,
        pressedColor: MNColors.surface,
        borderRadius: BorderRadius.circular(MNSize.iconButton / 2),
        semanticLabel: label,
        child: SizedBox.square(
          dimension: MNSize.iconButton,
          child: Center(
            child: Transform.flip(
              flipX: flip,
              child: MNIcon(MNIconData.chevron,
                  color: onTap == null ? MNColors.disabledText : MNColors.ink),
            ),
          ),
        ),
      );
}

/// A quick-choice chip in the `.chip` style: black when selected.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => MNPressable(
        onTap: onTap,
        pressedScale: MNMotion.pressChip,
        color: selected ? MNColors.black : MNColors.surface,
        borderRadius: BorderRadius.circular(MNRadius.small),
        semanticLabel: label,
        selected: selected,
        child: Container(
          constraints: const BoxConstraints(
              minHeight: MNSize.minTouch, minWidth: MNSize.minTouch),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
          child: ExcludeSemantics(
            child: Text(label,
                style: MNText.resolve(context, MNText.chip)
                    .copyWith(color: selected ? MNColors.white : MNColors.ink)),
          ),
        ),
      );
}

class _TimeSheet extends ConsumerStatefulWidget {
  final int hour;
  final int minute;
  final String? title;
  final TextStyle? titleStyle;
  const _TimeSheet(
      {required this.hour,
      required this.minute,
      required this.title,
      required this.titleStyle});

  @override
  ConsumerState<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends ConsumerState<_TimeSheet> {
  late int _hour = widget.hour;
  late int _minute = widget.minute;

  static String _two(int v) => v.toString().padLeft(2, '0');

  Future<void> _type(
      String title, int current, int max, ValueChanged<int> set) async {
    final v = await showNumberSheet(context,
        title: title, initial: current, max: max);
    if (v != null && mounted) setState(() => set(math.min(v, max)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // One row per part: label, − value +. Tapping the value types it on
    // the keypad, so a far minute is not 59 taps away.
    Widget part(String label, int value, int max, ValueChanged<int> set) {
      void step(int by) => setState(() => set(value + by));
      final down = value > 0, up = value < max;
      return Semantics(
        label: label,
        value: _two(value),
        increasedValue: up ? _two(value + 1) : null,
        decreasedValue: down ? _two(value - 1) : null,
        onIncrease: up ? () => step(1) : null,
        onDecrease: down ? () => step(-1) : null,
        child: Row(children: [
          Expanded(
              child: ExcludeSemantics(
                  child: Text(label,
                      style: MNText.resolve(context, MNText.title)))),
          MNQuantityButton(
              icon: MNIconData.minus,
              label: '${s.decrease} $label',
              onPressed: down ? () => step(-1) : null),
          MNPressable(
            onTap: () => _type(label, value, max, set),
            pressedScale: MNMotion.pressChip,
            pressedColor: MNColors.surface,
            borderRadius: BorderRadius.circular(MNRadius.small),
            semanticLabel: '$label, ${_two(value)}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  minWidth: 64, minHeight: MNSize.minTouch),
              child: Center(
                widthFactor: 1,
                child: ExcludeSemantics(
                  child: MNRollingNumber(value,
                      format: _two,
                      style: MNText.resolve(context, MNText.quantity)),
                ),
              ),
            ),
          ),
          MNQuantityButton(
              icon: MNIconData.plus,
              label: '${s.increase} $label',
              onPressed: up ? () => step(1) : null),
        ]),
      );
    }

    return MNSheet(
        title: widget.title ?? s.chooseTime,
        titleStyle: widget.titleStyle,
        children: [
          part(s.hourLabel, _hour, 23, (v) => _hour = v),
          part(s.minuteLabel, _minute, 59, (v) => _minute = v),
          MNButton('${s.useThisTime} · ${_two(_hour)}:${_two(_minute)}',
              onPressed: () =>
                  Navigator.of(context).pop((hour: _hour, minute: _minute))),
        ]);
  }
}

class _DateWheelSheet extends ConsumerStatefulWidget {
  final DateTime first, last, initial;
  final String? title;
  const _DateWheelSheet(
      {required this.first,
      required this.last,
      required this.initial,
      required this.title});

  @override
  ConsumerState<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends ConsumerState<_DateWheelSheet> {
  /// Rows above and below the centre one.
  static const _around = 2;
  late final int _count = widget.last.difference(widget.first).inDays + 1;
  late int _index = widget.initial.difference(widget.first).inDays;
  late final _controller = FixedExtentScrollController(initialItem: _index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // UTC midnight values, so adding days never meets a clock change.
  DateTime _at(int i) => widget.first.add(Duration(days: i));

  void _go(int i) {
    if (i < 0 || i >= _count) return;
    if (MNMotion.reduced(context)) {
      _controller.jumpToItem(i);
    } else {
      _controller.animateToItem(i,
          duration: MNMotion.sheet, curve: MNMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final extent = MediaQuery.textScalerOf(context)
        .scale(MNSize.minTouch)
        .clamp(MNSize.minTouch, MNSize.key + MNSpace.x2);
    final date = _at(_index);
    return MNSheetFrame(
        title: widget.title ?? s.customDate,
        closeLabel: s.close,
        button:
            MNButton(s.useDate, onPressed: () => Navigator.pop(context, date)),
        children: [
          const SizedBox(height: MNSpace.x6),
          Semantics(
            container: true,
            label: widget.title ?? s.customDate,
            value: s.date(date),
            increasedValue:
                _index + 1 < _count ? s.date(_at(_index + 1)) : null,
            decreasedValue: _index > 0 ? s.date(_at(_index - 1)) : null,
            onIncrease: _index + 1 < _count ? () => _go(_index + 1) : null,
            onDecrease: _index > 0 ? () => _go(_index - 1) : null,
            child: ExcludeSemantics(
              child: SizedBox(
                height: extent * (_around * 2 + 1),
                child: Stack(children: [
                  Center(
                      child: Container(
                          height: extent,
                          decoration: BoxDecoration(
                              color: MNColors.surface,
                              borderRadius:
                                  BorderRadius.circular(MNRadius.small)))),
                  ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: extent,
                    physics: const FixedExtentScrollPhysics(),
                    // Nearly flat, as in the reference: rows keep their width.
                    diameterRatio: 40,
                    perspective: .0001,
                    onSelectedItemChanged: (i) => setState(() => _index = i),
                    childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _count,
                        builder: (context, i) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _go(i),
                            child: _WheelRow(
                                date: _at(i),
                                selected: i == _index,
                                strings: s))),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: MNSpace.x4),
        ]);
  }
}

/// Weekday, day, month and year in four aligned columns.
class _WheelRow extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final Strings strings;
  const _WheelRow(
      {required this.date, required this.selected, required this.strings});

  @override
  Widget build(BuildContext context) {
    final style = selected ? MNText.wheelSelected : MNText.wheel;
    Widget cell(String text, int flex, Alignment alignment) => Expanded(
        flex: flex,
        child: Align(
            alignment: alignment,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(text, maxLines: 1, style: style))));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MNSpace.x5),
      child: Row(children: [
        cell(strings.weekdayName(date.weekday), 4, Alignment.centerLeft),
        cell('${date.day}', 2, Alignment.center),
        cell(strings.monthShort(date.month), 2, Alignment.center),
        cell('${date.year}', 2, Alignment.centerRight),
      ]),
    );
  }
}
