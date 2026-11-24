import 'package:flutter_test/flutter_test.dart';
import 'package:klik_mobile/core/services/app_config.dart';

void main() {
  test('missing configuration is safe and distinguishable', () {
    const value = AppConfig(apiBaseUrl: '');
    expect(value.isMissing, isTrue);
    expect(value.validationError, isNull);
  });

  test('accepts valid URL', () {
    const value = AppConfig(apiBaseUrl: 'http://localhost:8080');
    expect(value.isMissing, isFalse);
    expect(value.validationError, isNull);
  });

  test('accepts https URL', () {
    const value = AppConfig(apiBaseUrl: 'https://api.example.com');
    expect(value.isMissing, isFalse);
    expect(value.validationError, isNull);
  });

  test('rejects invalid URL', () {
    for (final url in ['not a url', 'ftp://example.com']) {
      expect(
        AppConfig(apiBaseUrl: url).validationError,
        isNotNull,
      );
    }
  });
}
