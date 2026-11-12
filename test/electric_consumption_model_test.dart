import 'package:factory_utility_visualization/utility_dashboard/monitoring/electric_consumption/model/electric_consumption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('billMonthOf', () {
    test('day 1..20 belongs to the same month', () {
      expect(billMonthOf(DateTime(2026, 9, 20)), DateTime(2026, 9));
      expect(billMonthOf(DateTime(2026, 9, 1)), DateTime(2026, 9));
    });

    test('day 21+ belongs to the next month, across years', () {
      expect(billMonthOf(DateTime(2026, 8, 21)), DateTime(2026, 9));
      expect(billMonthOf(DateTime(2026, 12, 25)), DateTime(2027, 1));
    });

    test('format / parse round trip', () {
      expect(formatBillMonth(DateTime(2026, 9)), '2026-09');
      expect(parseBillMonth('2026-09'), DateTime(2026, 9));
      expect(parseBillMonth('abc'), isNull);
    });
  });

  test('parses response with monthly, daily and null days', () {
    final response = ElectricConsumptionResponse.fromJson({
      'month': '2026-09',
      'billPeriod': {
        'label': 'Sep (Aug21 ~ Sep20]',
        'from': '2026-08-21',
        'to': '2026-09-21',
        'days': 31,
      },
      'dataUntil': '2026-09-21T00:00:00+07:00',
      'tariffAvailable': true,
      'unitPrices': {'gridNormal': 0.0758},
      'scopes': [
        {
          'code': 'KVH',
          'name': 'TTL KVH: A&B + C',
          'monthly': [
            {
              'month': '2026-08',
              'label': 'Aug (Jul21 ~ Aug20]',
              'days': 31,
              'perDayMwh': {'normal': 23.918, 'total': 49.253},
              'perDayKusd': {'total': 3.971},
            },
          ],
          'daily': [
            {
              'date': '2026-08-21',
              'weekday': 'Fri',
              'mwh': {'solar': 6.4, 'total': 49.6},
              'kusd': {'total': 4.001},
            },
            {'date': '2026-09-20', 'weekday': 'Sun', 'mwh': null, 'kusd': null},
          ],
          'dailyTotalMwh': {'total': 1526.9},
          'elapsedDays': 31,
        },
        {'code': 'FAC_C', 'name': 'Fac C'},
      ],
    });

    expect(response.billPeriod.days, 31);
    expect(response.unitPrices?.gridNormal, 0.0758);
    expect(response.scopes, hasLength(2));

    final kvh = response.scopes.first;
    expect(kvh.includesSolar, isTrue);
    expect(kvh.points.map((p) => p.key), [
      '2026-08',
      '2026-08-21',
      '2026-09-20',
    ]);
    expect(kvh.monthly.single.isMonthly, isTrue);
    expect(kvh.monthly.single.mwh?.total, 49.253);
    expect(kvh.daily.first.mwh?.solar, 6.4);
    expect(kvh.daily.last.hasData, isFalse);
    expect(kvh.totalOf(ConsumptionUnit.mwh)?.total, 1526.9);

    final facC = response.scopes.last;
    expect(facC.includesSolar, isFalse);
    expect(facC.points, isEmpty);

    // dataUntil 00:00 -> khong co ngay do dang.
    expect(response.partialDate, isNull);
  });

  group('no-data months, partial day, full-day average', () {
    final zeros = {
      'normal': 0.0,
      'highPeak': 0.0,
      'lowPeak': 0.0,
      'solar': 0.0,
      'totalElectricity': 0.0,
      'total': 0.0,
    };

    final response = ElectricConsumptionResponse.fromJson({
      'month': '2026-11',
      'billPeriod': {'from': '2026-10-21', 'to': '2026-11-21', 'days': 31},
      'dataUntil': '2026-11-12T09:00:00+07:00',
      'tariffAvailable': true,
      'scopes': [
        {
          'code': 'KVH',
          'name': 'TTL KVH: A&B + C',
          'monthly': [
            {'month': '2026-03', 'perDayMwh': zeros, 'perDayKusd': zeros},
            {
              'month': '2026-04',
              'perDayMwh': {'total': 3.382},
              'perDayKusd': {'total': 0.234},
            },
          ],
          'daily': [
            {
              'date': '2026-11-10',
              'mwh': {'total': 50.0, 'totalElectricity': 44.0},
            },
            {
              'date': '2026-11-11',
              'mwh': {'total': 52.0, 'totalElectricity': 46.0},
            },
            {
              'date': '2026-11-12',
              'mwh': {'total': 16.77, 'totalElectricity': 15.0},
            },
            {'date': '2026-11-13', 'mwh': null, 'kusd': null},
          ],
        },
      ],
    });
    final kvh = response.scopes.single;

    test('all-zero past period is treated as not recorded', () {
      expect(kvh.monthly[0].isNoData, isTrue);
      expect(kvh.monthly[0].valuesOf(ConsumptionUnit.mwh), isNull);
      expect(kvh.monthly[0].rawValuesOf(ConsumptionUnit.mwh), isNotNull);
      expect(kvh.monthly[1].isNoData, isFalse);
    });

    test('dataUntil mid-day marks that day partial', () {
      expect(response.partialDate, '2026-11-12');
      expect(response.partialUntil, '09:00');
    });

    test('average uses complete days only', () {
      expect(kvh.fullDays(response.partialDate).map((p) => p.key), [
        '2026-11-10',
        '2026-11-11',
      ]);
      expect(
        kvh.fullDayAverage(ConsumptionUnit.mwh, response.partialDate),
        51.0,
      );
      // Khong co ngay do dang: tinh ca 3 ngay.
      expect(
        kvh.fullDayAverage(ConsumptionUnit.mwh, null),
        closeTo(39.59, .01),
      );
    });
  });

  group('backend quality fields (partial / coverage / completeDays)', () {
    final response = ElectricConsumptionResponse.fromJson({
      'month': '2026-11',
      'billPeriod': {'from': '2026-10-21', 'to': '2026-11-21', 'days': 31},
      'dataUntil': '2026-11-12T10:00:00+07:00',
      'tariffAvailable': true,
      'minCoveragePct': 98,
      'historyStartDate': '2026-06-21',
      'excludedMeters': ['P-3.1_MFM384'],
      'scopes': [
        {
          'code': 'KVH',
          'name': 'TTL KVH: A&B + C',
          'completeDays': 1,
          'monthly': [
            {
              'month': '2026-06',
              'days': 31,
              'partial': true,
              'perDayMwh': null,
              'perDayKusd': null,
            },
            {
              'month': '2026-07',
              'days': 30,
              'completeDays': 18,
              'daysWithData': 30,
              'partial': true,
              'excludedMwh': 3466.313,
              'perDayMwh': {'total': 42.292},
            },
          ],
          'daily': [
            {
              'date': '2026-11-04',
              'partial': false,
              'coveragePct': 98.2,
              'mwh': {'total': 50.0},
            },
            {
              'date': '2026-11-05',
              'partial': true,
              'coveragePct': 92.7,
              'mwh': {'total': 51.0},
            },
            {
              'date': '2026-11-12',
              'partial': true,
              'coveragePct': 41.7,
              'mwh': {'total': 19.2},
            },
            {'date': '2026-11-13', 'partial': false, 'mwh': null},
          ],
        },
      ],
    });
    final kvh = response.scopes.single;

    test('parses response-level notes', () {
      expect(response.minCoveragePct, 98);
      expect(response.historyStartDate, '2026-06-21');
      expect(response.excludedMeters, ['P-3.1_MFM384']);
      expect(kvh.completeDays, 1);
    });

    test('monthly null values = no data; monthly never partial', () {
      expect(kvh.monthly[0].isNoData, isTrue);
      expect(kvh.monthly[1].completeDays, 18);
      expect(kvh.monthly[1].excludedMwh, 3466.313);
      expect(kvh.monthly[1].isPartial(response.partialDate), isFalse);
    });

    test('backend partial flag wins over dataUntil', () {
      final days = {for (final p in kvh.daily) p.key: p};
      expect(days['2026-11-04']!.isPartial(response.partialDate), isFalse);
      expect(days['2026-11-05']!.isPartial(response.partialDate), isTrue);
      expect(days['2026-11-12']!.isPartial(response.partialDate), isTrue);
      expect(days['2026-11-13']!.isPartial(response.partialDate), isFalse);
      expect(days['2026-11-05']!.coveragePct, 92.7);

      expect(kvh.fullDays(response.partialDate).map((p) => p.key), [
        '2026-11-04',
      ]);
      expect(kvh.partialDays(response.partialDate), hasLength(2));
      expect(
        kvh.fullDayAverage(ConsumptionUnit.mwh, response.partialDate),
        50.0,
      );
    });
  });
}
