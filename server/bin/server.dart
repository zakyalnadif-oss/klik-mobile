import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

late final Map<String, dynamic> _config;
late Connection _db;

Future<void> main() async {
  final localConfig = File('config.local.json');
  final configFile = localConfig.existsSync() ? localConfig : File('config.json');
  if (!configFile.existsSync()) {
    print('❌ config.local.json tidak ditemukan. Salin config.example.json lalu isi kredensial PostgreSQL.');
    exit(1);
  }
  _config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;

  final dbHost = _config['DB_HOST'] as String? ?? 'localhost';
  final dbPort = _config['DB_PORT'] as int? ?? 5432;
  final dbName = _config['DB_NAME'] as String? ?? 'klik_db';
  final dbUser = _config['DB_USERNAME'] as String? ?? 'postgres';
  final dbPass = _config['DB_PASSWORD'] as String? ?? '';
  final serverPort = _config['PORT'] as int? ?? 8080;

  _db = await Connection.open(
    Endpoint(
      host: dbHost,
      port: dbPort,
      database: dbName,
      username: dbUser,
      password: dbPass,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
  print('✅ Connected to PostgreSQL at $dbHost:$dbPort/$dbName');

  final router = Router()
    // Auth
    ..post('/api/auth/register', _handleRegister)
    ..post('/api/auth/login', _handleLogin)
    ..get('/api/auth/me', _handleMe)
    // Profile
    ..get('/api/profile', _handleGetProfile)
    ..put('/api/profile', _handleUpdateProfile)
    // Activities (Rooms & Events)
    ..get('/api/activities', _handleGetActivities)
    ..post('/api/activities', _handleCreateActivity)
    ..get('/api/activities/<id>', _handleGetActivityDetail)
    ..post('/api/activities/<id>/join', _handleJoinActivity)
    ..post('/api/activities/<id>/leave', _handleLeaveActivity)
    // Players
    ..get('/api/players', _handleGetPlayers)
    ..get('/api/players/<id>', _handleGetPlayerDetail)
    // Venues
    ..get('/api/venues', _handleGetVenues)
    // Rankings / Leaderboard
    ..get('/api/rankings', _handleGetRankings)
    // Checkout / Payments
    ..get('/api/checkout/<activityId>', _handleGetCheckout)
    ..post('/api/checkout/<reference>/confirm', _handleConfirmCheckout)
    // Match Scores
    ..post('/api/matches/<activityId>/score', _handleSubmitScore)
    ..get('/api/matches/<activityId>/result', _handleGetMatchResult)
    // Friends & Social
    ..post('/api/friends/request', _handleSendFriendRequest)
    ..post('/api/friends/cancel', _handleCancelFriendRequest)
    ..post('/api/friends/accept', _handleAcceptFriendRequest)
    ..post('/api/friends/reject', _handleRejectFriendRequest)
    ..post('/api/friends/remove', _handleRemoveFriend)
    ..get('/api/friends', _handleGetFriends)
    // Notifications
    ..get('/api/notifications', _handleGetNotifications)
    ..post('/api/notifications/<id>/read', _handleMarkNotificationRead)
    // Full Sync (untuk isi seluruh state Flutter sekaligus)
    ..get('/api/sync', _handleFullSync);

  final handler = const Pipeline()
      .addMiddleware(_cors())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await io.serve(handler, '0.0.0.0', serverPort);
  print('🚀 Server KLIK running on http://localhost:${server.port}');
}

// ════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════

String get _jwtSecret =>
    _config['JWT_SECRET'] as String? ?? 'klik-dev-secret-change-me';

String _createToken(String userId, String email) {
  final jwt = JWT({
    'sub': userId,
    'email': email,
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  });
  return jwt.sign(SecretKey(_jwtSecret), expiresIn: const Duration(days: 7));
}

int? _extractUserId(Request request) {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  try {
    final jwt =
        JWT.verify(authHeader.substring(7), SecretKey(_jwtSecret));
    final payload = jwt.payload as Map<String, dynamic>;
    return int.tryParse(payload['sub'] as String);
  } catch (_) {
    return null;
  }
}

Future<int?> _getUserIdForPlayer(String playerId) async {
  if (playerId.startsWith('user-')) {
    final parsed = int.tryParse(playerId.substring(5));
    if (parsed != null) return parsed;
  }
  final row = await _db.execute(
    Sql.named('SELECT user_id FROM players WHERE id = @id LIMIT 1'),
    parameters: {'id': playerId},
  );
  if (row.isNotEmpty) {
    final uid = row.first.toColumnMap()['user_id'];
    if (uid is int) return uid;
  }
  return null;
}

Future<String> _getPlayerIdForUser(int userId) async {
  final row = await _db.execute(
    Sql.named('SELECT id FROM players WHERE user_id = @uid LIMIT 1'),
    parameters: {'uid': userId},
  );
  if (row.isNotEmpty) {
    return row.first.toColumnMap()['id'] as String;
  }
  return 'user-$userId';
}

Response _json(dynamic data, [int status = 200]) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );
}

