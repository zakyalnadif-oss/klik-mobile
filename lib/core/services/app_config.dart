class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
  );

  final String apiBaseUrl;

  bool get isMissing => apiBaseUrl.isEmpty;

  String? get validationError {
    if (isMissing) return null;
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme)) {
      return 'API_BASE_URL harus berupa URL yang valid.';
    }
    return null;
  }
}
