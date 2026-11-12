import 'package:factory_utility_visualization/utility_dashboard/monitoring/electric_consumption/model/electric_consumption.dart';
import 'package:factory_utility_visualization/utility_dashboard/monitoring/electric_consumption/widgets/consumption_detail_table.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nhan nhom ("Avg / day", ky, "This period") khong duoc bi
/// cat giua chu khi bang cuon ngang (bang tu cuon toi phan daily luc mo).
void main() {
  Map<String, dynamic> values(double v) => {
    'normal': v * .55,
    'highPeak': v * .2,
    'lowPeak': v * .25,
    'solar': 5.0,
    'totalElectricity': v,
    'total': v + 5,
  };

  final scope = ConsumptionScope.fromJson({
    'code': 'KVH',
    'name': 'TTL KVH: A&B + C',
    'monthly': [
      for (final m in ['2026-07', '2026-08', '2026-09', '2026-10'])
        {'month': m, 'days': 30, 'perDayMwh': values(42)},
    ],
    'daily': [
      for (var d = 1; d <= 31; d++)
        {
          'date': '2026-10-${d.toString().padLeft(2, '0')}',
          'weekday': 'Mon',
          'mwh': values(48),
        },
    ],
    'dailyTotalMwh': values(1000),
    'dailyAverageMwh': values(48),
  });

  // "This period" nam o khoi ghim ben phai, khong thuoc vung cuon.
  const groupLabels = ['Avg / day', 'Nov (Oct21 ~ Nov20]'];

  /// Moi nhan nhom dang hien phai nam tron trong khung cuon ngang.
  void expectLabelsInsideViewport(WidgetTester tester) {
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    var shown = 0;
    for (final label in groupLabels) {
      // Chi tim trong vung cuon (cot ghim ben phai cung co "Avg / day").
      final finder = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text(label),
      );
      if (finder.evaluate().isEmpty) continue;
      shown++;
      final rect = tester.getRect(finder);
      expect(
        rect.left,
        greaterThanOrEqualTo(viewport.left - .5),
        reason: label,
      );
      expect(rect.right, lessThanOrEqualTo(viewport.right + .5), reason: label);
    }
    expect(shown, greaterThan(0));
  }

  testWidgets('group labels stay inside the visible area while scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: ConsumptionDetailTable(
              scope: scope,
              unit: ConsumptionUnit.mwh,
              tariffAvailable: true,
              unitPrices: null,
              billLabel: 'Nov (Oct21 ~ Nov20]',
              partialDate: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Luc mo: bang da tu cuon toi phan daily.
    // Bang mo o ngay moi nhat: nhom monthly co the ngoai tam nhin (nhan an).
    expectLabelsInsideViewport(tester);

    final scroll = find.byType(SingleChildScrollView);
    for (final dx in [-300.0, -600.0, 400.0, 2000.0]) {
      await tester.drag(scroll, Offset(dx, 0));
      await tester.pumpAndSettle();
      expectLabelsInsideViewport(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('table scrolls horizontally by mouse drag and arrow buttons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: ConsumptionDetailTable(
              scope: scope,
              unit: ConsumptionUnit.mwh,
              tariffAvailable: true,
              unitPrices: null,
              billLabel: 'Nov (Oct21 ~ Nov20]',
              partialDate: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(SingleChildScrollView);
    final controller = tester
        .widget<SingleChildScrollView>(scrollable)
        .controller!;
    double offset() => controller.offset;

    // Bang mo o ngay moi nhat (cuoi bang): ve dau truoc khi thu cuon.
    controller.jumpTo(0);
    await tester.pumpAndSettle();

    // Keo bang chuot (web / desktop) sang trai -> cuon sang phai.
    final before = offset();
    await tester.drag(
      scrollable,
      const Offset(-250, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(before));

    // Nut ▶ / ◀.
    final afterDrag = offset();
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(afterDrag));

    final afterRight = offset();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    expect(offset(), lessThan(afterRight));

    expect(tester.takeException(), isNull);
  });

  testWidgets('opens at today, Today button returns, totals stay pinned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: ConsumptionDetailTable(
              scope: scope,
              unit: ConsumptionUnit.mwh,
              tariffAvailable: true,
              unitPrices: null,
              billLabel: 'Nov (Oct21 ~ Nov20]',
              // Ngay dang chay giua ky.
              partialDate: '2026-10-12',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    void expectTodayVisible() {
      // Tieu de cot hom nay (nut "Today" tren tieu de bang khong tinh).
      final today = tester.getRect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text('Today'),
        ),
      );
      expect(today.left, greaterThanOrEqualTo(viewport.left));
      expect(today.right, lessThanOrEqualTo(viewport.right));
    }

    // Mo bang: cot hom nay (Oct 12) trong tam nhin.
    expectTodayVisible();

    // Cot Total / Avg / day ghim: luon hien, nam ben phai vung cuon.
    final total = tester.getRect(find.text('Total'));
    expect(total.left, greaterThanOrEqualTo(viewport.right - .5));

    // Cuon ve dau roi bam "Today": quay lai hom nay; cot ghim khong doi.
    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Total')), total);

    // Nut "Today" (TextButton.icon la lop con rieng -> tim theo icon).
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();
    expectTodayVisible();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Amount table shows unit price inside the row label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pump(ConsumptionUnit unit) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: ConsumptionDetailTable(
              scope: scope,
              unit: unit,
              tariffAvailable: true,
              unitPrices: const UnitPrices(
                gridNormal: 0.0758,
                gridHighPeak: 0.1405,
                gridLowPeak: 0.0492,
              ),
              billLabel: 'Nov (Oct21 ~ Nov20]',
              partialDate: null,
            ),
          ),
        ),
      ),
    );

    await pump(ConsumptionUnit.kusd);
    await tester.pumpAndSettle();
    expect(find.text(r'$/kWh'), findsOneWidget);
    expect(find.text('0.0758'), findsOneWidget);
    expect(find.text('0.1405'), findsOneWidget);
    expect(find.text('0.0492'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Bang MWh: khong con cot Unit lap "MWh" moi dong.
    await pump(ConsumptionUnit.mwh);
    await tester.pumpAndSettle();
    expect(find.text('MWh'), findsNothing);
    expect(find.text(r'$/kWh'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
