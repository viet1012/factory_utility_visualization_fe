enum TimeBucket { hour, day, month }

class UtilitySeriesRequest {
  final String facId;          // A/B/C
  final String utility;        // Electricity/Water/Compressed Air
  final String? scadaId;       // optional: A1/A2/B1...
  final String? deviceId;      // optional: boxDeviceId (A1_ELEC...)
  final String plcAddress;     // param key trong device (D1, D2...)
  final DateTime from;
  final DateTime to;
  final TimeBucket bucket;
  final int seed;

  const UtilitySeriesRequest({
    required this.facId,
    required this.utility,
    required this.plcAddress,
    required this.from,
    required this.to,
    required this.bucket,
    this.scadaId,
    this.deviceId,
    this.seed = 1,
  });
}
