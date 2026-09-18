import 'dart:convert';

import '../models/utility_para.dart';
import '../models/utility_para_tree_models.dart';
import 'package:http/http.dart' as http;

class UtilityParaApi {
  final String baseUrl;
  final http.Client _client;

  UtilityParaApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<UtilityPara>> getAll() async {
    final res = await _client.get(_uri('/api/v1/utility-para'));
    final body = jsonDecode(res.body);
    return (body as List).map((e) => UtilityPara.fromJson(e)).toList();
  }

  Future<List<UtilityParaTreeFac>> getGroupedByFacWithParas() async {
    final response = await _client.get(
      _uri('/api/v1/utility-para/grouped-by-fac-with-paras'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'API error: ${response.statusCode} ${response.reasonPhrase}\n${response.body}',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! List) {
      throw Exception('Invalid response format: expected a list');
    }

    return body
        .map(
          (e) =>
              UtilityParaTreeFac.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<UtilityPara> create(UtilityPara item) async {
    final res = await _client.post(
      _uri('/api/v1/utility-para'),
      body: jsonEncode(item.toJson()..remove('id')),
      headers: {'Content-Type': 'application/json'},
    );
    return UtilityPara.fromJson(jsonDecode(res.body));
  }

  Future<UtilityPara> update(int id, UtilityPara item) async {
    final res = await _client.put(
      _uri('/api/v1/utility-para/$id'),
      body: jsonEncode(item.toJson()..remove('id')),
      headers: {'Content-Type': 'application/json'},
    );
    return UtilityPara.fromJson(jsonDecode(res.body));
  }

  void dispose() => _client.close();
}
