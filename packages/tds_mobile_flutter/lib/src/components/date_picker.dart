import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import 'bottom_sheet.dart';
import 'text.dart';
import 'text_field.dart';

DateTime tdsDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);
int tdsDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
DateTime tdsClampDate(DateTime value, {DateTime? min, DateTime? max}) {
  final date = tdsDateOnly(value);
  if (min != null && date.isBefore(tdsDateOnly(min))) return tdsDateOnly(min);
  if (max != null && date.isAfter(tdsDateOnly(max))) return tdsDateOnly(max);
  return date;
}

bool _same(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

enum TdsWheelPerspective { center, left, right }

class TdsWheel extends StatefulWidget {
  const TdsWheel({
    required this.options,
    required this.onChange,
    this.initialIndex = 0,
    this.loop = false,
    this.width = 70,
    this.height = 240,
    this.formatValue,
    this.dialDegree = 18,
    this.perspective = TdsWheelPerspective.center,
    this.semanticLabel = '선택해 주세요',
    super.key,
  }) : assert(initialIndex >= 0),
       assert(dialDegree > 0 && dialDegree < 90);
  final List<int> options;
  final int initialIndex;
  final bool loop;
  final double width, height, dialDegree;
  final String Function(int)? formatValue;
  final ValueChanged<int> onChange;
  final TdsWheelPerspective perspective;
  final String semanticLabel;
  @override
  State<TdsWheel> createState() => _TdsWheelState();
}

class _TdsWheelState extends State<TdsWheel> {
  int get _initial => widget.options.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.options.length - 1);
  late int _selected = _initial;
  late final _controller = FixedExtentScrollController(initialItem: _initial);
  @override
  void didUpdateWidget(TdsWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex ||
        !listEquals(oldWidget.options, widget.options)) {
      _selected = _initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToItem(_initial);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void move(int delta) {
    if (widget.options.isEmpty) return;
    final target = widget.loop
        ? _controller.selectedItem + delta
        : (_selected + delta).clamp(0, widget.options.length - 1);
    _controller.animateToItem(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return SizedBox(width: widget.width + 12, height: widget.height);
    }
    String label(int index) =>
        widget.formatValue?.call(widget.options[index]) ??
        '${widget.options[index]}';
    final extent =
        widget.height * math.sin(widget.dialDegree * math.pi / 180) / 2;
    return Semantics(
      label: widget.semanticLabel,
      value: label(_selected),
      increasedValue: label((_selected + 1) % widget.options.length),
      decreasedValue: label((_selected - 1) % widget.options.length),
      onIncrease: widget.loop || _selected < widget.options.length - 1
          ? () => move(1)
          : null,
      onDecrease: widget.loop || _selected > 0 ? () => move(-1) : null,
      child: Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.arrowDown ||
                  e.logicalKey == LogicalKeyboardKey.arrowUp)) {
            move(e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ExcludeSemantics(
          child: TdsFontScaleLimit(
            limit: 135,
            child: SizedBox(
              width: widget.width + 12,
              height: widget.height,
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                physics: const FixedExtentScrollPhysics(),
                itemExtent: extent,
                diameterRatio: 1.1,
                perspective: .003,
                offAxisFraction: switch (widget.perspective) {
                  TdsWheelPerspective.center => 0,
                  TdsWheelPerspective.left => -.4,
                  TdsWheelPerspective.right => .4,
                },
                overAndUnderCenterOpacity: .5,
                onSelectedItemChanged: (index) {
                  final next = index % widget.options.length;
                  if (next == _selected) return;
                  setState(() => _selected = next);
                  widget.onChange(widget.options[next]);
                },
                childDelegate: widget.loop
                    ? ListWheelChildLoopingListDelegate(
                        children: [
                          for (var i = 0; i < widget.options.length; i++)
                            Center(
                              child: TdsText(
                                label(i),
                                typography: TdsTypography.t4,
                              ),
                            ),
                        ],
                      )
                    : ListWheelChildBuilderDelegate(
                        childCount: widget.options.length,
                        builder: (context, i) => Center(
                          child: TdsText(
                            label(i),
                            typography: TdsTypography.t4,
                          ),
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

class TdsWheelDateSheet extends StatefulWidget {
  const TdsWheelDateSheet({
    required this.open,
    required this.title,
    required this.onClose,
    required this.onChange,
    this.initialDate,
    this.min,
    this.max,
    this.description,
    this.onWheel,
    this.buttonText = '적용',
    super.key,
  });
  final bool open;
  final String title, buttonText;
  final String? description;
  final DateTime? initialDate, min, max;
  final VoidCallback onClose;
  final VoidCallback? onWheel;
  final ValueChanged<DateTime> onChange;
  @override
  State<TdsWheelDateSheet> createState() => _TdsWheelDateSheetState();
}

class _TdsWheelDateSheetState extends State<TdsWheelDateSheet> {
  late final DateTime _initial = widget.initialDate ?? DateTime.now();
  DateTime get min => tdsDateOnly(
    widget.min ?? DateTime(_initial.year - 100, _initial.month, _initial.day),
  );
  DateTime get max => tdsDateOnly(
    widget.max ?? DateTime(_initial.year + 100, _initial.month, _initial.day),
  );
  late DateTime _date = tdsClampDate(_initial, min: min, max: max);
  void change({int? year, int? month, int? day}) {
    final y = year ?? _date.year, m = month ?? _date.month;
    setState(
      () => _date = tdsClampDate(
        DateTime(y, m, math.min(day ?? _date.day, tdsDaysInMonth(y, m))),
        min: min,
        max: max,
      ),
    );
    widget.onWheel?.call();
  }

  @override
  void didUpdateWidget(TdsWheelDateSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _date = tdsClampDate(_date, min: min, max: max);
  }

  @override
  Widget build(BuildContext context) {
    if (min.isAfter(max)) throw ArgumentError('min must not be after max');
    final firstMonth = _date.year == min.year ? min.month : 1,
        lastMonth = _date.year == max.year ? max.month : 12;
    final firstDay = _date.year == min.year && _date.month == min.month
        ? min.day
        : 1;
    final lastDay = _date.year == max.year && _date.month == max.month
        ? max.day
        : tdsDaysInMonth(_date.year, _date.month);
    List<int> range(int start, int end) =>
        List.generate(end - start + 1, (i) => start + i);
    return TdsBottomSheet(
      open: widget.open,
      onClose: widget.onClose,
      disableChildrenDragging: true,
      header: TdsBottomSheetHeader(widget.title),
      headerDescription: widget.description == null
          ? null
          : TdsBottomSheetHeaderDescription(widget.description!),
      cta: TdsBottomSheetCTA(
        onPressed: () {
          widget.onChange(_date);
          widget.onClose();
        },
        child: Text(widget.buttonText),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: TdsWheel(
              options: range(min.year, max.year),
              initialIndex: _date.year - min.year,
              onChange: (year) => change(year: year),
              formatValue: (v) => '$v년',
              semanticLabel: '년도 선택',
              perspective: TdsWheelPerspective.right,
            ),
          ),
          Flexible(
            child: TdsWheel(
              options: range(firstMonth, lastMonth),
              initialIndex: _date.month - firstMonth,
              onChange: (month) => change(month: month),
              formatValue: (v) => '$v월',
              semanticLabel: '월 선택',
              width: 50,
            ),
          ),
          Flexible(
            child: TdsWheel(
              options: range(firstDay, lastDay),
              initialIndex: _date.day - firstDay,
              onChange: (day) => change(day: day),
              formatValue: (v) => '$v일',
              semanticLabel: '일 선택',
              perspective: TdsWheelPerspective.left,
              width: 50,
            ),
          ),
        ],
      ),
    );
  }
}

class TdsWheelDatePicker extends StatefulWidget {
  const TdsWheelDatePicker({
    required this.title,
    required this.triggerLabel,
    required this.onChange,
    this.value,
    this.initialDate,
    this.min,
    this.max,
    this.description,
    this.buttonText = '적용',
    this.onWheel,
    this.formatValue,
    super.key,
  });
  final String title, triggerLabel, buttonText;
  final String? description;
  final DateTime? value, initialDate, min, max;
  final ValueChanged<DateTime> onChange;
  final VoidCallback? onWheel;
  final String Function(DateTime)? formatValue;
  @override
  State<TdsWheelDatePicker> createState() => _TdsWheelDatePickerState();
}

class _TdsWheelDatePickerState extends State<TdsWheelDatePicker> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TdsTextFieldButton(
        variant: TdsTextFieldVariant.line,
        label: widget.triggerLabel,
        value: widget.value == null
            ? ''
            : widget.formatValue?.call(widget.value!) ??
                  '${widget.value!.year}.${widget.value!.month.toString().padLeft(2, '0')}.${widget.value!.day.toString().padLeft(2, '0')}',
        onPressed: () => setState(() => _open = true),
      ),
      TdsWheelDateSheet(
        open: _open,
        title: widget.title,
        description: widget.description,
        initialDate: widget.initialDate,
        min: widget.min,
        max: widget.max,
        buttonText: widget.buttonText,
        onWheel: widget.onWheel,
        onChange: widget.onChange,
        onClose: () => setState(() => _open = false),
      ),
    ],
  );
}

@immutable
class TdsDateRange {
  const TdsDateRange(this.start, this.end);
  final DateTime? start, end;
  TdsDateRange select(DateTime day, {bool allowSameDate = false}) =>
      start == null
      ? TdsDateRange(day, null)
      : end == null &&
            (day.isAfter(start!) || allowSameDate && _same(day, start))
      ? TdsDateRange(start, day)
      : TdsDateRange(day, null);
}

class TdsDatePicker extends StatelessWidget {
  const TdsDatePicker({
    this.selectedDate,
    this.defaultSelectedDate,
    this.onDateChange,
    this.initialMonth,
    this.maxVisibleMonth,
    this.minSelectableDate,
    this.maxSelectableDate,
    this.disabledDate,
    this.dayAriaLabel,
    this.monthPageSize = 5,
    this.scrollThreshold = 50,
    this.controlled = false,
    super.key,
  });
  final DateTime? selectedDate,
      defaultSelectedDate,
      initialMonth,
      maxVisibleMonth,
      minSelectableDate,
      maxSelectableDate;
  final ValueChanged<DateTime?>? onDateChange;
  final bool Function(DateTime)? disabledDate;
  final String Function(DateTime)? dayAriaLabel;
  final int monthPageSize;
  final double scrollThreshold;
  final bool controlled;
  @override
  Widget build(BuildContext context) => _Calendar(
    range: false,
    controlled: controlled || selectedDate != null,
    start: selectedDate,
    defaultStart: defaultSelectedDate,
    onChange: (v) => onDateChange?.call(v.start),
    initialMonth: initialMonth,
    maxVisibleMonth: maxVisibleMonth,
    min: minSelectableDate,
    max: maxSelectableDate,
    disabledDate: disabledDate,
    dayAriaLabel: dayAriaLabel,
    pageSize: monthPageSize,
    scrollThreshold: scrollThreshold,
  );
}

class TdsDateRangePicker extends StatelessWidget {
  const TdsDateRangePicker({
    this.startDate,
    this.endDate,
    this.defaultStartDate,
    this.defaultEndDate,
    this.onDatesChange,
    this.initialMonth,
    this.maxVisibleMonth,
    this.minSelectableDate,
    this.maxSelectableDate,
    this.disabledDate,
    this.dayAriaLabel,
    this.allowSameDateSelect = false,
    this.monthPageSize = 3,
    this.scrollThreshold = 50,
    this.controlled = false,
    super.key,
  });
  final DateTime? startDate,
      endDate,
      defaultStartDate,
      defaultEndDate,
      initialMonth,
      maxVisibleMonth,
      minSelectableDate,
      maxSelectableDate;
  final ValueChanged<TdsDateRange>? onDatesChange;
  final bool Function(DateTime)? disabledDate;
  final String Function(DateTime)? dayAriaLabel;
  final bool allowSameDateSelect, controlled;
  final int monthPageSize;
  final double scrollThreshold;
  @override
  Widget build(BuildContext context) => _Calendar(
    range: true,
    controlled: controlled || startDate != null || endDate != null,
    start: startDate,
    end: endDate,
    defaultStart: defaultStartDate,
    defaultEnd: defaultEndDate,
    onChange: onDatesChange,
    initialMonth: initialMonth,
    maxVisibleMonth: maxVisibleMonth,
    min: minSelectableDate,
    max: maxSelectableDate,
    disabledDate: disabledDate,
    dayAriaLabel: dayAriaLabel,
    allowSameDate: allowSameDateSelect,
    pageSize: monthPageSize,
    scrollThreshold: scrollThreshold,
  );
}

class _Calendar extends StatefulWidget {
  const _Calendar({
    required this.range,
    required this.controlled,
    this.start,
    this.end,
    this.defaultStart,
    this.defaultEnd,
    this.onChange,
    this.initialMonth,
    this.maxVisibleMonth,
    this.min,
    this.max,
    this.disabledDate,
    this.dayAriaLabel,
    this.allowSameDate = false,
    required this.pageSize,
    required this.scrollThreshold,
  }) : assert(pageSize > 0);
  final bool range, controlled, allowSameDate;
  final DateTime? start,
      end,
      defaultStart,
      defaultEnd,
      initialMonth,
      maxVisibleMonth,
      min,
      max;
  final ValueChanged<TdsDateRange>? onChange;
  final bool Function(DateTime)? disabledDate;
  final String Function(DateTime)? dayAriaLabel;
  final int pageSize;
  final double scrollThreshold;
  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  late final _today = tdsDateOnly(DateTime.now());
  late TdsDateRange _value = TdsDateRange(
    widget.defaultStart,
    widget.defaultEnd,
  );
  late int _count = widget.pageSize + 1;
  DateTime get month => DateTime(
    (widget.initialMonth ?? _today).year,
    (widget.initialMonth ?? _today).month,
  );
  TdsDateRange get value =>
      widget.controlled ? TdsDateRange(widget.start, widget.end) : _value;
  bool disabled(DateTime day) {
    final min = widget.min ?? (widget.range ? null : _today);
    return min != null && day.isBefore(tdsDateOnly(min)) ||
        widget.max != null && day.isAfter(tdsDateOnly(widget.max!)) ||
        (widget.disabledDate?.call(day) ?? false);
  }

  void select(DateTime day) {
    if (disabled(day)) return;
    final next = widget.range
        ? value.select(day, allowSameDate: widget.allowSameDate)
        : TdsDateRange(_same(day, value.start) ? null : day, null);
    if (!widget.controlled) setState(() => _value = next);
    widget.onChange?.call(next);
  }

  @override
  void didUpdateWidget(_Calendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMonth != widget.initialMonth ||
        oldWidget.pageSize != widget.pageSize) {
      _count = widget.pageSize + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final maxMonths = widget.maxVisibleMonth == null
        ? _count
        : math.max(
            0,
            (widget.maxVisibleMonth!.year - month.year) * 12 +
                widget.maxVisibleMonth!.month -
                month.month +
                1,
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              for (final name in ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(
                  child: TdsText(
                    name,
                    typography: TdsTypography.st11,
                    color: theme.color('grey600'),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        const TdsBorder(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < widget.scrollThreshold &&
                  _count < maxMonths) {
                setState(() => _count += widget.pageSize);
              }
              // Without maxVisibleMonth the source loads further months indefinitely.
              if (widget.maxVisibleMonth == null &&
                  n is ScrollUpdateNotification &&
                  n.metrics.extentAfter < widget.scrollThreshold) {
                setState(() => _count += widget.pageSize);
              }
              return false;
            },
            child: ListView.builder(
              itemCount: math.min(_count, maxMonths),
              itemBuilder: (context, index) {
                final date = DateTime(month.year, month.month + index);
                final leading = date.weekday % 7,
                    days = tdsDaysInMonth(date.year, date.month);
                final weeks = ((leading + days) / 7).ceil();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 32, 18, 8),
                      child: Semantics(
                        header: true,
                        child: TdsText(
                          '${date.year}.${date.month.toString().padLeft(2, '0')}',
                          typography: TdsTypography.t3,
                          fontWeight: TdsFontWeight.bold,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    for (var week = 0; week < weeks; week++)
                      Row(
                        children: [
                          for (var column = 0; column < 7; column++)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final d = week * 7 + column - leading + 1;
                                  if (d < 1 || d > days) {
                                    return const SizedBox(height: 46);
                                  }
                                  final day = DateTime(
                                    date.year,
                                    date.month,
                                    d,
                                  );
                                  final start = _same(value.start, day),
                                      end = _same(value.end, day),
                                      chosen = start || end;
                                  final inRange =
                                      value.start != null &&
                                      value.end != null &&
                                      !day.isBefore(value.start!) &&
                                      !day.isAfter(value.end!);
                                  final isDisabled = disabled(day);
                                  final label =
                                      widget.dayAriaLabel?.call(day) ??
                                      '${day.year}년 ${day.month}월 ${day.day}일';
                                  final suffix = !widget.range && chosen
                                      ? '이 선택됨'
                                      : start && end
                                      ? '이 선택됨'
                                      : start
                                      ? '이 시작날짜로 선택됨'
                                      : end
                                      ? '이 끝날짜로 선택됨'
                                      : inRange
                                      ? '이 선택범위에 포함됨'
                                      : '';
                                  return Semantics(
                                    selected: chosen || inRange,
                                    child: TdsPressable(
                                      semanticLabel: '$label$suffix',
                                      enabled: !isDisabled,
                                      onPressed: () => select(day),
                                      builder:
                                          (
                                            context,
                                            pressed,
                                            hovered,
                                            focused,
                                          ) => SizedBox(
                                            height: 46,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (inRange)
                                                  Positioned.fill(
                                                    child: FractionallySizedBox(
                                                      widthFactor: chosen
                                                          ? .5
                                                          : 1,
                                                      alignment: start
                                                          ? Alignment
                                                                .centerRight
                                                          : Alignment
                                                                .centerLeft,
                                                      child: ColoredBox(
                                                        color: theme.color(
                                                          'greyOpacity100',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                Container(
                                                  width: 46,
                                                  height: 46,
                                                  alignment: Alignment.center,
                                                  decoration: chosen || focused
                                                      ? BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: theme.color(
                                                            'blue500',
                                                          ),
                                                        )
                                                      : null,
                                                  child: ExcludeSemantics(
                                                    child: TdsText(
                                                      '$d',
                                                      typography:
                                                          TdsTypography.st9,
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                      ),
                                                      color: isDisabled
                                                          ? theme.color(
                                                              'grey300',
                                                            )
                                                          : chosen || focused
                                                          ? const Color(
                                                              0xffffffff,
                                                            )
                                                          : theme.color(
                                                              inRange
                                                                  ? 'grey700'
                                                                  : 'grey600',
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                                if (_same(day, _today) &&
                                                    !chosen)
                                                  Positioned(
                                                    top: 6,
                                                    child: Container(
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: theme.color(
                                                          'blue500',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
