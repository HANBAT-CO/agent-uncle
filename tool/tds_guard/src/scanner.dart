/// Detects UI code in the app that bypasses `tds_mobile_flutter`.
///
/// Rules match identifiers in code only: comments and string contents are
/// blanked first, so documentation and copy never trigger a rule.
library;

/// One forbidden pattern. [alternative] names the TDS replacement so an agent
/// can fix the violation without inventing a component.
class GuardRule {
  const GuardRule({
    required this.id,
    required this.message,
    required this.alternative,
    required this.pattern,
    this.onImports = false,
    this.themeMayUse = false,
  });

  final String id;
  final String message;
  final String alternative;
  final RegExp pattern;

  /// Matched against `import`/`export` directives instead of code.
  final bool onImports;

  /// `lib/core/theme/` owns brand colors, fonts and the TDS theme subclass.
  final bool themeMayUse;
}

RegExp _words(List<String> names) => RegExp('\\b(?:${names.join('|')})\\b');

final guardRules = <GuardRule>[
  GuardRule(
    id: 'material-import',
    message: 'Material 위젯/아이콘 import 금지',
    alternative: 'package:tds_mobile_flutter/tds_mobile_flutter.dart 컴포넌트',
    pattern: RegExp(r'''['"]package:flutter/material\.dart['"]'''),
    onImports: true,
  ),
  GuardRule(
    id: 'cupertino-import',
    message: 'Cupertino 위젯/아이콘 import 금지',
    alternative: 'package:tds_mobile_flutter/tds_mobile_flutter.dart 컴포넌트',
    pattern: RegExp(r'''['"]package:flutter/cupertino\.dart['"]'''),
    onImports: true,
  ),
  GuardRule(
    id: 'dart-ui-import',
    message: 'dart:ui 직접 사용 금지 (필터·캔버스·셰이더)',
    alternative: 'TDS 컴포넌트가 제공하는 표면·효과 (예: TdsLiquidTabBar)',
    pattern: RegExp(r'''['"]dart:ui['"]'''),
    onImports: true,
  ),
  GuardRule(
    id: 'tds-internal-import',
    message: 'tds_mobile_flutter 내부(src/) import 금지',
    alternative: "import 'package:tds_mobile_flutter/tds_mobile_flutter.dart'",
    pattern: RegExp(r'''['"]package:tds_mobile_flutter/src/'''),
    onImports: true,
  ),
  GuardRule(
    id: 'raw-decoration',
    message: '직접 만든 박스·테두리·그림자·그라디언트 금지',
    alternative:
        'TdsBorder, TdsListRow, TdsAssetFrame, 기존 FigmaSurface/PageFrame',
    pattern: _words([
      'Container',
      'DecoratedBox',
      'ColoredBox',
      'BoxDecoration',
      'ShapeDecoration',
      'BoxShadow',
      'Shadow',
      'BorderRadius',
      'BorderSide',
      'Border',
      'RoundedRectangleBorder',
      'StadiumBorder',
      'CircleBorder',
      'ContinuousRectangleBorder',
      'BeveledRectangleBorder',
      'LinearGradient',
      'RadialGradient',
      'SweepGradient',
      'PhysicalModel',
      'PhysicalShape',
      'Card',
      'Material',
      'Ink',
    ]),
  ),
  GuardRule(
    id: 'raw-paint',
    message: '직접 그리기·클리핑·필터·투명도·변형 금지',
    alternative: 'TDS 컴포넌트의 기본 렌더링 (TdsAssetFrame, TdsLiquidGlass 등)',
    pattern: _words([
      'CustomPaint',
      'CustomPainter',
      'CustomClipper',
      'CustomSingleChildLayout',
      'CustomMultiChildLayout',
      'Canvas',
      'Paint',
      'Path',
      'ClipRRect',
      'ClipRSuperellipse',
      'ClipOval',
      'ClipPath',
      'ClipRect',
      'BackdropFilter',
      'BackdropGroup',
      'ImageFilter',
      'ColorFilter',
      'ColorFiltered',
      'ShaderMask',
      'Opacity',
      'Transform',
      'RotatedBox',
    ]),
  ),
  GuardRule(
    id: 'raw-gesture',
    message: '직접 만든 터치·제스처 영역 금지 (자체 버튼 생성)',
    alternative:
        'TdsButton, TdsTextButton, TdsIconButton, TdsListRow(onPressed:), TdsChip',
    pattern: _words([
      'GestureDetector',
      'RawGestureDetector',
      'InkWell',
      'InkResponse',
      'Listener',
      'MouseRegion',
      'Draggable',
      'LongPressDraggable',
      'DragTarget',
      'Dismissible',
      'TapRegion',
      'RawMaterialButton',
    ]),
  ),
  GuardRule(
    id: 'raw-text-style',
    message: '직접 지정한 글꼴·텍스트 스타일 금지',
    alternative:
        'TdsText(typography: TdsTypography.*, fontWeight: TdsFontWeight.*)',
    pattern: _words([
      'TextStyle',
      'RichText',
      'TextSpan',
      'DefaultTextStyle',
      'FontWeight',
      'FontStyle',
      'FontFeature',
      'TextDecoration',
      'TextTheme',
    ]),
    themeMayUse: true,
  ),
  GuardRule(
    id: 'raw-color',
    message: '하드코딩 색상·색상 가공 금지',
    alternative: "TdsTheme.of(context).color('토큰'), TdsPalette.*, AppColors.*",
    pattern: RegExp(
      r'\bColor\s*\(|\bColor\.(?:fromARGB|fromRGBO|from|lerp)\b|'
      r'\b(?:Colors|CupertinoColors|HSLColor|HSVColor)\b|'
      r'\.(?:withOpacity|withValues|withAlpha|withRed|withGreen|withBlue)\s*\(',
    ),
    themeMayUse: true,
  ),
  GuardRule(
    id: 'raw-icon',
    message: 'Material/Cupertino 아이콘·직접 만든 아이콘 금지',
    alternative:
        'TdsAssetIcon, TdsIconButtonImage, 기존 FigmaIcon (assets/icons 원본)',
    pattern: _words([
      'Icon',
      'Icons',
      'IconData',
      'ImageIcon',
      'CupertinoIcons',
    ]),
  ),
  GuardRule(
    id: 'raw-image',
    message: 'Image 위젯 직접 사용 금지',
    alternative: 'TdsAssetFrame + TdsAssetImage',
    pattern: _words([
      'Image',
      'RawImage',
      'NetworkImage',
      'AssetImage',
      'MemoryImage',
      'FileImage',
      'ResizeImage',
      'DecorationImage',
      'SvgPicture',
    ]),
  ),
  GuardRule(
    id: 'raw-animation',
    message: '직접 만든 애니메이션·전환 금지',
    alternative: 'TDS 컴포넌트 내장 모션 (TdsMotion 토큰)',
    pattern: RegExp(
      '${_words(['AnimationController', 'Tween', 'TweenAnimationBuilder', 'CurvedAnimation', 'Curves', 'Hero', 'AnimatedContainer', 'AnimatedOpacity', 'AnimatedPadding', 'AnimatedAlign', 'AnimatedPositioned', 'AnimatedScale', 'AnimatedRotation', 'AnimatedSlide', 'AnimatedSize', 'AnimatedDefaultTextStyle', 'AnimatedPhysicalModel', 'AnimatedCrossFade', 'AnimatedSwitcher', 'AnimatedList', 'FadeTransition', 'ScaleTransition', 'SlideTransition', 'SizeTransition', 'RotationTransition', 'PositionedTransition', 'AlignTransition', 'DecoratedBoxTransition', 'DefaultTextStyleTransition', 'RelativePositionedTransition', 'MatrixTransition']).pattern}|\\btransitionsBuilder\\s*:',
    ),
  ),
  GuardRule(
    id: 'raw-overlay',
    message: '직접 만든 오버레이·다이얼로그·라우트 금지',
    alternative:
        'TdsDialogProvider + TdsAlertDialog/TdsConfirmDialog, TdsBottomSheet, TdsToast, TdsTooltip, TdsMenu',
    pattern: _words([
      'Overlay',
      'OverlayEntry',
      'OverlayPortal',
      'PopupRoute',
      'RawDialogRoute',
      'showGeneralDialog',
      'showDialog',
      'showModalBottomSheet',
      'showMenu',
    ]),
  ),
  GuardRule(
    id: 'raw-input',
    message: '직접 만든 텍스트 입력 금지',
    alternative:
        'TdsTextField, TdsSearchField, TdsSplitTextField, TdsNumberKeypad',
    pattern: _words(['EditableText', 'SelectableText']),
  ),
  GuardRule(
    id: 'tds-impersonation',
    message: '앱 코드에서 Tds* 이름의 새 타입 정의 금지 (TDS 컴포넌트 창작)',
    alternative: '패키지에 있는 TDS 컴포넌트 조합',
    pattern: RegExp(
      r'\b(?:class|mixin|enum|typedef|extension(?:\s+type)?)\s+Tds\w*',
    ),
  ),
  GuardRule(
    id: 'tds-subclass',
    message: 'TDS 컴포넌트 상속으로 변형 컴포넌트 생성 금지',
    alternative: 'TDS 컴포넌트를 공개 파라미터로 그대로 사용',
    pattern: RegExp(r'\b(?:extends|implements|with)\s+Tds\w+'),
    themeMayUse: true,
  ),
];

