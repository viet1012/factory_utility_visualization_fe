import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/utility_data.dart';

class ApiService {
  // final String baseUrl = "http://F2PC24017:9999/api";

  final String baseUrl = "http://192.168.122.15:9092/api";

  Future<List<UtilityData>> fetchDetailsDataRF() async {
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
}
