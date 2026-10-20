// Flutter 기본 의존부가 함께 쓰는 루트 Navigator 찾기(SDK 내부용).
import 'package:flutter/widgets.dart';

/// 앱의 루트 [NavigatorState]다. `MaterialApp`·`CupertinoApp`·`WidgetsApp`이 만든 첫 Navigator를 찾는다. 없으면 null
NavigatorState? rootNavigator() {
  NavigatorState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is NavigatorState) {
      found = element.state as NavigatorState;
      return;
    }
    element.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return found;
}

/// 루트 Navigator 맨 위 화면의 이름이다(`RouteSettings.name`). 없으면 null
String? currentRouteName() {
  final navigator = rootNavigator();
  if (navigator == null) return null;
  String? name;
  // 맨 위 화면에서 바로 멈추므로 아무것도 닫지 않는다 — 맨 위 화면을 읽는 공개 API가 없어 이렇게 읽는다
  navigator.popUntil((route) {
    name = route.settings.name;
    return true;
  });
  return name;
}