Middleware _cors() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

// ════════════════════════════════════════════════════════════
// 1. AUTH HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleRegister(Request request) async {
  try {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (body['email'] as String?)?.trim();
    final password = body['password'] as String?;
    final displayName = (body['display_name'] as String?)?.trim() ?? 'Pemain KLIK';
    final city = (body['city'] as String?)?.trim() ?? 'Jakarta Selatan';
    final sport = (body['sport'] as String?)?.trim() ?? 'Futsal';

    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return _json({'error': 'Email dan password wajib diisi.'}, 400);
    }
    if (password.length < 8) {
      return _json({'error': 'Password minimal 8 karakter.'}, 400);
    }

    final existing = await _db.execute(
      Sql.named('SELECT id FROM users WHERE email = @email LIMIT 1'),
      parameters: {'email': email},
    );
    if (existing.isNotEmpty) {
      return _json({'error': 'Email sudah terdaftar.'}, 409);
    }

    final result = await _db.execute(
      Sql.named(
        'INSERT INTO users (email, password, display_name, city, sport) '
        'VALUES (@email, @password, @displayName, @city, @sport) '
        'RETURNING id, email, display_name, city, sport, level, theme, avatar_url',
      ),
      parameters: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'city': city,
        'sport': sport,
      },
    );

    final row = result.first.toColumnMap();
    final userId = row['id'].toString();
    final token = _createToken(userId, email);

    // Auto-create player entry
    final initials = displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final handle = '@${email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '')}';
    await _db.execute(
      Sql.named(
        'INSERT INTO players (id, name, handle, sport, city, level, initials, user_id) '
        'VALUES (@id, @name, @handle, @sport, @city, @level, @initials, @userId) '
        'ON CONFLICT (id) DO UPDATE SET user_id = @userId',
      ),
      parameters: {
        'id': 'user-$userId',
        'name': displayName,
        'handle': handle,
        'sport': sport,
        'city': city,
        'level': row['level'] ?? 'Menengah',
        'initials': initials.isEmpty ? 'P' : initials,
        'userId': int.parse(userId),
      },
    );

    return _json({
      'token': token,
      'user': {
        'id': userId,
        'email': row['email'],
        'display_name': row['display_name'],
        'city': row['city'],
        'sport': row['sport'],
        'level': row['level'],
        'theme': row['theme'],
        'avatar_url': row['avatar_url'],
        'playerId': 'user-$userId',
      },
    }, 201);
  } catch (e) {
    return _json({'error': 'Gagal mendaftar: $e'}, 500);
  }
}

Future<Response> _handleLogin(Request request) async {
  try {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (body['email'] as String?)?.trim();
    final password = body['password'] as String?;

    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return _json({'error': 'Email dan password wajib diisi.'}, 400);
    }

    final result = await _db.execute(
      Sql.named(
        'SELECT id, email, display_name, city, sport, level, theme, avatar_url FROM users '
        'WHERE email = @email AND password = @password LIMIT 1',
      ),
      parameters: {'email': email, 'password': password},
    );

    if (result.isEmpty) {
      return _json({'error': 'Email atau kata sandi salah.'}, 401);
    }

    final row = result.first.toColumnMap();
    final userId = row['id'].toString();
    final token = _createToken(userId, email);
    final pid = await _getPlayerIdForUser(int.parse(userId));

    return _json({
      'token': token,
      'user': {
        'id': userId,
        'email': row['email'],
        'display_name': row['display_name'],
        'city': row['city'],
        'sport': row['sport'],
        'level': row['level'],
        'theme': row['theme'],
        'avatar_url': row['avatar_url'],
        'playerId': pid,
      },
    });
  } catch (e) {
    return _json({'error': 'Gagal login: $e'}, 500);
  }
}

Future<Response> _handleMe(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Unauthorized'}, 401);

  final result = await _db.execute(
    Sql.named(
      'SELECT id, email, display_name, city, sport, level, theme, avatar_url FROM users WHERE id = @id LIMIT 1',
    ),
    parameters: {'id': userId},
  );

  if (result.isEmpty) return _json({'error': 'User not found'}, 404);
  final row = result.first.toColumnMap();
  final pid = await _getPlayerIdForUser(userId);
  return _json({
    'user': {
      'id': row['id'].toString(),
      'email': row['email'],
      'display_name': row['display_name'],
      'city': row['city'],
      'sport': row['sport'],
      'level': row['level'],
      'theme': row['theme'],
      'avatar_url': row['avatar_url'],
      'playerId': pid,
    },
  });
}

// ════════════════════════════════════════════════════════════
// 2. PROFILE HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetProfile(Request request) async {
  return _handleMe(request);
}

