/// Base URL cua backend, doi khi build / chay bang --dart-define:
///
/// ```text
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:9999
/// ```
///
/// build_web.bat truyen bien moi truong API_BASE_URL (neu co) vao
/// --dart-define; khong dat thi dung [defaultValue] (production).
///
/// Noi duy nhat khai bao dia chi backend; DioClient va moi API doc tu day.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.122.16:9093',
);
