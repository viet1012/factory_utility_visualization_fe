import 'dart:convert';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_models/utility_scada_channel.dart';
import 'package:http/http.dart' as http;

class UtilityScadaChannelApi {
  final String baseUrl;
  final http.Client _client;

  UtilityScadaChannelApi({required this.baseUrl, http.Client? client})
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

  Future<List<UtilityScadaChannel>> getAll() async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada-channels'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw Exception('Invalid response format: expected a list');
    }

    return body
        .map(
          (e) =>
              UtilityScadaChannel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<UtilityScadaChannel> getById(int id) async {
    final response = await _client.get(
      _uri('/api/v1/utility-scada-channels/$id'),
      headers: _headers,
    );

    _ensureSuccess(response);

    final body = jsonDecode(response.body);
    return UtilityScadaChannel.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<UtilityScadaChannel> create(UtilityScadaChannel item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _client.post(
      _uri('/api/v1/utility-scada-channels'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    _ensureSuccess(response, allowedStatusCodes: {200, 201});

    final body = jsonDecode(response.body);
    return UtilityScadaChannel.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<UtilityScadaChannel> update(int id, UtilityScadaChannel item) async {
    final payload = Map<String, dynamic>.from(item.toJson())..remove('id');

    final response = await _client.put(
      _uri('/api/v1/utility-scada-channels/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    _ensureSuccess(response, allowedStatusCodes: {200, 201});

    final body = jsonDecode(response.body);
    return UtilityScadaChannel.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(
      _uri('/api/v1/utility-scada-channels/$id'),
      headers: _headers,
    );

    _ensureSuccess(response, allowedStatusCodes: {200, 204});
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