Future<Response> _handleUpdateProfile(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Unauthorized'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final name = body['display_name'] as String?;
  final city = body['city'] as String?;
  final sport = body['sport'] as String?;
  final level = body['level'] as String?;
  final theme = body['theme'] as String?;

  await _db.execute(
    Sql.named('''
      UPDATE users SET
        display_name = COALESCE(@name, display_name),
        city = COALESCE(@city, city),
        sport = COALESCE(@sport, sport),
        level = COALESCE(@level, level),
        theme = COALESCE(@theme, theme)
      WHERE id = @id
    '''),
    parameters: {
      'id': userId,
      'name': name,
      'city': city,
      'sport': sport,
      'level': level,
      'theme': theme,
    },
  );

  return _json({'success': true});
}

// ════════════════════════════════════════════════════════════
// 3. ACTIVITIES HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetActivities(Request request) async {
  final params = request.url.queryParameters;
  final sport = params['sport'];
  final mode = params['mode'];
  final kind = params['kind'];
  final search = params['q'];

  var sql = 'SELECT * FROM activities WHERE 1=1';
  final p = <String, dynamic>{};

  if (sport != null && sport.isNotEmpty) {
    sql += ' AND sport = @sport';
    p['sport'] = sport;
  }
  if (mode != null && mode.isNotEmpty) {
    sql += ' AND mode = @mode';
    p['mode'] = mode;
  }
  if (kind != null && kind.isNotEmpty) {
    sql += ' AND kind = @kind';
    p['kind'] = kind;
  }
  if (search != null && search.isNotEmpty) {
    sql += ' AND (title ILIKE @q OR venue ILIKE @q OR city ILIKE @q)';
    p['q'] = '%$search%';
  }
  sql += ' ORDER BY starts_at ASC';

  final result = await _db.execute(Sql.named(sql), parameters: p);
  final list = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'kind': m['kind'],
      'title': m['title'],
      'sport': m['sport'],
      'venue': m['venue'],
      'city': m['city'],
      'mode': m['mode'],
      'startsAt': (m['starts_at'] as DateTime).toUtc().toIso8601String(),
      'durationMinutes': m['duration_minutes'],
      'capacity': m['capacity'],
      'occupied': m['occupied'],
      'price': m['price'],
      'owner': m['owner'],
      'description': m['description'],
      'demo': m['demo'] ?? false,
    };
  }).toList();

  return _json(list);
}

Future<Response> _handleCreateActivity(Request request) async {
  final userId = _extractUserId(request);
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

  final id = 'act-${DateTime.now().microsecondsSinceEpoch}';
  final kind = body['kind'] as String? ?? 'room';
  final title = (body['title'] as String?)?.trim() ?? '';
  final sport = body['sport'] as String? ?? 'Futsal';
  final venue = (body['venue'] as String?)?.trim() ?? '';
  final city = (body['city'] as String?)?.trim() ?? 'Jakarta Selatan';
  final mode = body['mode'] as String? ?? 'Kasual';
  final startsAt = DateTime.tryParse(body['startsAt'] as String? ?? '') ??
      DateTime.now().add(const Duration(days: 1));
  final durationMinutes = body['durationMinutes'] as int? ?? (kind == 'event' ? 360 : 120);
  final capacity = body['capacity'] as int? ?? 10;
  final price = body['price'] as int? ?? 0;
  final owner = body['owner'] as String? ?? 'Pemain KLIK';
  final description = body['description'] as String? ?? '';

  await _db.execute(
    Sql.named('''
      INSERT INTO activities (id, kind, title, sport, venue, city, mode, starts_at, duration_minutes, capacity, occupied, price, owner, description, demo, owner_user_id)
      VALUES (@id, @kind, @title, @sport, @venue, @city, @mode, @startsAt, @durationMinutes, @capacity, 1, @price, @owner, @description, false, @userId)
    '''),
    parameters: {
      'id': id,
      'kind': kind,
      'title': title,
      'sport': sport,
      'venue': venue,
      'city': city,
      'mode': mode,
      'startsAt': startsAt,
      'durationMinutes': durationMinutes,
      'capacity': capacity,
      'price': price,
      'owner': owner,
      'description': description,
      'userId': userId,
    },
  );

  // If user is logged in, auto-join as participant
  if (userId != null) {
    await _db.execute(
      Sql.named('INSERT INTO activity_participants (activity_id, user_id) VALUES (@actId, @userId) ON CONFLICT DO NOTHING'),
      parameters: {'actId': id, 'userId': userId},
    );
  }

  // If ranked room, create team A
  if (kind == 'room' && mode == 'Berperingkat') {
    final teamName = body['teamName'] as String? ?? 'Tim $owner';
    final teamId = 'team-$id-a';
    final captainId = userId != null ? 'user-$userId' : 'local-player';
    await _db.execute(
      Sql.named('INSERT INTO teams (id, name, captain_id, captain_name) VALUES (@id, @name, @capId, @capName) ON CONFLICT DO NOTHING'),
      parameters: {'id': teamId, 'name': teamName, 'capId': captainId, 'capName': owner},
    );
    await _db.execute(
      Sql.named('INSERT INTO ranked_matches (activity_id, team_a_id) VALUES (@actId, @teamId) ON CONFLICT DO NOTHING'),
      parameters: {'actId': id, 'teamId': teamId},
    );
  }

  return _json({'id': id, 'message': 'Aktivitas berhasil dibuat'}, 201);
}

