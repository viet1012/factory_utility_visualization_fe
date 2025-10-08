import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/dashboard_response.dart';
import '../model/facility_filtered.dart';
import '../model/utility_data.dart';

class ApiService {
  // final String baseUrl = "http://F2PC24017:9999/api";

  final String baseUrl = "http://192.168.122.15:9093/api";

  Future<DashboardResponse> fetchDashboardData() async {
    final response = await http.get(
      Uri.parse('http://localhost:8080/api/utility/overview'),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return DashboardResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load dashboard data');
    }
  }

  List<FacilityFiltered> getFacilitiesWithSignals(
    DashboardResponse data,
    List<String> plcAddresses,
  ) {
    final List<FacilityFiltered> result = [];

    for (var facility in data.facilities) {
      final filteredSignals = facility.signals
          .where((s) => plcAddresses.contains(s.plcAddress))
          .toList();

      if (filteredSignals.isNotEmpty) {
        result.add(
          FacilityFiltered(
            fac: facility.fac,
            facName: facility.facName,
            signals: filteredSignals,
          ),
        );
      }
    }

    return result;
  }

  Future<List<UtilityData>> fetchElectricalCabinets() async {
    final url = Uri.parse("$baseUrl/utility/latest");
    print("url: $url");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UtilityData.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print("Exception caught: $e");
      return [];
    }
  }

  /// Hàm fetch API trả về giá trị plcValue của D24
  Future<double?> fetchElectricValue() async {
    final url = Uri.parse("$baseUrl/utility/latest");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        // tìm D24
        final item = data.firstWhere(
          (e) => e["plcAddress"] == "D24",
          orElse: () => {},
        );
        if (item.isNotEmpty) {
          return double.tryParse(item["plcValue"].toString());
        }
      }
    } catch (e) {
      print("Error fetching D24: $e");
    }
    return null; // fallback
  }
}
