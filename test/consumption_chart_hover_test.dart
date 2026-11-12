import 'package:factory_utility_visualization/utility_dashboard/monitoring/electric_consumption/model/electric_consumption.dart';
import 'package:factory_utility_visualization/utility_dashboard/monitoring/electric_consumption/widgets/consumption_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hover vao chart (tooltip nhieu dong) khong duoc gay RenderFlex overflow,
/// ke ca khi chart thap (o luoi Charts ~200px).
void main() {
  Map<String, dynamic> values(double base) => {
    'normal': base * .55,
    'highPeak': base * .2,
    'lowPeak': base * .25,
    'solar': 5.4,
    'totalElectricity': base,
    'total': base + 5.4,
  };

  final response = ElectricConsumptionResponse.fromJson({
    'month': '2026-11',
    'billPeriod': {
      'label': 'Nov (Oct21 ~ Nov20]',
      'from': '2026-10-21',
      'to': '2026-11-21',
      'days': 31,
    },
    'dataUntil': '2026-11-12T10:00:00+07:00',
    'tariffAvailable': true,
    'scopes': [
      {
        'code': 'KVH',
        'name': 'TTL KVH: A&B + C',
        'completeDays': 19,
        'monthly': [
          for (final m in ['2026-07', '2026-08', '2026-09', '2026-10'])
            {
              'month': m,
              'label': 'Jul (Jun21 ~ Jul20]',
              'days': 30,
              'completeDays': 18,
              'excludedMwh': 3466.313,
              'perDayMwh': values(46),
              'perDayKusd': values(3.5),
            },
        ],
        'daily': [
          for (var d = 21; d <= 31; d++)
            {
              'date': '2026-10-$d',
              'weekday': 'Wed',
              'coveragePct': 92.7,
              'partial': d == 25,
              'mwh': values(48),
              'kusd': values(3.9),
            },
        ],
        'dailyTotalMwh': values(500),
        'dailyTotalKusd': values(40),
        'dailyAverageMwh': values(48),
        'dailyAverageKusd': values(3.9),
      },
    ],
  });

  for (final size in [const Size(560, 200), const Size(900, 320)]) {
    for (final unit in ConsumptionUnit.values) {
      testWidgets('hover ${unit.label} @ ${size.width}x${size.height}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: ConsumptionChart(
                    scope: response.scopes.single,
                    unit: unit,
                    tariffAvailable: true,
                    partialDate: response.partialDate,
                    partialUntil: response.partialUntil,
                    billLabel: 'Nov (Oct21 ~ Nov20]',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.getRect(find.byType(ConsumptionChart));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: box.topLeft);
        addTearDown(mouse.removePointer);

        // Quet ngang qua giua chart: cot monthly, daily, mep phai.
        for (final fx in [.12, .3, .5, .7, .9, .97]) {
          for (final fy in [.45, .7, .85]) {
            await mouse.moveTo(
              Offset(box.left + box.width * fx, box.top + box.height * fy),
            );
            await tester.pump(const Duration(milliseconds: 400));
            // Bam cung kich hoat tooltip (web / cam ung).
            await tester.tapAt(
              Offset(box.left + box.width * fx, box.top + box.height * fy),
            );
            await tester.pump(const Duration(milliseconds: 400));
          }
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