Future<Response> _handleGetActivityDetail(Request request, String id) async {
  final result = await _db.execute(
    Sql.named('SELECT * FROM activities WHERE id = @id LIMIT 1'),
    parameters: {'id': id},
  );
  if (result.isEmpty) return _json({'error': 'Aktivitas tidak ditemukan'}, 404);

  final m = result.first.toColumnMap();
  return _json({
    'id': m['id'],
    'kind': m['kind'],
    'title': m['title'],
    'sport': m['sport'],
    'venue': m['venue'],
    'city': m['city'],
    'mode': m['mode'],
    'startsAt': (m['starts_at'] as DateTime).toUtc().toIso8601String(),
    'durationMinutes': m['duration_minutes'],
    'capacity': m['capacity'],
    'occupied': m['occupied'],
    'price': m['price'],
    'owner': m['owner'],
    'description': m['description'],
    'demo': m['demo'] ?? false,
  });
}

Future<Response> _handleJoinActivity(Request request, String id) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final act = await _db.execute(
    Sql.named('SELECT occupied, capacity, starts_at, price FROM activities WHERE id = @id LIMIT 1'),
    parameters: {'id': id},
  );
  if (act.isEmpty) return _json({'error': 'Aktivitas tidak ditemukan'}, 404);

  final a = act.first.toColumnMap();
  if ((a['occupied'] as int) >= (a['capacity'] as int)) {
    return _json({'error': 'Kapasitas sudah penuh'}, 400);
  }
  if ((a['starts_at'] as DateTime).isBefore(DateTime.now())) {
    return _json({'error': 'Aktivitas sudah dimulai'}, 400);
  }

  try {
    await _db.execute(
      Sql.named('INSERT INTO activity_participants (activity_id, user_id) VALUES (@id, @userId)'),
      parameters: {'id': id, 'userId': userId},
    );
    await _db.execute(
      Sql.named('UPDATE activities SET occupied = occupied + 1 WHERE id = @id'),
      parameters: {'id': id},
    );
    return _json({'success': true, 'message': 'Berhasil bergabung'});
  } catch (e) {
    return _json({'error': 'Sudah bergabung sebelumnya'}, 409);
  }
}

Future<Response> _handleLeaveActivity(Request request, String id) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final deleted = await _db.execute(
    Sql.named('DELETE FROM activity_participants WHERE activity_id = @id AND user_id = @userId RETURNING id'),
    parameters: {'id': id, 'userId': userId},
  );
  if (deleted.isEmpty) return _json({'error': 'Belum bergabung di aktivitas ini'}, 400);

  await _db.execute(
    Sql.named('UPDATE activities SET occupied = GREATEST(0, occupied - 1) WHERE id = @id'),
    parameters: {'id': id},
  );
  return _json({'success': true, 'message': 'Berhasil keluar'});
}

// ════════════════════════════════════════════════════════════
// 4. PLAYERS HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetPlayers(Request request) async {
  final result = await _db.execute('SELECT * FROM players ORDER BY name ASC');
  final list = result.map((r) => r.toColumnMap()).toList();
  return _json(list);
}

Future<Response> _handleGetPlayerDetail(Request request, String id) async {
  final result = await _db.execute(
    Sql.named('SELECT * FROM players WHERE id = @id LIMIT 1'),
    parameters: {'id': id},
  );
  if (result.isEmpty) return _json({'error': 'Pemain tidak ditemukan'}, 404);
  return _json(result.first.toColumnMap());
}

// ════════════════════════════════════════════════════════════
// 5. VENUES HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetVenues(Request request) async {
  final result = await _db.execute('SELECT * FROM venues ORDER BY name ASC');
  final list = result.map((r) => r.toColumnMap()).toList();
  return _json(list);
}

// ════════════════════════════════════════════════════════════
// 6. RANKINGS / LEADERBOARD HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetRankings(Request request) async {
  final sport = request.url.queryParameters['sport'];
  final type = request.url.queryParameters['type'];

  var sql = 'SELECT * FROM rankings WHERE 1=1';
  final p = <String, dynamic>{};
  if (sport != null && sport.isNotEmpty) {
    sql += ' AND sport = @sport';
    p['sport'] = sport;
  }
  if (type != null && type.isNotEmpty) {
    sql += ' AND type = @type';
    p['type'] = type;
  }
  sql += ' ORDER BY rank ASC';

  final result = await _db.execute(Sql.named(sql), parameters: p);
  final list = result.map((r) => r.toColumnMap()).toList();
  return _json(list);
}

