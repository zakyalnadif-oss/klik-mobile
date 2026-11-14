import 'dart:async';
import 'dart:convert';

import '../models/local_record.dart';

/// Commits a record only after durable storage succeeds, serializing mutations.
class RecordQueue {
  Future<void> _pending = Future.value();
  Future<void> apply({
    required Map<String, dynamic> Function() current,
    required void Function(Map<String, dynamic>) update,
    required Future<void> Function(Map<String, dynamic>) save,
    required void Function(Map<String, dynamic>) commit,
  }) {
    final result = Completer<void>();
    _pending = _pending.then((_) async {
      try {
        final next = jsonDecode(jsonEncode(current())) as Map<String, dynamic>;
        update(next);
        LocalRecord.validate(next);
        await save(next);
        commit(next);
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }
}
