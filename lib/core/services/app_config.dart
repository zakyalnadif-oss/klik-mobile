import 'dart:convert';

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.publishableKey});

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String supabaseUrl;
  final String publishableKey;

  bool get isMissing => supabaseUrl.isEmpty || publishableKey.isEmpty;

  String? get validationError {
    if (isMissing) return null;
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty) {
      return 'SUPABASE_URL harus berupa URL proyek yang valid.';
    }
    if (publishableKey.startsWith('sb_publishable_')) return null;
    try {
      final segments = publishableKey.split('.');
      if (segments.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
        );
        if (payload is Map && payload['role'] == 'anon') return null;
      }
    } on FormatException {
      // Invalid keys are reported without exposing the provided value.
    }
    return 'Gunakan publishable key atau legacy anon key untuk aplikasi mobile.';
  }
}