// ════════════════════════════════════════════════════════════
// 7. CHECKOUT / QRIS HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetCheckout(Request request, String activityId) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final act = await _db.execute(
    Sql.named('SELECT price FROM activities WHERE id = @id LIMIT 1'),
    parameters: {'id': activityId},
  );
  if (act.isEmpty) return _json({'error': 'Aktivitas tidak ditemukan'}, 404);
  final price = act.first.toColumnMap()['price'] as int;

  final ref = 'KLIK-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  final expiresAt = DateTime.now().add(const Duration(minutes: 15));

  await _db.execute(
    Sql.named('''
      INSERT INTO checkout_previews (reference, activity_id, user_id, amount, status, expires_at)
      VALUES (@ref, @actId, @userId, @amount, 'pending', @exp)
    '''),
    parameters: {
      'ref': ref,
      'actId': activityId,
      'userId': userId,
      'amount': price,
      'exp': expiresAt,
    },
  );

  return _json({
    'reference': ref,
    'activityId': activityId,
    'amount': price,
    'status': 'pending',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'qrPayload': {
      'app': 'KLIK',
      'purpose': 'checkout-preview',
      'test_only': true,
      'reference': ref,
      'activity_id': activityId,
      'amount': price,
      'currency': 'IDR',
    },
  });
}

Future<Response> _handleConfirmCheckout(Request request, String reference) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final prev = await _db.execute(
    Sql.named('SELECT * FROM checkout_previews WHERE reference = @ref AND user_id = @userId LIMIT 1'),
    parameters: {'ref': reference, 'userId': userId},
  );
  if (prev.isEmpty) return _json({'error': 'Transaksi tidak ditemukan'}, 404);

  final p = prev.first.toColumnMap();
  if ((p['expires_at'] as DateTime).isBefore(DateTime.now())) {
    return _json({'error': 'Kode pembayaran sudah kedaluwarsa'}, 400);
  }

  await _db.execute(
    Sql.named("UPDATE checkout_previews SET status = 'demo_confirmed' WHERE reference = @ref"),
    parameters: {'ref': reference},
  );

  // Auto join activity
  final actId = p['activity_id'] as String;
  await _db.execute(
    Sql.named('INSERT INTO activity_participants (activity_id, user_id) VALUES (@actId, @userId) ON CONFLICT DO NOTHING'),
    parameters: {'actId': actId, 'userId': userId},
  );
  await _db.execute(
    Sql.named('UPDATE activities SET occupied = occupied + 1 WHERE id = @id'),
    parameters: {'id': actId},
  );

  return _json({'success': true, 'message': 'Pembayaran berhasil dikonfirmasi'});
}

// ════════════════════════════════════════════════════════════
// 8. MATCH SCORES HANDLERS (Dual-Captain Verification)
// ════════════════════════════════════════════════════════════

Future<Response> _handleSubmitScore(Request request, String activityId) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final captainId = body['captainId'] as String? ?? 'user-$userId';
  final scoreA = body['scoreA'] as int? ?? 0;
  final scoreB = body['scoreB'] as int? ?? 0;

  var resultQuery = await _db.execute(
    Sql.named('SELECT id FROM match_results WHERE activity_id = @actId LIMIT 1'),
    parameters: {'actId': activityId},
  );

  int resultId;
  if (resultQuery.isEmpty) {
    final inserted = await _db.execute(
      Sql.named('INSERT INTO match_results (activity_id, score_a, score_b) VALUES (@actId, @a, @b) RETURNING id'),
      parameters: {'actId': activityId, 'a': scoreA, 'b': scoreB},
    );
    resultId = inserted.first.toColumnMap()['id'] as int;
  } else {
    resultId = resultQuery.first.toColumnMap()['id'] as int;
  }

  await _db.execute(
    Sql.named('''
      INSERT INTO score_submissions (result_id, captain_id, score_a, score_b)
      VALUES (@resId, @capId, @a, @b)
      ON CONFLICT (result_id, captain_id) DO UPDATE SET score_a = @a, score_b = @b, submitted_at = NOW()
    '''),
    parameters: {'resId': resultId, 'capId': captainId, 'a': scoreA, 'b': scoreB},
  );

  final allSubs = await _db.execute(
    Sql.named('SELECT captain_id, score_a, score_b FROM score_submissions WHERE result_id = @resId'),
    parameters: {'resId': resultId},
  );

  String newStatus;
  DateTime? confirmedAt;
  if (allSubs.length < 2) {
    newStatus = 'Menunggu konfirmasi';
  } else {
    final first = allSubs[0].toColumnMap();
    final second = allSubs[1].toColumnMap();
    if (first['score_a'] == second['score_a'] && first['score_b'] == second['score_b']) {
      newStatus = 'Disahkan';
      confirmedAt = DateTime.now();
    } else {
      newStatus = 'Skor berbeda';
    }
  }

  await _db.execute(
    Sql.named('UPDATE match_results SET status = @st, confirmed_at = @ca, score_a = @a, score_b = @b WHERE id = @id'),
    parameters: {'st': newStatus, 'ca': confirmedAt, 'a': scoreA, 'b': scoreB, 'id': resultId},
  );

  return _json({'status': newStatus, 'scoreA': scoreA, 'scoreB': scoreB});
}