GuardRule ruleById(String id) => guardRules.firstWhere((rule) => rule.id == id);

/// App source owned by this policy. Tests, tools and the TDS package itself
/// are outside it.
bool isGuardedSource(String relPath) =>
    relPath.startsWith('lib/') && relPath.endsWith('.dart');

bool _isThemeLayer(String relPath) => relPath.startsWith('lib/core/theme/');

/// 사용자 승인: 표준 iOS 뒤로가기만 공통 내비게이션 계층에 허용한다.
/// Cupertino 위젯의 추가 노출, 재수출, 다른 파일의 import는 계속 금지한다.
bool _isApprovedNavigationImport(String relPath, String directive) =>
    relPath == 'lib/core/navigation/app_page_route.dart' &&
    RegExp(
      r'''^\s*import ['"]package:flutter/cupertino\.dart['"] show CupertinoPageRoute;\s*$''',
    ).hasMatch(directive);

/// Rule id → 1-based line of every match, in source order.
Map<String, List<int>> scanSource(String relPath, String source) {
  final code = stripCommentsAndStrings(source);
  final lineStarts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) lineStarts.add(i + 1);
  }
  int lineOf(int offset) {
    var low = 0, high = lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  final directives = RegExp(
    r'^[ \t]*(?:import|export)\b[^\n]*',
    multiLine: true,
  ).allMatches(source).toList();
  // `show Icons` in a directive is part of the import, not a usage.
  final body = code.codeUnits.toList();
  for (final directive in directives) {
    body.fillRange(directive.start, directive.end, 0x20);
  }
  final bodyCode = String.fromCharCodes(body);

  final hits = <String, List<int>>{};
  for (final rule in guardRules) {
    if (rule.themeMayUse && _isThemeLayer(relPath)) continue;
    final lines = <int>[];
    if (rule.onImports) {
      for (final directive in directives) {
        // The directive must survive stripping, i.e. it is not commented out.
        if (code.substring(directive.start, directive.end).trim().isEmpty) {
          continue;
        }
        if (rule.pattern.hasMatch(directive.group(0)!)) {
          if (rule.id == 'cupertino-import' &&
              _isApprovedNavigationImport(relPath, directive.group(0)!)) {
            continue;
          }
          lines.add(lineOf(directive.start));
        }
      }
    } else {
      for (final match in rule.pattern.allMatches(bodyCode)) {
        lines.add(lineOf(match.start));
      }
    }
    if (lines.isNotEmpty) hits[rule.id] = lines;
  }
  return hits;
}

