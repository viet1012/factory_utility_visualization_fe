import 'package:dio/dio.dart';

import 'alarm_event.dart';

class AlarmApi {
  final Dio dio;

  AlarmApi(this.dio);

  /// TODO: đổi endpoint theo backend của bạn
  /// gợi ý: GET /api/utility/alarms?facId=&cate=&acked=&q=
  Future<List<AlarmEvent>> fetchAlarms({
    String? facId,
    String? cate,
    bool? acked,
    String? q,
  }) async {
    // ======= MOCK tạm để UI chạy ngay =======
    final now = DateTime.now();
    return [
      AlarmEvent(
        id: 'A1',
        ts: now.subtract(const Duration(minutes: 2)),
        facId: 'Fac_B',
        cate: 'Electricity',
        boxDeviceId: 'DPB-L2-PANNEL_CB-80A',
        plcAddress: 'D18',
        severity: AlarmSeverity.warning,
        message: 'High current threshold warning',
        value: 19.5,
        unit: 'A',
      ),
      AlarmEvent(
        id: 'A2',
        ts: now.subtract(const Duration(minutes: 8)),
        facId: 'Fac_A',
        cate: 'Electricity',
        boxDeviceId: 'MAIN-PANEL',
        plcAddress: 'D30',
        severity: AlarmSeverity.offline,
        message: 'No data (stale > 2m)',
        acked: true,
        ackBy: 'operator',
        ackAt: now.subtract(const Duration(minutes: 6)),
      ),
    ];

    // ======= nếu backend có rồi thì dùng đoạn dưới =======
    // final res = await dio.get(
    //   '/api/utility/alarms',
    //   queryParameters: {
    //     if (facId != null) 'facId': facId,
    //     if (cate != null) 'cate': cate,
    //     if (acked != null) 'acked': acked ? 1 : 0,
    //     if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    //   },
    // );
    // final data = (res.data as List).cast<Map<String, dynamic>>();
    // return data.map((j) => AlarmEvent(...)).toList();
  }

  /// TODO: backend: POST /api/utility/alarms/{id}/ack
  Future<void> ackAlarm(String id, {String? ackBy}) async {
    // MOCK: do nothing
    // await dio.post('/api/utility/alarms/$id/ack', data: {'ackBy': ackBy});
  }
}
