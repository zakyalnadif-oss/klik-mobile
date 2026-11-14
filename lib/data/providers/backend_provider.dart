import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/app_config.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final backendProvider = FutureProvider<SupabaseClient?>((ref) async {
  final config = ref.watch(appConfigProvider);
  if (config.isMissing) return null;
  final error = config.validationError;
  if (error != null) throw FormatException(error);
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.publishableKey,
  );
  return supabase.client;
});