/// Replaces comments and string literal contents with spaces. Offsets and
/// newlines are preserved; code inside `${...}` interpolation is kept.
String stripCommentsAndStrings(String source) {
  final out = source.codeUnits.toList();
  final length = out.length;
  const slash = 0x2F, star = 0x2A, newline = 0x0A, backslash = 0x5C;
  const dollar = 0x24, openBrace = 0x7B, closeBrace = 0x7D;
  const single = 0x27, double = 0x22;

  void blank(int index) {
    if (out[index] != newline) out[index] = 0x20;
  }

  bool isQuote(int unit) => unit == single || unit == double;
  late int Function(int start, bool untilBrace) code;

  // Returns the index just after the closing quote.
  int string(int start, bool raw) {
    final quote = out[start];
    final triple =
        start + 2 < length &&
        out[start + 1] == quote &&
        out[start + 2] == quote;
    var i = start + (triple ? 3 : 1);
    while (i < length) {
      final unit = out[i];
      if (!raw && unit == backslash) {
        blank(i);
        if (i + 1 < length) blank(i + 1);
        i += 2;
        continue;
      }
      if (!raw && unit == dollar && i + 1 < length && out[i + 1] == openBrace) {
        i = code(i + 2, true);
        continue;
      }
      if (unit == quote) {
        if (!triple) return i + 1;
        if (i + 2 < length && out[i + 1] == quote && out[i + 2] == quote) {
          return i + 3;
        }
      }
      if (!triple && unit == newline) return i + 1;
      blank(i);
      i++;
    }
    return i;
  }

  // Returns the index just after the matching `}` (or the end of input).
  code = (int start, bool untilBrace) {
    var depth = 0;
    var i = start;
    while (i < length) {
      final unit = out[i];
      final next = i + 1 < length ? out[i + 1] : -1;
      if (unit == slash && next == slash) {
        while (i < length && out[i] != newline) {
          blank(i);
          i++;
        }
      } else if (unit == slash && next == star) {
        var nesting = 0;
        while (i < length) {
          if (out[i] == slash && i + 1 < length && out[i + 1] == star) {
            nesting++;
            blank(i);
            blank(i + 1);
            i += 2;
          } else if (out[i] == star && i + 1 < length && out[i + 1] == slash) {
            nesting--;
            blank(i);
            blank(i + 1);
            i += 2;
            if (nesting == 0) break;
          } else {
            blank(i);
            i++;
          }
        }
      } else if ((unit == 0x72 || unit == 0x52) && isQuote(next)) {
        final before = i > 0 ? out[i - 1] : 0x20;
        final identifierChar = RegExp(
          r'[\w$]',
        ).hasMatch(String.fromCharCode(before));
        if (identifierChar) {
          i++;
        } else {
          i = string(i + 1, true);
        }
      } else if (isQuote(unit)) {
        i = string(i, false);
      } else if (untilBrace && unit == openBrace) {
        depth++;
        i++;
      } else if (untilBrace && unit == closeBrace) {
        if (depth == 0) return i + 1;
        depth--;
        i++;
      } else {
        i++;
      }
    }
    return i;
  };

  code(0, false);
  return String.fromCharCodes(out);
}
