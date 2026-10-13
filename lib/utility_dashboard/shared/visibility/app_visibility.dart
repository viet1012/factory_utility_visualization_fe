import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Route observer cua MaterialApp (main.dart). Chi theo doi PageRoute nen
/// dialog / popup khong tinh la "che man hinh".
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Trang thai hien thi chung cua ung dung:
/// - [pageVisible]: tab trinh duyet dang hien (document `visibilitychange`);
/// - [dashboardCovered]: man hinh dashboard dang bi route khac che
///   (Facility detail, Solar detail...), do dashboard bao qua RouteAware.
///
/// Polling dung cac co nay qua PollingCoordinator (xem
/// UtilityDashboardScreen).
class AppVisibility extends ChangeNotifier {
  AppVisibility._() {
    _pageVisible = !web.document.hidden;
    web.document.addEventListener('visibilitychange', _listener);
  }

  static final AppVisibility instance = AppVisibility._();

  late final JSFunction _listener = ((web.Event _) {
    _setPageVisible(!web.document.hidden);
  }).toJS;

  bool _pageVisible = true;
  bool _dashboardCovered = false;

  bool get pageVisible => _pageVisible;

  bool get dashboardCovered => _dashboardCovered;

  void _setPageVisible(bool visible) {
    if (_pageVisible == visible) return;

    _pageVisible = visible;
    notifyListeners();
  }

  void setDashboardCovered(bool covered) {
    if (_dashboardCovered == covered) return;

    _dashboardCovered = covered;
    notifyListeners();
  }
}
