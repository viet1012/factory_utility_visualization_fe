import 'dart:convert';

import 'package:http/http.dart' as http;

import 'utility_dashboard_setting_models/utility_scada.dart';

class UtilityScadaApi {
  final String baseUrl;
  final http.Client _client;

  UtilityScadaApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Uri _uri([String path = '']) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final normalizedPath = path.isEmpty
        ? ''
        : (path.startsWith('/') ? path : '/$path');

    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, String> get _headers => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<UtilityScada>> getAll() async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw Exception('Invalid response format: expected a list');
    }

    return body
        .map((e) => UtilityScada.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<UtilityScada> getById(int id) async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada/$id'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    return UtilityScada.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<UtilityScada> create(UtilityScada item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _client.post(
      _uri('/api/v1/utility-scada'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    _ensureSuccess(response, allowedStatusCodes: {200, 201});

    final body = jsonDecode(response.body);
    return UtilityScada.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<UtilityScada> update(int id, UtilityScada item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _client.put(
      _uri('/api/v1/utility-scada/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    _ensureSuccess(response, allowedStatusCodes: {200, 201});

    final body = jsonDecode(response.body);
    return UtilityScada.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(
      _uri('/api/v1/utility-scada/$id'),
      headers: _headers,
    );

    _ensureSuccess(response, allowedStatusCodes: {200, 204});
  }

  Future<UtilityScada> getByScadaId(String scadaId) async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada/scada/$scadaId'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    return UtilityScada.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<List<UtilityScada>> getByFac(String fac) async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada/fac/$fac'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw Exception('Invalid response format: expected a list');
    }

    return body
        .map((e) => UtilityScada.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<UtilityScada>> getByConnected(bool connected) async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada/connected/$connected'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw Exception('Invalid response format: expected a list');
    }

    return body
        .map((e) => UtilityScada.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<UtilityScada>> getByAlert(bool alert) async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada/alert/$alert'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw Exception('Invalid response format: expected a list');
    }

    return body
        .map((e) => UtilityScada.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void dispose() {
    _client.close();
  }

  void _ensureSuccess(
    http.Response response, {
    Set<int> allowedStatusCodes = const {200},
  }) {
    if (!allowedStatusCodes.contains(response.statusCode)) {
      throw Exception(
        'API error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}',
      );
    }
  }
}
