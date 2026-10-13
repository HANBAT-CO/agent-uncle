import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// iOS에서는 Flutter 표준 가장자리 스와이프와 페이지 전환을 함께 사용한다.
/// 화면 내용과 하단 탭은 기존 TDS 위젯이 담당한다.
PageRoute<T> appPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPageRoute<T>(builder: builder, settings: settings);
  }
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}
