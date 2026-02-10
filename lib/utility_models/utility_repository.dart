import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_history.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_master.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_scada_box.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_scada_channel.dart';

abstract class UtilityRepository {
  Future<List<UtilityScadaBox>> fetchBoxes();

  Future<List<UtilityScadaChannel>> fetchChannels();

  Future<List<UtilityParameterMaster>> fetchMasters();

  Future<List<UtilityParameterHistory>> fetchLatestHistories({
    DateTime? at,
    int seed = 1,
  });

  Future<List<UtilityParameterMaster>> fetchParamsFor({
    required String facId,
    required String utility,
  });
}
