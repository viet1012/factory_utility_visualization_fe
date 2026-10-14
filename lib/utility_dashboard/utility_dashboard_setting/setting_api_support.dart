import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Timeout moi request cua man Setting (khong dung receiveTimeout 90s mac
/// dinh cua DioClient).
const Duration kSettingRequestTimeout = Duration(seconds: 30);

/// Options cho request Setting. [withBody] = POST / PUT: Flutter Web khong ho
/// tro sendTimeout voi request khong co body (GET).
Options settingRequestOptions({bool withBody = false}) {
  return Options(
    receiveTimeout: kSettingRequestTimeout,
    sendTimeout: withBody || !kIsWeb ? kSettingRequestTimeout : null,
  );
}

/// Response phai la danh sach JSON.
List<dynamic> settingListOf(Response<dynamic> response) {
  final data = response.data;
  if (data is! List) {
    throw const FormatException('Invalid response format: expected a list');
  }
  return data;
}

/// Response phai la mot object JSON.
Map<String, dynamic> settingMapOf(Response<dynamic> response) {
  final data = response.data;
  if (data is! Map) {
    throw const FormatException('Invalid response format: expected an object');
  }
  return Map<String, dynamic>.from(data);
}

/// Thong bao loi cho SnackBar / dialog cua man Setting.
///
/// - 400 / 409 / 422: message trong body backend (key message, error,
///   detail);
/// - timeout: "Request timed out";
/// - khong ket noi duoc: "Cannot reach server";
/// - con lai: "Unexpected error (HTTP <code>)".
String settingErrorMessage(Object error) {
  if (error is! DioException) {
    if (error is FormatException) {
      return 'Unexpected error: ${error.message}';
    }
    return 'Unexpected error';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Request timed out';
    case DioExceptionType.connectionError:
      return 'Cannot reach server';
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final status = error.response?.statusCode;

  // Web / loi socket khong co response: khong toi duoc server.
  if (status == null) {
    return error.type == DioExceptionType.unknown
        ? 'Cannot reach server'
        : 'Unexpected error';
  }

  if (status == 400 || status == 409 || status == 422) {
    final message = _bodyMessage(error.response?.data);
    if (message != null) return message;
  }

  return 'Unexpected error (HTTP $status)';
}

String? _bodyMessage(dynamic data) {
  if (data is Map) {
    for (final key in const ['message', 'error', 'detail']) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  if (data is String) {
    final value = data.trim();
    return value.isEmpty ? null : value;
  }

  return null;
}
