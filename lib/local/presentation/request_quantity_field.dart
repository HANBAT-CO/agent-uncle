import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'common.dart';

/// 일반 수량은 TDS 휠로, 50개 초과 수량은 숫자 입력으로 작성한다.
class RequestQuantityField extends StatefulWidget {
  const RequestQuantityField({
    required this.controller,
    required this.directInput,
    required this.onDirectInputChanged,
    required this.onChanged,
    this.error,
    super.key,
  });

  final TextEditingController controller;
  final bool directInput;
  final ValueChanged<bool> onDirectInputChanged;
  final VoidCallback onChanged;
  final String? error;

  @override
  State<RequestQuantityField> createState() => _RequestQuantityFieldState();
}

class _RequestQuantityFieldState extends State<RequestQuantityField> {
  static final quantities = List.generate(50, (i) => i + 1, growable: false);
  static final digitsOnly = TdsTextFieldFormat(
    transform: (value) => value.replaceAll(RegExp(r'[^0-9]'), ''),
  );
  bool open = false;
  int revision = 0, initialIndex = 0, pendingQuantity = 1;
  late int wheelQuantity = widget.directInput
      ? 1
      : (int.tryParse(widget.controller.text) ?? 1).clamp(1, 50);
  late String directQuantity = widget.directInput ? widget.controller.text : '';

  void toggleDirectInput(bool value) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (value) {
      wheelQuantity = (int.tryParse(widget.controller.text) ?? 1).clamp(1, 50);
      widget.controller.text = directQuantity;
    } else {
      directQuantity = widget.controller.text;
      widget.controller.text = '$wheelQuantity';
    }
    widget.onDirectInputChanged(value);
  }

  void showPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      pendingQuantity = (int.tryParse(widget.controller.text) ?? 1).clamp(
        1,
        50,
      );
      initialIndex = pendingQuantity - 1;
      revision++;
      open = true;
    });
  }

  void close() => setState(() => open = false);

  void apply() {
    widget.controller.text = '$pendingQuantity';
    wheelQuantity = pendingQuantity;
    close();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.directInput)
        Field(
          '요청 수량',
          controller: widget.controller,
          numeric: true,
          format: digitsOnly,
          placeholder: '51개 이상 숫자로 입력',
          error: widget.error,
          onChanged: (_) => widget.onChanged(),
        )
      else
        TdsTextFieldButton(
          variant: TdsTextFieldVariant.box,
          label: '요청 수량',
          labelOption: TdsTextFieldLabelOption.sustain,
          value: '${widget.controller.text}개',
          paddingTop: 10,
          paddingBottom: 10,
          focused: open,
          hasError: widget.error != null,
          help: widget.error == null ? null : Text(widget.error!),
          onPressed: showPicker,
        ),
      Inset(
        child: TdsCheckbox(
          checked: widget.directInput,
          onChanged: toggleDirectInput,
          child: const Text('50개 초과 직접 입력'),
        ),
      ),
      TdsBottomSheet(
        open: open,
        onClose: close,
        disableChildrenDragging: true,
        semanticLabel: '요청 수량 선택',
        header: const TdsBottomSheetHeader('요청 수량 선택'),
        headerDescription: const TdsBottomSheetHeaderDescription(
          '숫자를 위아래로 스크롤해 1~50개 중 선택해 주세요.',
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
            onPressed: apply,
            child: const Text('적용'),
          ),
        ),
        child: Center(
          child: TdsWheel(
            key: ValueKey('request-quantity-$revision'),
            options: quantities,
            initialIndex: initialIndex,
            width: 120,
            semanticLabel: '요청 수량',
            formatValue: (value) => '$value개',
            // 스크롤 중에는 시작 위치를 바꾸지 않고 적용할 값만 갱신한다.
            onChange: (value) => pendingQuantity = value,
          ),
        ),
      ),
    ],
  );
}
