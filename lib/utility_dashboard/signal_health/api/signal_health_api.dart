import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../utility_api/dio_client.dart';

/// Raw Excel payload returned by the Signal Health export endpoint.
class SignalHealthExportFile {
  final Uint8List bytes;

  /// Filename taken from `Content-Disposition`, or a safe fallback.
  final String filename;

  const SignalHealthExportFile({required this.bytes, required this.filename});
}

class SignalHealthApi {
  SignalHealthApi();

  static const String _signalHealthMatrixPath =
      '/api/utility/signal-health-matrix';

  static const String _exportPath = '/api/utility/export';

  static const String _fallbackExportFilename = 'utility-signal-health.xlsx';

  static const String xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Dio get _dio => DioClient.dio;

  Future<List<Map<String, dynamic>>> getSignalHealthMatrix() async {
    final response = await _dio.get<dynamic>(_signalHealthMatrixPath);

    return _parseMapList(
      response.data,
      errorMessage: 'Invalid signal health matrix response',
    );
  }

  /// Downloads the Signal Health export as raw .xlsx bytes.
  ///
  /// Deliberately NOT parsed as JSON: [ResponseType.bytes] keeps the binary
  /// payload intact, since decoding it as text would corrupt the archive.
  Future<SignalHealthExportFile> getSignalHealthExport() async {
    final response = await _dio.get<List<int>>(
      _exportPath,
      options: Options(responseType: ResponseType.bytes),
    );

    final data = response.data;

    if (data == null || data.isEmpty) {
      throw const FormatException('Empty signal health export response');
    }

    return SignalHealthExportFile(
      bytes: Uint8List.fromList(data),
      filename: _filenameFromHeaders(response.headers),
    );
  }

  /// Extracts the filename from `Content-Disposition`.
  ///
  /// Handles both quoted and bare forms, and RFC 5987 `filename*`, falling back
  /// to [_fallbackExportFilename]. The backend already timestamps the name, so
  /// no timestamp is generated here.
  String _filenameFromHeaders(Headers headers) {
    final disposition = headers.value('content-disposition');

    if (disposition == null || disposition.trim().isEmpty) {
      return _fallbackExportFilename;
    }

    // Prefer RFC 5987 filename*=UTF-8''<encoded> when present.
    final extended = RegExp(
      r"filename\*\s*=\s*[^']*'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);

    if (extended != null) {
      final decoded = _safeDecode(extended.group(1)!.trim());
      if (decoded.isNotEmpty) return decoded;
    }

    final quoted = RegExp(
      r'filename\s*=\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(disposition);

    if (quoted != null) {
      final name = _sanitizeFilename(quoted.group(1)!);
      if (name.isNotEmpty) return name;
    }

    final bare = RegExp(
      r'filename\s*=\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(disposition);

    if (bare != null) {
      final name = _sanitizeFilename(bare.group(1)!);
      if (name.isNotEmpty) return name;
    }

    return _fallbackExportFilename;
  }

  String _safeDecode(String value) {
    try {
      return _sanitizeFilename(Uri.decodeComponent(value));
    } catch (_) {
      return _sanitizeFilename(value);
    }
  }

  /// Strips quotes and any path separators so the browser cannot be handed a
  /// traversal-style name from the header.
  String _sanitizeFilename(String value) {
    final trimmed = value.trim().replaceAll('"', '').trim();

    if (trimmed.isEmpty) return '';

    return trimmed.split(RegExp(r'[/\\]')).last.trim();
  }

  List<Map<String, dynamic>> _parseMapList(
    dynamic raw, {
    required String errorMessage,
  }) {
    if (raw is! List) {
      throw FormatException(errorMessage);
    }

    final result = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }

    return List<Map<String, dynamic>>.unmodifiable(result);
  }
}
