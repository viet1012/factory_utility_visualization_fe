import '../f2_utility_parameter_master.dart';
import '../f2_utility_scada_box.dart';
import '../f2_utility_scada_channel.dart';
import 'latest_record.dart';

class UtilityCatalogDto {
  final List<ScadaDto> scadas;
  final List<ScadaChannelDto> channels;
  final List<ParamDto> params;
  final List<LatestRecordDto> latest;

  UtilityCatalogDto({
    required this.scadas,
    required this.channels,
    required this.params,
    required this.latest,
  });

  factory UtilityCatalogDto.fromJson(Map<String, dynamic> j) =>
      UtilityCatalogDto(
        scadas: (j['scadas'] as List? ?? [])
            .map((e) => ScadaDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        channels: (j['channels'] as List? ?? [])
            .map((e) => ScadaChannelDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        params: (j['params'] as List? ?? [])
            .map((e) => ParamDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        latest: (j['latest'] as List? ?? [])
            .map((e) => LatestRecordDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