Future<Response> _handleGetMatchResult(Request request, String activityId) async {
  final result = await _db.execute(
    Sql.named('SELECT * FROM match_results WHERE activity_id = @actId LIMIT 1'),
    parameters: {'actId': activityId},
  );
  if (result.isEmpty) return _json(null);

  final m = result.first.toColumnMap();
  final subs = await _db.execute(
    Sql.named('SELECT captain_id, score_a, score_b, submitted_at FROM score_submissions WHERE result_id = @id'),
    parameters: {'id': m['id']},
  );

  final subMap = <String, dynamic>{};
  for (final s in subs) {
    final sm = s.toColumnMap();
    subMap[sm['captain_id'] as String] = {
      'scoreA': sm['score_a'],
      'scoreB': sm['score_b'],
      'at': (sm['submitted_at'] as DateTime).toUtc().toIso8601String(),
    };
  }

  return _json({
    'schema': 2,
    'own': m['score_a'],
    'other': m['score_b'],
    'status': m['status'],
    'at': (m['created_at'] as DateTime).toUtc().toIso8601String(),
    'confirmedAt': (m['confirmed_at'] as DateTime?)?.toUtc().toIso8601String(),
    'submissions': subMap,
  });
}

// ════════════════════════════════════════════════════════════
// 9. FRIENDS & SOCIAL HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleSendFriendRequest(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final targetPlayerId = body['targetPlayerId'] as String?;
  if (targetPlayerId == null || targetPlayerId.isEmpty) {
    return _json({'error': 'targetPlayerId wajib diisi'}, 400);
  }

  final targetUserId = await _getUserIdForPlayer(targetPlayerId);
  if (targetUserId == null) {
    return _json({'error': 'Pemain tidak ditemukan atau belum terdaftar'}, 404);
  }

  if (targetUserId == userId) {
    return _json({'error': 'Tidak dapat menambahkan diri sendiri sebagai teman'}, 400);
  }

  // Check existing friend status
  final existing = await _db.execute(
    Sql.named('''
      SELECT status FROM friends 
      WHERE (user_id = @sender AND friend_id = @target) 
         OR (user_id = @target AND friend_id = @sender)
      LIMIT 1
    '''),
    parameters: {'sender': userId, 'target': targetUserId},
  );

  if (existing.isNotEmpty && existing.first.toColumnMap()['status'] == 'accepted') {
    return _json({'error': 'Sudah berteman'}, 400);
  }

  // Insert or update request in friends table
  await _db.execute(
    Sql.named('''
      INSERT INTO friends (user_id, friend_id, status)
      VALUES (@sender, @target, 'pending')
      ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'pending', created_at = NOW()
    '''),
    parameters: {'sender': userId, 'target': targetUserId},
  );

  // Get sender's display name
  final senderRow = await _db.execute(
    Sql.named('SELECT display_name FROM users WHERE id = @uid LIMIT 1'),
    parameters: {'uid': userId},
  );
  final senderName = senderRow.isNotEmpty
      ? (senderRow.first.toColumnMap()['display_name'] as String? ?? 'Seorang pemain')
      : 'Seorang pemain';

  // Create notification for target user
  final senderPid = await _getPlayerIdForUser(userId);
  await _db.execute(
    Sql.named('''
      INSERT INTO notifications (user_id, title, body, type, action_id)
      VALUES (@target, 'Permintaan Pertemanan', @body, 'friend_request', @senderPid)
    '''),
    parameters: {
      'target': targetUserId,
      'body': '$senderName ingin berteman denganmu. Periksa menu Sosial atau terima di sini.',
      'senderPid': senderPid,
    },
  );

  return _json({'success': true, 'message': 'Permintaan pertemanan terkirim'});
}

Future<Response> _handleCancelFriendRequest(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final targetPlayerId = body['targetPlayerId'] as String?;
  if (targetPlayerId == null || targetPlayerId.isEmpty) {
    return _json({'error': 'targetPlayerId wajib diisi'}, 400);
  }

  final targetUserId = await _getUserIdForPlayer(targetPlayerId);
  if (targetUserId == null) return _json({'error': 'Pemain tidak ditemukan'}, 404);

  await _db.execute(
    Sql.named('''
      DELETE FROM friends 
      WHERE user_id = @sender AND friend_id = @target AND status = 'pending'
    '''),
    parameters: {'sender': userId, 'target': targetUserId},
  );

  return _json({'success': true, 'message': 'Permintaan pertemanan dibatalkan'});
}

