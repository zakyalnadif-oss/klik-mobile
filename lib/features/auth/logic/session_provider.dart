import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/providers/backend_provider.dart';
import '../data/session_repository.dart';

final sessionProvider = StreamProvider<User?>((ref) async* {
  final client = await ref.watch(backendProvider.future);
  if (client == null) {
    yield null;
    return;
  }
  yield* SessionRepository(client).watchUser();
});
