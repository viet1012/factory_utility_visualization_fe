import 'package:factory_utility_visualization/utility_dashboard/shared/visibility/app_visibility.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_screen.dart';
import 'package:flutter/material.dart';

void main() {
  // debugPrintRebuildDirtyWidgets = true;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      showPerformanceOverlay: true,
      debugShowCheckedModeBanner: false,
      title: 'Utility Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Dashboard dung RouteAware de dung polling khi bi route khac che.
      navigatorObservers: [appRouteObserver],
      home: UtilityDashboardScreen(),
    );
  }
}
