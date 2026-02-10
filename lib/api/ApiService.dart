import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../model/dashboard_response.dart';
import '../model/utility_data.dart';

class ApiService {
  ApiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? "http://192.168.122.15:9999/api";

  final http.Client _client;
  final String baseUrl;

  // =========================
  // Core HTTP helpers
  // =========================

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;

    return uri.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// ✅ Build URI có list params (fac=...&fac=...) + params thường (from/to)
  /// Vì Uri.replace() không support queryParametersAll => build query string thủ công
  Uri _buildUriWithList(
      String path,
      Map<String, List<String>> listParams, [
        Map<String, String>? singleParams,
      ]) {
    final parts = <String>[];

    // list params: fac=Fac A&fac=Fac B...
    listParams.forEach((key, values) {
      for (final v in values) {
        if (v.trim().isEmpty) continue;
        parts.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(v.trim())}',
        );
      }
    });

    // single params: from=...&to=...
    if (singleParams != null) {
      singleParams.forEach((k, v) {
        parts.add(
          '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v)}',
        );
      });
    }

    final qs = parts.join('&');
    final full = qs.isEmpty ? '$baseUrl$path' : '$baseUrl$path?$qs';
    return Uri.parse(full);
  }

  Future<dynamic> _getJson(Uri url) async {
    final res = await _client.get(url);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    return jsonDecode(res.body);
  }

  // =========================
  // APIs
  // =========================

  /// GET /utility/overview?fac=Fac%20A&fac=Fac%20B...
  Future<DashboardResponse> fetchDashboardOverview({
    List<String> facList = const ['Fac A', 'Fac B', 'Fac C'],
  }) async {
    final url = _buildUriWithList(
      '/utility/overview',
      {'fac': facList},
    );

    final json = await _getJson(url);
    return DashboardResponse.fromJson(json);
  }

  /// ✅ GET /utility/overview/range?fac=...&from=...&to=...
  Future<DashboardResponse> fetchDashboardOverviewInRange({
    required DateTime from,
    required DateTime to,
    List<String>? facList,
  }) async {
    // Backend Spring của bạn dùng LocalDateTime (không timezone)
    // => gửi dạng "yyyy-MM-ddTHH:mm:ss" cho chắc
    final singleParams = {
      'from': _toLocalIsoNoZone(from),
      'to': _toLocalIsoNoZone(to),
    };

    final url = (facList == null || facList.isEmpty)
        ? _buildUriWithList('/utility/overview/range', const {}, singleParams)
        : _buildUriWithList(
      '/utility/overview/range',
      {'fac': facList},
      singleParams,
    );
    debugPrint('🌐 GET $url');
    final json = await _getJson(url);
    return DashboardResponse.fromJson(json);
  }


  String _toLocalIsoNoZone(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${d.year.toString().padLeft(4, '0')}-'
        '${two(d.month)}-'
        '${two(d.day)}T'
        '${two(d.hour)}:'
        '${two(d.minute)}:'
        '${two(d.second)}';
  }

  void dispose() {
    _client.close();
  }
}
