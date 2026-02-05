import '../model/dashboard_response.dart';
import '../api/ApiService.dart';
import 'facility_provider_base.dart';

class FacilityRealtimeProvider extends FacilityProviderBase {
  FacilityRealtimeProvider({ApiService? api, bool debugLog = false})
      : super(api: api, debugLog: debugLog);

  @override
  Future<DashboardResponse> loadDashboard({
    required List<String> plcAddresses,
  }) {
    // realtime dùng /utility/overview
    return api.fetchDashboardOverview();
  }
}