Future<Response> _handleAcceptFriendRequest(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final requesterPlayerId = body['requesterPlayerId'] as String?;
  if (requesterPlayerId == null || requesterPlayerId.isEmpty) {
    return _json({'error': 'requesterPlayerId wajib diisi'}, 400);
  }

  final requesterUserId = await _getUserIdForPlayer(requesterPlayerId);
  if (requesterUserId == null) {
    return _json({'error': 'Pemain tidak ditemukan'}, 404);
  }

  // Update status to accepted
  await _db.execute(
    Sql.named('''
      UPDATE friends SET status = 'accepted' 
      WHERE user_id = @req AND friend_id = @me
    '''),
    parameters: {'req': requesterUserId, 'me': userId},
  );

  // Insert reciprocal row so both users see each other as friends
  await _db.execute(
    Sql.named('''
      INSERT INTO friends (user_id, friend_id, status)
      VALUES (@me, @req, 'accepted')
      ON CONFLICT (user_id, friend_id) DO UPDATE SET status = 'accepted'
    '''),
    parameters: {'me': userId, 'req': requesterUserId},
  );

  // Get current user's name
  final meRow = await _db.execute(
    Sql.named('SELECT display_name FROM users WHERE id = @uid LIMIT 1'),
    parameters: {'uid': userId},
  );
  final myName = meRow.isNotEmpty
      ? (meRow.first.toColumnMap()['display_name'] as String? ?? 'Teman baru')
      : 'Teman baru';

  // Send notification to the requester
  final myPid = await _getPlayerIdForUser(userId);
  await _db.execute(
    Sql.named('''
      INSERT INTO notifications (user_id, title, body, type, action_id)
      VALUES (@req, 'Pertemanan Diterima', @body, 'friend_accepted', @myPid)
    '''),
    parameters: {
      'req': requesterUserId,
      'body': '$myName telah menerima permintaan pertemananmu. Sekarang kalian berteman!',
      'myPid': myPid,
    },
  );

  return _json({'success': true, 'message': 'Permintaan pertemanan diterima'});
}

Future<Response> _handleRejectFriendRequest(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final requesterPlayerId = body['requesterPlayerId'] as String?;
  if (requesterPlayerId == null || requesterPlayerId.isEmpty) {
    return _json({'error': 'requesterPlayerId wajib diisi'}, 400);
  }

  final requesterUserId = await _getUserIdForPlayer(requesterPlayerId);
  if (requesterUserId == null) return _json({'error': 'Pemain tidak ditemukan'}, 404);

  await _db.execute(
    Sql.named('''
      DELETE FROM friends 
      WHERE user_id = @req AND friend_id = @me AND status = 'pending'
    '''),
    parameters: {'req': requesterUserId, 'me': userId},
  );

  return _json({'success': true, 'message': 'Permintaan pertemanan ditolak'});
}

Future<Response> _handleRemoveFriend(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final friendPlayerId = body['friendPlayerId'] as String?;
  if (friendPlayerId == null || friendPlayerId.isEmpty) {
    return _json({'error': 'friendPlayerId wajib diisi'}, 400);
  }

  final friendUserId = await _getUserIdForPlayer(friendPlayerId);
  if (friendUserId == null) return _json({'error': 'Pemain tidak ditemukan'}, 404);

  await _db.execute(
    Sql.named('''
      DELETE FROM friends 
      WHERE (user_id = @me AND friend_id = @friend) 
         OR (user_id = @friend AND friend_id = @me)
    '''),
    parameters: {'me': userId, 'friend': friendUserId},
  );

  return _json({'success': true, 'message': 'Pertemanan dihapus'});
}

Future<Response> _handleGetFriends(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  // 1. Accepted friends
  final fRows = await _db.execute(
    Sql.named('SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'accepted\''),
    parameters: {'uid': userId},
  );
  final friends = <String>[];
  for (final r in fRows) {
    final fid = r.toColumnMap()['friend_id'] as int;
    final pid = await _getPlayerIdForUser(fid);
    friends.add(pid);
  }

  // 2. Sent requests (pending)
  final sentRows = await _db.execute(
    Sql.named('SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'pending\''),
    parameters: {'uid': userId},
  );
  final sent = <String>[];
  for (final r in sentRows) {
    final fid = r.toColumnMap()['friend_id'] as int;
    final pid = await _getPlayerIdForUser(fid);
    sent.add(pid);
  }

  // 3. Received requests (pending)
  final recRows = await _db.execute(
    Sql.named('SELECT user_id FROM friends WHERE friend_id = @uid AND status = \'pending\''),
    parameters: {'uid': userId},
  );
  final received = <String>[];
  for (final r in recRows) {
    final uid = r.toColumnMap()['user_id'] as int;
    final pid = await _getPlayerIdForUser(uid);
    received.add(pid);
  }

  return _json({
    'friends': friends,
    'sent': sent,
    'received': received,
  });
}

// ════════════════════════════════════════════════════════════
// 10. NOTIFICATIONS HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetNotifications(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final rows = await _db.execute(
    Sql.named('''
      SELECT id, title, body, type, action_id, is_read, created_at 
      FROM notifications 
      WHERE user_id = @uid 
      ORDER BY created_at DESC 
      LIMIT 50
    '''),
    parameters: {'uid': userId},
  );

  final list = rows.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'title': m['title'],
      'body': m['body'],
      'type': m['type'] ?? 'general',
      'actionId': m['action_id'],
      'isRead': m['is_read'] ?? false,
      'createdAt': (m['created_at'] as DateTime).toUtc().toIso8601String(),
    };
  }).toList();

  return _json(list);
}

