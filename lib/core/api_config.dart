class ApiConfig {
  ApiConfig._();

  /// Override at build time:
  /// flutter run --dart-define=API_BASE_URL=https://xxxx.mockapi.io/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://6ae023e78e42963c8d5eed1b.mockapi.io/api/v1',
  );

  static const Duration timeout = Duration(seconds: 15);

  static bool get isConfigured => !baseUrl.contains('YOUR_PROJECT_ID');
}
