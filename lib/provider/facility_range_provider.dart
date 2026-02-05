import '../model/dashboard_response.dart';
import '../api/ApiService.dart';
import 'facility_provider_base.dart';

class FacilityRangeProvider extends FacilityProviderBase {
  FacilityRangeProvider({
    ApiService? api,
    bool debugLog = false,
    this.facList,
    required this.from,
    required this.to,
  }) : super(api: api, debugLog: debugLog);

  /// optional filter fac
  final List<String>? facList;

  /// range cố định (nếu muốn “trượt”, bạn update từ/to từ widget)
  DateTime from;
  DateTime to;

  void setRange(DateTime newFrom, DateTime newTo) {
    from = newFrom;
    to = newTo;
    // gọi lại nếu muốn refresh ngay
    // unawaited(fetchFacilities(facilities...)) -> không có plc list ở đây nên thường widget sẽ gọi fetch
  }

  @override
  Future<DashboardResponse> loadDashboard({
    required List<String> plcAddresses,
  }) {
    return api.fetchDashboardOverviewInRange(
      from: from,
      to: to,
      facList: facList,
    );
  }
}
