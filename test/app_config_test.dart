import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:klik_mobile/core/services/app_config.dart';

void main() {
  AppConfig config(String key) => AppConfig(
    supabaseUrl: 'https://example.supabase.co',
    publishableKey: key,
  );
  String jwt(String role) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.signature';

  test('missing configuration is safe and distinguishable', () {
    const value = AppConfig(supabaseUrl: '', publishableKey: '');
    expect(value.isMissing, isTrue);
    expect(value.validationError, isNull);
  });
  test('accepts public client keys', () {
    expect(config('sb_publishable_example').validationError, isNull);
    expect(config(jwt('anon')).validationError, isNull);
  });
  test('rejects privileged and malformed keys', () {
    for (final key in ['sb_secret_example', jwt('service_role'), 'invalid']) {
      expect(config(key).validationError, isNotNull);
    }
  });
  test('rejects invalid and credential-bearing URLs', () {
    for (final url in [
      'not a url',
      'ftp://example.com',
      'https://user:pass@example.com',
    ]) {
      expect(
        AppConfig(
          supabaseUrl: url,
          publishableKey: 'sb_publishable_example',
        ).validationError,
        isNotNull,
      );
    }
  });
}