Future<Response> _handleMarkNotificationRead(Request request, String idStr) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final notifId = int.tryParse(idStr);
  if (notifId == null) return _json({'error': 'ID tidak valid'}, 400);

  await _db.execute(
    Sql.named('UPDATE notifications SET is_read = true WHERE id = @id AND user_id = @uid'),
    parameters: {'id': notifId, 'uid': userId},
  );

  return _json({'success': true});
}

// ════════════════════════════════════════════════════════════
// 11. FULL SYNC
// ════════════════════════════════════════════════════════════

Future<Response> _handleFullSync(Request request) async {
  final userId = _extractUserId(request);

  // Activities
  final actRows = await _db.execute('SELECT * FROM activities ORDER BY starts_at ASC');
  final activities = actRows.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'kind': m['kind'],
      'title': m['title'],
      'sport': m['sport'],
      'venue': m['venue'],
      'city': m['city'],
      'mode': m['mode'],
      'startsAt': (m['starts_at'] as DateTime).toUtc().toIso8601String(),
      'durationMinutes': m['duration_minutes'],
      'capacity': m['capacity'],
      'occupied': m['occupied'],
      'price': m['price'],
      'owner': m['owner'],
      'description': m['description'],
      'demo': m['demo'] ?? false,
    };
  }).toList();

  // Players
  final playerRows = await _db.execute('SELECT * FROM players ORDER BY name ASC');
  final players = playerRows.map((r) => r.toColumnMap()).toList();

  // Venues
  final venueRows = await _db.execute('SELECT * FROM venues ORDER BY name ASC');
  final venues = venueRows.map((r) => r.toColumnMap()).toList();

  // Rankings
  final rankRows = await _db.execute('SELECT * FROM rankings ORDER BY rank ASC');
  final rankings = rankRows.map((r) => r.toColumnMap()).toList();

  // Joined activity IDs for this user
  var joinedIds = <String>[];
  var friendsList = <String>[];
  var requestedList = <String>[];
  var incomingList = <String>[];
  var notificationsList = <Map<String, dynamic>>[];

  if (userId != null) {
    // Joined activities
    final jRows = await _db.execute(
      Sql.named('SELECT activity_id FROM activity_participants WHERE user_id = @uid'),
      parameters: {'uid': userId},
    );
    joinedIds = jRows.map((r) => r.toColumnMap()['activity_id'] as String).toList();

    // Accepted friends
    final fRows = await _db.execute(
      Sql.named('SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'accepted\''),
      parameters: {'uid': userId},
    );
    for (final r in fRows) {
      final fid = r.toColumnMap()['friend_id'] as int;
      final pid = await _getPlayerIdForUser(fid);
      if (!friendsList.contains(pid)) friendsList.add(pid);
    }

    // Outgoing requested
    final reqRows = await _db.execute(
      Sql.named('SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'pending\''),
      parameters: {'uid': userId},
    );
    for (final r in reqRows) {
      final fid = r.toColumnMap()['friend_id'] as int;
      final pid = await _getPlayerIdForUser(fid);
      if (!requestedList.contains(pid)) requestedList.add(pid);
    }

    // Incoming requests
    final incRows = await _db.execute(
      Sql.named('SELECT user_id FROM friends WHERE friend_id = @uid AND status = \'pending\''),
      parameters: {'uid': userId},
    );
    for (final r in incRows) {
      final reqUid = r.toColumnMap()['user_id'] as int;
      final pid = await _getPlayerIdForUser(reqUid);
      if (!incomingList.contains(pid)) incomingList.add(pid);
    }

    // Notifications
    final notifRows = await _db.execute(
      Sql.named('''
        SELECT id, title, body, type, action_id, is_read, created_at 
        FROM notifications 
        WHERE user_id = @uid 
        ORDER BY created_at DESC 
        LIMIT 50
      '''),
      parameters: {'uid': userId},
    );
    notificationsList = notifRows.map((r) {
      final m = r.toColumnMap();
      return {
        'id': m['id'],
        'title': m['title'],
        'body': m['body'],
        'type': m['type'] ?? 'general',
        'actionId': m['action_id'],
        'isRead': m['is_read'] ?? false,
        'createdAt': (m['created_at'] as DateTime).toUtc().toIso8601String(),
      };
    }).toList();
  }

  // User profile
  Map<String, dynamic>? userProfile;
  if (userId != null) {
    final uRows = await _db.execute(
      Sql.named('SELECT display_name, city, sport, level, theme, avatar_url FROM users WHERE id = @uid LIMIT 1'),
      parameters: {'uid': userId},
    );
    if (uRows.isNotEmpty) {
      userProfile = uRows.first.toColumnMap();
      userProfile['playerId'] = await _getPlayerIdForUser(userId);
    }
  }

  return _json({
    'activities': activities,
    'players': players,
    'venues': venues,
    'rankings': rankings,
    'joined': joinedIds,
    'friends': friendsList,
    'requested': requestedList,
    'incomingRequests': incomingList,
    'notifications': notificationsList,
    'user': userProfile,
  });
}
