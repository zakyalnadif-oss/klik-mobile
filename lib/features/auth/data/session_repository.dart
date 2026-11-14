import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class SessionRepository {
  SessionRepository(this._client);

  final SupabaseClient _client;

  Stream<User?> watchUser() => Stream<User?>.multi((controller) {
    final subscription = _client.auth.onAuthStateChange.listen(
      (event) => controller.add(event.session?.user),
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_client.auth.currentUser);
    controller.onCancel = subscription.cancel;
  });
}
