import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/providers/backend_provider.dart';
import '../data/auth_api_client.dart';

/// Holds the currently logged-in user data (map) or null.
final sessionProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Provides the AuthApiClient singleton.
final authApiClientProvider = Provider<AuthApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthApiClient(config.apiBaseUrl);
});
