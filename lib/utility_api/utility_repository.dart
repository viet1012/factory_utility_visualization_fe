import 'package:dio/dio.dart';

import '../utility_models/f2_utility_parameter_history.dart';
import '../utility_models/f2_utility_parameter_master.dart';
import '../utility_models/f2_utility_scada_box.dart';
import '../utility_models/f2_utility_scada_channel.dart';
import '../utility_models/request/utility_series_request.dart';
import '../utility_models/utility_repository.dart';

class UtilityApiRepository implements UtilityRepository {
  final Dio dio;

  UtilityApiRepository(this.dio);

  @override
  Future<List<UtilityScadaBox>> fetchBoxes() async {
    final res = await dio.get('/api/utility/boxes');
    return (res.data as List).map((j) => UtilityScadaBox.fromJson(j)).toList();
  }

  @override
  Future<List<UtilityScadaChannel>> fetchChannels() async {
    final res = await dio.get('/api/utility/channels');
    return (res.data as List)
        .map((j) => UtilityScadaChannel.fromJson(j))
        .toList();
  }

  @override
  Future<List<UtilityParameterMaster>> fetchMasters() async {
    final res = await dio.get('/api/utility/masters');
    return (res.data as List)
        .map((j) => UtilityParameterMaster.fromJson(j))
        .toList();
  }

  @override
  Future<List<UtilityParameterHistory>> fetchLatestHistories({
    DateTime? at,
    int seed = 1,
  }) async {
    final res = await dio.get(
      '/api/utility/histories/latest',
      queryParameters: {if (at != null) 'at': at.toIso8601String()},
    );
    return (res.data as List)
        .map((j) => UtilityParameterHistory.fromJson(j))
        .toList();
  }

  Future<List<UtilityParameterHistory>> fetchSeries(
    UtilitySeriesRequest req,
  ) async {
    final res = await dio.get(
      '/api/utility/histories/series',
      queryParameters: {
        'facId': req.facId,
        'utility': req.utility,
        if (req.deviceId != null) 'deviceId': req.deviceId,
        if (req.scadaId != null) 'scadaId': req.scadaId,
        'plcAddress': req.plcAddress,
        'from': req.from.toIso8601String(),
        'to': req.to.toIso8601String(),
        'bucket': req.bucket.name,
      },
    );
    return (res.data as List)
        .map((j) => UtilityParameterHistory.fromJson(j))
        .toList();
  }

  @override
  Future<List<UtilityParameterMaster>> fetchParamsFor({
    required String facId,
    required String utility,
  }) async {
    final res = await dio.get(
      '/api/utility/params',
      queryParameters: {'facId': facId, 'utility': utility},
    );
    return (res.data as List)
        .map((j) => UtilityParameterMaster.fromJson(j))
        .toList();
  }
}
