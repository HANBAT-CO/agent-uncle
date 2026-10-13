import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../domain/profile_validation.dart';

/// 가입·프로필의 HH:mm 값을 TDS 시·분 휠로 선택한다.
class ProfileTimeField extends StatefulWidget {
  const ProfileTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.initialHour = 0,
    this.optional = false,
    this.error,
    super.key,
  }) : assert(initialHour >= 0 && initialHour < 24);

  final String label, value;
  final ValueChanged<String> onChanged;
  final int initialHour;
  final bool optional;
  final String? error;

  @override
  State<ProfileTimeField> createState() => _ProfileTimeFieldState();
}

class _ProfileTimeFieldState extends State<ProfileTimeField> {
  static final hours = List.generate(24, (i) => i, growable: false);
  static final minutes = List.generate(60, (i) => i, growable: false);
  bool open = false;
  int revision = 0, initialHour = 0, initialMinute = 0, hour = 0, minute = 0;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  void showPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    final parts = isValidTimeText(widget.value)
        ? widget.value.trim().split(':').map(int.parse).toList()
        : [widget.initialHour, 0];
    setState(() {
      initialHour = hour = parts[0];
      initialMinute = minute = parts[1];
      revision++;
      open = true;
    });
  }

  void close() => setState(() => open = false);

  void commit(String value) {
    close();
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TdsTextFieldButton(
        variant: TdsTextFieldVariant.box,
        label: widget.optional ? '${widget.label} (선택)' : widget.label,
        labelOption: TdsTextFieldLabelOption.sustain,
        value: widget.value,
        placeholder: '시간 선택',
        paddingTop: 10,
        paddingBottom: 10,
        focused: open,
        hasError: widget.error != null,
        help: widget.error == null ? null : Text(widget.error!),
        onPressed: showPicker,
      ),
      TdsBottomSheet(
        open: open,
        onClose: close,
        disableChildrenDragging: true,
        semanticLabel: '${widget.label} 선택',
        header: TdsBottomSheetHeader('${widget.label} 선택'),
        headerDescription: const TdsBottomSheetHeaderDescription(
          '24시간 기준으로 시와 분을 선택해 주세요.',
        ),
        cta: TdsBottomSheetDoubleCTA(
          leftButton: TdsButton(
            display: TdsButtonDisplay.block,
            variant: TdsButtonVariant.weak,
            onPressed: close,
            child: const Text('취소'),
          ),
          rightButton: TdsButton(
            display: TdsButtonDisplay.block,
            onPressed: () => commit('${twoDigits(hour)}:${twoDigits(minute)}'),
            child: const Text('적용'),
          ),
          bottomAccessory: widget.optional
              ? TdsTextButton(
                  size: TdsTextButtonSize.small,
                  colorToken: 'grey600',
                  onPressed: () => commit(''),
                  child: const SizedBox(
                    height: 44,
                    child: Center(child: Text('선택 해제')),
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 휠이 움직이는 동안 initialIndex를 바꾸면 스크롤이 되감긴다.
            // 열 때의 위치는 고정하고 적용할 임시 값만 갱신한다.
            Flexible(
              child: TdsWheel(
                key: ValueKey('hour-$revision'),
                options: hours,
                initialIndex: initialHour,
                semanticLabel: '${widget.label} 시',
                formatValue: (value) => '${twoDigits(value)}시',
                onChange: (value) => hour = value,
              ),
            ),
            Flexible(
              child: TdsWheel(
                key: ValueKey('minute-$revision'),
                options: minutes,
                initialIndex: initialMinute,
                semanticLabel: '${widget.label} 분',
                formatValue: (value) => '${twoDigits(value)}분',
                onChange: (value) => minute = value,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
