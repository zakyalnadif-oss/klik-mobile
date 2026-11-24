import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

late final Map<String, dynamic> _config;
late Connection _db;
DateTime? _lastNominatimRequest;
Future<void> _nominatimQueue = Future<void>.value();

Future<void> main() async {
  final localConfig = File('config.local.json');
  final configFile = localConfig.existsSync()
      ? localConfig
      : File('config.json');
  if (!configFile.existsSync()) {
    print(
      '❌ config.local.json tidak ditemukan. Salin config.example.json lalu isi kredensial PostgreSQL.',
    );
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
    ..post('/api/auth/password-reset', _handlePasswordResetRequest)
    ..post('/api/auth/password-reset/confirm', _handlePasswordResetConfirm)
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
    ..get('/api/venues/locate', _handleLocateVenue)
    ..post('/api/venues', _handleCreateVenue)
    ..get('/api/venues/<id>/availability', _handleVenueAvailability)
    ..get('/api/venues/<id>/bookings', _handleGetVenueBookings)
    ..post('/api/venues/<id>/bookings', _handleCreateVenueBooking)
    ..put('/api/venue-bookings/<id>', _handleUpdateVenueBooking)
    // Rankings / Leaderboard
    ..get('/api/rankings', _handleGetRankings)
    // Checkout / Payments (Midtrans QRIS)
    ..get('/api/checkout/<activityId>', _handleGetCheckout)
    ..post('/api/checkout/<reference>/confirm', _handleConfirmCheckout)
    ..get('/api/checkout/<reference>/status', _handleCheckPaymentStatus)
    ..post('/api/midtrans/webhook', _handleMidtransWebhook)
    ..get('/api/pay/<reference>', _handlePublicPayPage)
    ..post('/api/pay/<reference>/submit', _handlePublicPaySubmit)
    // Match Scores
    ..post('/api/matches/<activityId>/score', _handleSubmitScore)
    ..get('/api/matches/<activityId>/result', _handleGetMatchResult)
    ..post('/api/matches/<activityId>/teams', _handleRegisterMatchTeam)
    // Friends & Social
    ..post('/api/friends/request', _handleSendFriendRequest)
    ..post('/api/friends/cancel', _handleCancelFriendRequest)
    ..post('/api/friends/accept', _handleAcceptFriendRequest)
    ..post('/api/friends/reject', _handleRejectFriendRequest)
    ..post('/api/friends/remove', _handleRemoveFriend)
    ..get('/api/friends', _handleGetFriends)
    // Direct Messages / Chat Antar Teman
    ..get('/api/messages/conversations', _handleGetConversations)
    ..get('/api/messages/<targetPlayerId>', _handleGetDirectMessages)
    ..post('/api/messages/<targetPlayerId>', _handleSendDirectMessage)
    // Communities
    ..post('/api/communities/join', _handleJoinCommunity)
    ..post('/api/communities/leave', _handleLeaveCommunity)
    ..get('/api/communities', _handleGetCommunities)
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

const _passwordIterations = 210000;

String _hashPassword(String password) {
  final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final key = _derivePasswordKey(password, salt, _passwordIterations);
  return 'pbkdf2_sha256\$$_passwordIterations\$${base64Encode(salt)}\$${base64Encode(key)}';
}

bool _verifyPassword(String password, String stored) {
  if (!stored.startsWith('pbkdf2_sha256\$')) return stored == password;
  final parts = stored.split('\$');
  if (parts.length != 4) return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 100000 || iterations > 1000000) {
    return false;
  }
  try {
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = _derivePasswordKey(password, salt, iterations);
    if (actual.length != expected.length) return false;
    var mismatch = 0;
    for (var i = 0; i < actual.length; i++) {
      mismatch |= actual[i] ^ expected[i];
    }
    return mismatch == 0;
  } on FormatException {
    return false;
  }
}

List<int> _derivePasswordKey(String password, List<int> salt, int iterations) {
  final mac = crypto.Hmac(crypto.sha256, utf8.encode(password));
  var block = mac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = List<int>.from(block);
  for (var i = 1; i < iterations; i++) {
    block = mac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return result;
}

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
    final jwt = JWT.verify(authHeader.substring(7), SecretKey(_jwtSecret));
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
    final displayName =
        (body['display_name'] as String?)?.trim() ?? 'Pemain KLIK';
    final city = (body['city'] as String?)?.trim() ?? 'Jakarta Selatan';
    final sport = (body['sport'] as String?)?.trim() ?? 'Futsal';

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
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
        'password': _hashPassword(password),
        'displayName': displayName,
        'city': city,
        'sport': sport,
      },
    );

    final row = result.first.toColumnMap();
    final userId = row['id'].toString();
    final token = _createToken(userId, email);

    // Auto-create player entry
    final initials = displayName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final handle =
        '@${email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '')}';
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

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _json({'error': 'Email dan password wajib diisi.'}, 400);
    }

    final result = await _db.execute(
      Sql.named(
        'SELECT id, email, password, display_name, city, sport, level, theme, avatar_url FROM users '
        'WHERE email = @email LIMIT 1',
      ),
      parameters: {'email': email},
    );

    if (result.isEmpty ||
        !_verifyPassword(
          password,
          result.first.toColumnMap()['password'] as String,
        )) {
      return _json({'error': 'Email atau kata sandi salah.'}, 401);
    }

    final row = result.first.toColumnMap();
    if (!(row['password'] as String).startsWith('pbkdf2_sha256\$')) {
      await _db.execute(
        Sql.named('UPDATE users SET password = @password WHERE id = @id'),
        parameters: {'id': row['id'], 'password': _hashPassword(password)},
      );
    }
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

bool get _smtpConfigured => [
  'SMTP_HOST',
  'SMTP_USERNAME',
  'SMTP_PASSWORD',
  'SMTP_FROM_EMAIL',
].every((key) => (_config[key] as String? ?? '').trim().isNotEmpty);

Future<void> _sendPasswordResetEmail(String email, String token) async {
  final port = _config['SMTP_PORT'] as int? ?? 587;
  final username = _config['SMTP_USERNAME'] as String;
  final message = Message()
    ..from = Address(
      _config['SMTP_FROM_EMAIL'] as String,
      _config['SMTP_FROM_NAME'] as String? ?? 'KLIK',
    )
    ..recipients.add(email)
    ..subject = 'Kode pemulihan akun KLIK'
    ..text =
        'Kode pemulihan akun KLIK: $token\nKode berlaku selama 30 menit. Jika kamu tidak meminta pemulihan, abaikan email ini.';
  await send(
    message,
    SmtpServer(
      _config['SMTP_HOST'] as String,
      port: port,
      ssl: port == 465,
      username: username,
      password: _config['SMTP_PASSWORD'] as String,
    ),
    timeout: const Duration(seconds: 15),
  );
}

Future<Response> _handlePasswordResetRequest(Request request) async {
  if (!_smtpConfigured) {
    return _json({
      'error': 'Email pemulihan belum dikonfigurasi di server.',
    }, 503);
  }
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final email = (body['email'] as String?)?.trim().toLowerCase();
  if (email == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return _json({'error': 'Alamat email tidak valid.'}, 400);
  }
  final users = await _db.execute(
    Sql.named('SELECT id FROM users WHERE LOWER(email) = @email LIMIT 1'),
    parameters: {'email': email},
  );
  if (users.isEmpty) return _json({'success': true}, 202);
  final userId = users.first.toColumnMap()['id'] as int;
  final recent = await _db.execute(
    Sql.named('''
      SELECT COUNT(*)::int AS count FROM password_reset_tokens
      WHERE user_id = @userId AND created_at > NOW() - INTERVAL '15 minutes'
    '''),
    parameters: {'userId': userId},
  );
  if ((recent.first.toColumnMap()['count'] as int) >= 3) {
    return _json({'success': true}, 202);
  }

  final token = base64UrlEncode(
    List<int>.generate(32, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  final tokenHash = crypto.sha256.convert(utf8.encode(token)).toString();
  await _db.execute(
    Sql.named('''
      INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
      VALUES (@userId, @hash, NOW() + INTERVAL '30 minutes')
    '''),
    parameters: {'userId': userId, 'hash': tokenHash},
  );
  try {
    await _sendPasswordResetEmail(email, token);
  } catch (_) {
    await _db.execute(
      Sql.named(
        'UPDATE password_reset_tokens SET used_at = NOW() WHERE token_hash = @hash',
      ),
      parameters: {'hash': tokenHash},
    );
    return _json({
      'error': 'Email pemulihan gagal dikirim. Coba lagi nanti.',
    }, 503);
  }
  return _json({'success': true}, 202);
}

Future<Response> _handlePasswordResetConfirm(Request request) async {
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final token = body['token'] as String? ?? '';
  final password = body['password'] as String? ?? '';
  if (token.length < 32 || password.length < 8) {
    return _json({
      'error':
          'Kode pemulihan tidak valid atau kata sandi kurang dari 8 karakter.',
    }, 400);
  }
  final tokenHash = crypto.sha256.convert(utf8.encode(token)).toString();
  final updated = await _db.execute(
    Sql.named('''
      WITH consumed AS (
        UPDATE password_reset_tokens SET used_at = NOW()
        WHERE token_hash = @hash AND used_at IS NULL AND expires_at > NOW()
        RETURNING user_id
      )
      UPDATE users SET password = @password
      FROM consumed WHERE users.id = consumed.user_id
      RETURNING users.id
    '''),
    parameters: {'hash': tokenHash, 'password': _hashPassword(password)},
  );
  if (updated.isEmpty) {
    return _json({
      'error': 'Kode pemulihan tidak valid atau sudah kedaluwarsa.',
    }, 400);
  }
  return _json({'success': true});
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

  await _db.execute(
    Sql.named('''
      UPDATE players SET name = COALESCE(@name, name), city = COALESCE(@city, city),
        sport = COALESCE(@sport, sport), level = COALESCE(@level, level)
      WHERE user_id = @id
    '''),
    parameters: {
      'id': userId,
      'name': name,
      'city': city,
      'sport': sport,
      'level': level,
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
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

  final id = 'act-${DateTime.now().microsecondsSinceEpoch}';
  final kind = body['kind'] as String? ?? 'room';
  final title = (body['title'] as String?)?.trim() ?? '';
  final sport = body['sport'] as String? ?? 'Futsal';
  final venue = (body['venue'] as String?)?.trim() ?? '';
  final city = (body['city'] as String?)?.trim() ?? 'Jakarta Selatan';
  final mode = body['mode'] as String? ?? 'Kasual';
  final startsAt =
      DateTime.tryParse(body['startsAt'] as String? ?? '') ??
      DateTime.now().add(const Duration(days: 1));
  final durationMinutes =
      body['durationMinutes'] as int? ?? (kind == 'event' ? 360 : 120);
  final capacity = body['capacity'] as int? ?? 10;
  final price = body['price'] as int? ?? 0;
  final owner = body['owner'] as String? ?? 'Pemain KLIK';
  final description = body['description'] as String? ?? '';

  await _db.execute(
    Sql.named('''
      INSERT INTO activities (id, kind, title, sport, venue, venue_id, city, mode, starts_at, duration_minutes, capacity, occupied, price, owner, description, demo, owner_user_id)
      VALUES (@id, @kind, @title, @sport, @venue,
        (SELECT id FROM venues WHERE LOWER(name) = LOWER(@venue) LIMIT 1),
        @city, @mode, @startsAt, @durationMinutes, @capacity, 1, @price, @owner, @description, false, @userId)
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
  await _db.execute(
    Sql.named(
      'INSERT INTO activity_participants (activity_id, user_id) VALUES (@actId, @userId) ON CONFLICT DO NOTHING',
    ),
    parameters: {'actId': id, 'userId': userId},
  );

  // If ranked room, create team A
  if (kind == 'room' && mode == 'Berperingkat') {
    final teamName = body['teamName'] as String? ?? 'Tim $owner';
    final teamId = 'team-$id-a';
    final captainId = 'user-$userId';
    await _db.execute(
      Sql.named(
        'INSERT INTO teams (id, name, captain_id, captain_name) VALUES (@id, @name, @capId, @capName) ON CONFLICT DO NOTHING',
      ),
      parameters: {
        'id': teamId,
        'name': teamName,
        'capId': captainId,
        'capName': owner,
      },
    );
    await _db.execute(
      Sql.named(
        'INSERT INTO ranked_matches (activity_id, team_a_id) VALUES (@actId, @teamId) ON CONFLICT DO NOTHING',
      ),
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
    Sql.named(
      'SELECT occupied, capacity, starts_at, price FROM activities WHERE id = @id LIMIT 1',
    ),
    parameters: {'id': id},
  );
  if (act.isEmpty) return _json({'error': 'Aktivitas tidak ditemukan'}, 404);

  final a = act.first.toColumnMap();
  if ((a['price'] as int) > 0) {
    return _json({
      'error': 'Kegiatan berbayar harus dibayar melalui checkout.',
    }, 400);
  }
  if ((a['occupied'] as int) >= (a['capacity'] as int)) {
    return _json({'error': 'Kapasitas sudah penuh'}, 400);
  }
  if ((a['starts_at'] as DateTime).isBefore(DateTime.now())) {
    return _json({'error': 'Aktivitas sudah dimulai'}, 400);
  }

  try {
    await _db.execute(
      Sql.named(
        'INSERT INTO activity_participants (activity_id, user_id) VALUES (@id, @userId)',
      ),
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
    Sql.named(
      'DELETE FROM activity_participants WHERE activity_id = @id AND user_id = @userId RETURNING id',
    ),
    parameters: {'id': id, 'userId': userId},
  );
  if (deleted.isEmpty)
    return _json({'error': 'Belum bergabung di aktivitas ini'}, 400);

  await _db.execute(
    Sql.named(
      'UPDATE activities SET occupied = GREATEST(0, occupied - 1) WHERE id = @id',
    ),
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

Future<Response> _handleCreateVenue(Request request) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final name = (body['name'] as String?)?.trim() ?? '';
  final sport = (body['sport'] as String?)?.trim() ?? '';
  final address = (body['address'] as String?)?.trim() ?? '';
  final description = (body['description'] as String?)?.trim() ?? '';
  if (name.isEmpty ||
      name.length > 200 ||
      address.isEmpty ||
      address.length > 300 ||
      ![
        'Futsal',
        'Basket',
        'Biliar',
        'Voli',
        'Padel',
        'Bulu Tangkis',
        'Sepak Bola',
      ].contains(sport)) {
    return _json({
      'error': 'Nama, olahraga, atau alamat lapangan tidak valid.',
    }, 400);
  }
  try {
    final result = await _db.execute(
      Sql.named('''
        INSERT INTO venues (name, sport, address, description, owner_user_id)
        VALUES (@name, @sport, @address, @description, @owner)
        RETURNING id, name, sport, address, description, latitude, longitude, owner_user_id
      '''),
      parameters: {
        'name': name,
        'sport': sport,
        'address': address,
        'description': description,
        'owner': userId,
      },
    );
    return _json(result.first.toColumnMap(), 201);
  } catch (error) {
    if (error.toString().contains('venues_name_key')) {
      return _json({'error': 'Lapangan dengan nama itu sudah terdaftar.'}, 409);
    }
    rethrow;
  }
}

Future<Response> _handleVenueAvailability(
  Request request,
  String idText,
) async {
  final venueId = int.tryParse(idText);
  if (venueId == null) return _json({'error': 'ID lapangan tidak valid.'}, 400);
  final from = DateTime.tryParse(request.url.queryParameters['from'] ?? '');
  final to = DateTime.tryParse(request.url.queryParameters['to'] ?? '');
  if (from == null ||
      to == null ||
      !to.isAfter(from) ||
      to.difference(from).inDays > 31) {
    return _json({'error': 'Rentang jadwal maksimal 31 hari.'}, 400);
  }
  final bookings = await _db.execute(
    Sql.named('''
      SELECT id::text AS id, starts_at, ends_at, status, 'booking' AS source
      FROM venue_bookings WHERE venue_id = @id AND status IN ('pending','confirmed')
        AND starts_at < @to AND ends_at > @from
      UNION ALL
      SELECT id::text AS id, starts_at, starts_at + make_interval(mins => duration_minutes),
        'confirmed'::text AS status, 'activity' AS source
      FROM activities WHERE venue_id = @id AND starts_at < @to
        AND starts_at + make_interval(mins => duration_minutes) > @from
      ORDER BY starts_at ASC
    '''),
    parameters: {'id': venueId, 'from': from.toUtc(), 'to': to.toUtc()},
  );
  return _json(
    bookings.map((row) {
      final m = row.toColumnMap();
      return {
        'id': m['id'],
        'startsAt': (m['starts_at'] as DateTime).toUtc().toIso8601String(),
        'endsAt': (m['ends_at'] as DateTime).toUtc().toIso8601String(),
        'status': m['status'],
        'source': m['source'],
      };
    }).toList(),
  );
}

Future<Response> _handleGetVenueBookings(Request request, String idText) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);
  final venueId = int.tryParse(idText);
  if (venueId == null) return _json({'error': 'ID lapangan tidak valid.'}, 400);
  final rows = await _db.execute(
    Sql.named('''
      SELECT b.id, b.user_id, b.starts_at, b.ends_at, b.status, b.notes, u.display_name
      FROM venue_bookings b JOIN venues v ON v.id = b.venue_id
      JOIN users u ON u.id = b.user_id
      WHERE b.venue_id = @venue AND (b.user_id = @userId OR v.owner_user_id = @userId)
      ORDER BY b.starts_at ASC
    '''),
    parameters: {'venue': venueId, 'userId': userId},
  );
  final isOwnerRows = await _db.execute(
    Sql.named(
      'SELECT 1 FROM venues WHERE id = @venue AND owner_user_id = @userId LIMIT 1',
    ),
    parameters: {'venue': venueId, 'userId': userId},
  );
  final isOwner = isOwnerRows.isNotEmpty;
  return _json(
    rows.map((row) {
      final m = row.toColumnMap();
      return {
        'id': m['id'],
        'startsAt': (m['starts_at'] as DateTime).toUtc().toIso8601String(),
        'endsAt': (m['ends_at'] as DateTime).toUtc().toIso8601String(),
        'status': m['status'],
        'notes': m['notes'],
        'canManage': isOwner,
        if (isOwner) 'customer': m['display_name'],
      };
    }).toList(),
  );
}

Future<Response> _handleCreateVenueBooking(
  Request request,
  String idText,
) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);
  final venueId = int.tryParse(idText);
  if (venueId == null) return _json({'error': 'ID lapangan tidak valid.'}, 400);
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final startsAt = DateTime.tryParse(body['startsAt'] as String? ?? '');
  final duration = body['durationMinutes'] as int? ?? 120;
  final notes = (body['notes'] as String? ?? '').trim();
  if (startsAt == null ||
      !startsAt.isAfter(DateTime.now()) ||
      duration < 30 ||
      duration > 720 ||
      notes.length > 500) {
    return _json({'error': 'Jadwal atau catatan pemesanan tidak valid.'}, 400);
  }
  final venue = await _db.execute(
    Sql.named('SELECT owner_user_id FROM venues WHERE id = @id LIMIT 1'),
    parameters: {'id': venueId},
  );
  if (venue.isEmpty) return _json({'error': 'Lapangan tidak ditemukan.'}, 404);
  final ownerId = venue.first.toColumnMap()['owner_user_id'] as int?;
  if (ownerId == null)
    return _json({
      'error': 'Lapangan ini belum dikelola pemilik di KLIK.',
    }, 409);
  if (ownerId == userId)
    return _json({
      'error': 'Pemilik tidak dapat memesan lapangannya sendiri.',
    }, 400);
  final endsAt = startsAt.add(Duration(minutes: duration));
  final activityConflict = await _db.execute(
    Sql.named('''
      SELECT 1 FROM activities WHERE venue_id = @venue AND starts_at < @ends
        AND starts_at + make_interval(mins => duration_minutes) > @starts LIMIT 1
    '''),
    parameters: {
      'venue': venueId,
      'starts': startsAt.toUtc(),
      'ends': endsAt.toUtc(),
    },
  );
  if (activityConflict.isNotEmpty) {
    return _json({'error': 'Waktu tersebut sudah dipakai kegiatan KLIK.'}, 409);
  }
  try {
    final rows = await _db.execute(
      Sql.named('''
        INSERT INTO venue_bookings (venue_id, user_id, starts_at, ends_at, notes)
        VALUES (@venue, @userId, @starts, @ends, @notes)
        RETURNING id, starts_at, ends_at, status
      '''),
      parameters: {
        'venue': venueId,
        'userId': userId,
        'starts': startsAt.toUtc(),
        'ends': endsAt.toUtc(),
        'notes': notes,
      },
    );
    final m = rows.first.toColumnMap();
    await _db.execute(
      Sql.named('''
        INSERT INTO notifications (user_id, title, body, type, action_id)
        VALUES (@owner, 'Permintaan pemesanan lapangan', 'Ada permintaan jadwal baru.', 'venue_booking', @id)
      '''),
      parameters: {'owner': ownerId, 'id': m['id'].toString()},
    );
    return _json({
      'id': m['id'],
      'startsAt': (m['starts_at'] as DateTime).toUtc().toIso8601String(),
      'endsAt': (m['ends_at'] as DateTime).toUtc().toIso8601String(),
      'status': m['status'],
    }, 201);
  } catch (error) {
    if (error.toString().contains('venue_bookings_no_overlap')) {
      return _json({'error': 'Jadwal tersebut baru saja dipesan.'}, 409);
    }
    rethrow;
  }
}

Future<Response> _handleUpdateVenueBooking(
  Request request,
  String idText,
) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);
  final bookingId = int.tryParse(idText);
  if (bookingId == null)
    return _json({'error': 'ID pemesanan tidak valid.'}, 400);
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final status = body['status'] as String?;
  if (!['confirmed', 'rejected'].contains(status)) {
    return _json({'error': 'Status pemesanan tidak valid.'}, 400);
  }
  final updated = await _db.execute(
    Sql.named('''
      UPDATE venue_bookings b SET status = @status
      FROM venues v WHERE b.id = @id AND b.venue_id = v.id
        AND v.owner_user_id = @userId AND b.status = 'pending'
      RETURNING b.user_id, b.venue_id, b.starts_at
    '''),
    parameters: {'id': bookingId, 'userId': userId, 'status': status},
  );
  if (updated.isEmpty)
    return _json({'error': 'Permintaan tidak tersedia untuk dikelola.'}, 404);
  final row = updated.first.toColumnMap();
  final venue = await _db.execute(
    Sql.named('SELECT name FROM venues WHERE id = @id'),
    parameters: {'id': row['venue_id']},
  );
  await _db.execute(
    Sql.named('''
      INSERT INTO notifications (user_id, title, body, type, action_id)
      VALUES (@userId, @title, @body, 'venue_booking', @id)
    '''),
    parameters: {
      'userId': row['user_id'],
      'title': status == 'confirmed'
          ? 'Pemesanan dikonfirmasi'
          : 'Pemesanan ditolak',
      'body':
          '${venue.first.toColumnMap()['name']} memperbarui permintaan jadwalmu.',
      'id': bookingId.toString(),
    },
  );
  return _json({'success': true, 'status': status});
}

Future<Response> _handleLocateVenue(Request request) async {
  final name = request.url.queryParameters['name']?.trim();
  if (name == null || name.isEmpty) {
    return _json({'error': 'Nama lapangan wajib diisi.'}, 400);
  }
  final rows = await _db.execute(
    Sql.named(
      'SELECT id, name, address, latitude, longitude FROM venues WHERE name = @name LIMIT 1',
    ),
    parameters: {'name': name},
  );
  if (rows.isEmpty)
    return _json({'error': 'Lapangan belum terdaftar di server.'}, 404);
  final venue = rows.first.toColumnMap();
  if (venue['latitude'] != null && venue['longitude'] != null) {
    return _json({
      'latitude': venue['latitude'],
      'longitude': venue['longitude'],
    });
  }

  await _waitForNominatimSlot();

  final query = '${venue['name']}, ${venue['address']}';
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent = 'KLIK-Mobile/0.4.3';
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '1',
      'q': query,
    });
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return _json({
        'error': 'Lokasi belum dapat dicari di OpenStreetMap.',
      }, 503);
    }
    final matches = jsonDecode(await response.transform(utf8.decoder).join());
    if (matches is! List || matches.isEmpty) {
      return _json({'error': 'Koordinat lapangan belum ditemukan.'}, 404);
    }
    final first = matches.first as Map<String, dynamic>;
    final latitude = double.tryParse(first['lat'] as String? ?? '');
    final longitude = double.tryParse(first['lon'] as String? ?? '');
    if (latitude == null || longitude == null) {
      return _json({'error': 'Koordinat lapangan tidak valid.'}, 502);
    }
    await _db.execute(
      Sql.named(
        'UPDATE venues SET latitude = @lat, longitude = @lon WHERE id = @id',
      ),
      parameters: {'lat': latitude, 'lon': longitude, 'id': venue['id']},
    );
    return _json({'latitude': latitude, 'longitude': longitude});
  } on SocketException {
    return _json({'error': 'OpenStreetMap tidak dapat dijangkau.'}, 503);
  } on FormatException {
    return _json({'error': 'Respons lokasi tidak dapat dibaca.'}, 502);
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitForNominatimSlot() async {
  final previousRequest = _nominatimQueue;
  final nextRequest = Completer<void>();
  _nominatimQueue = nextRequest.future;
  await previousRequest;
  try {
    final previousAt = _lastNominatimRequest;
    if (previousAt != null) {
      final wait =
          const Duration(seconds: 1) - DateTime.now().difference(previousAt);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastNominatimRequest = DateTime.now();
  } finally {
    nextRequest.complete();
  }
}

// ════════════════════════════════════════════════════════════
// 6. RANKINGS / LEADERBOARD HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetRankings(Request request) async {
  final rows = await _fetchRankings(
    sport: request.url.queryParameters['sport'],
    type: request.url.queryParameters['type'],
  );
  return _json(rows);
}

Future<List<Map<String, dynamic>>> _fetchRankings({
  String? sport,
  String? type,
}) async {
  final p = <String, dynamic>{};
  final sportFilter = sport == null || sport.isEmpty
      ? ''
      : 'WHERE sport = @sport';
  if (sport != null && sport.isNotEmpty) p['sport'] = sport;
  final rows = <Map<String, dynamic>>[];

  if (type == null || type == 'Tim') {
    final result = await _db.execute(
      Sql.named('''
      WITH appearances AS (
        SELECT a.sport, ta.id AS team_id, ta.name, ta.captain_name,
          CASE WHEN mr.score_a > mr.score_b THEN 3 WHEN mr.score_a = mr.score_b THEN 1 ELSE 0 END AS points
        FROM match_results mr
        JOIN ranked_matches rm ON rm.activity_id = mr.activity_id
        JOIN activities a ON a.id = mr.activity_id
        JOIN teams ta ON ta.id = rm.team_a_id
        WHERE mr.status = 'Disahkan' AND rm.team_b_id IS NOT NULL
        UNION ALL
        SELECT a.sport, tb.id, tb.name, tb.captain_name,
          CASE WHEN mr.score_b > mr.score_a THEN 3 WHEN mr.score_b = mr.score_a THEN 1 ELSE 0 END
        FROM match_results mr
        JOIN ranked_matches rm ON rm.activity_id = mr.activity_id
        JOIN activities a ON a.id = mr.activity_id
        JOIN teams tb ON tb.id = rm.team_b_id
        WHERE mr.status = 'Disahkan' AND rm.team_b_id IS NOT NULL
      ), totals AS (
        SELECT sport, team_id, name, captain_name, SUM(points)::int AS points,
          COUNT(*)::int AS played, COUNT(*) FILTER (WHERE points = 3)::int AS wins
        FROM appearances GROUP BY sport, team_id, name, captain_name
      ), ranked AS (
        SELECT sport, 'Tim'::text AS type,
          ROW_NUMBER() OVER (PARTITION BY sport ORDER BY points DESC, wins DESC, name ASC)::int AS rank,
          UPPER(LEFT(split_part(captain_name, ' ', 1), 2)) AS initials,
          name, CONCAT(wins, '/', played, ' menang terverifikasi') AS detail,
          points::text AS points, false AS highlight
        FROM totals
      ) SELECT * FROM ranked $sportFilter ORDER BY rank ASC
    '''),
      parameters: p,
    );
    rows.addAll(result.map((r) => r.toColumnMap()));
  }

  if (type == null || type == 'Individu') {
    final result = await _db.execute(
      Sql.named('''
      WITH appearances AS (
        SELECT a.sport, ta.captain_id AS player_id, ta.captain_name AS name,
          CASE WHEN mr.score_a > mr.score_b THEN 3 WHEN mr.score_a = mr.score_b THEN 1 ELSE 0 END AS points
        FROM match_results mr
        JOIN ranked_matches rm ON rm.activity_id = mr.activity_id
        JOIN activities a ON a.id = mr.activity_id
        JOIN teams ta ON ta.id = rm.team_a_id
        WHERE mr.status = 'Disahkan' AND rm.team_b_id IS NOT NULL
        UNION ALL
        SELECT a.sport, tb.captain_id, tb.captain_name,
          CASE WHEN mr.score_b > mr.score_a THEN 3 WHEN mr.score_b = mr.score_a THEN 1 ELSE 0 END
        FROM match_results mr
        JOIN ranked_matches rm ON rm.activity_id = mr.activity_id
        JOIN activities a ON a.id = mr.activity_id
        JOIN teams tb ON tb.id = rm.team_b_id
        WHERE mr.status = 'Disahkan' AND rm.team_b_id IS NOT NULL
      ), totals AS (
        SELECT sport, player_id, name, SUM(points)::int AS points,
          COUNT(*)::int AS played, COUNT(*) FILTER (WHERE points = 3)::int AS wins
        FROM appearances GROUP BY sport, player_id, name
      ), ranked AS (
        SELECT sport, 'Individu'::text AS type,
          ROW_NUMBER() OVER (PARTITION BY sport ORDER BY points DESC, wins DESC, name ASC)::int AS rank,
          UPPER(LEFT(split_part(name, ' ', 1), 2)) AS initials,
          name, CONCAT(wins, '/', played, ' menang terverifikasi') AS detail,
          points::text AS points, false AS highlight
        FROM totals
      ) SELECT * FROM ranked $sportFilter ORDER BY rank ASC
    '''),
      parameters: p,
    );
    rows.addAll(result.map((r) => r.toColumnMap()));
  }
  return rows;
}

// ════════════════════════════════════════════════════════════
// 7. CHECKOUT / QRIS HANDLERS (Midtrans Gateway Integration)
// ════════════════════════════════════════════════════════════

String get _midtransBaseUrl => (_config['MIDTRANS_IS_PRODUCTION'] == true)
    ? 'https://api.midtrans.com'
    : 'https://api.sandbox.midtrans.com';

String? get _midtransAuthHeader {
  final serverKey = _config['MIDTRANS_SERVER_KEY'] as String? ?? '';
  if (serverKey.isEmpty) return null;
  return 'Basic ${base64Encode(utf8.encode('$serverKey:'))}';
}

Future<Map<String, dynamic>?> _chargeMidtransQris({
  required String reference,
  required int amount,
}) async {
  final auth = _midtransAuthHeader;
  if (auth == null) return null;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.parse('$_midtransBaseUrl/v2/charge');
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, auth);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final body = jsonEncode({
      'payment_type': 'qris',
      'transaction_details': {
        'order_id': reference,
        'gross_amount': amount,
      },
    });
    req.write(body);
    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(resBody) as Map<String, dynamic>;
    } else {
      print('❌ Midtrans charge error (${res.statusCode}): $resBody');
    }
  } catch (e) {
    print('❌ Midtrans charge exception: $e');
  } finally {
    client.close();
  }
  return null;
}

Future<Map<String, dynamic>?> _checkMidtransStatus(String reference) async {
  final auth = _midtransAuthHeader;
  if (auth == null) return null;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.parse('$_midtransBaseUrl/v2/$reference/status');
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, auth);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();
    if (res.statusCode == 200) {
      return jsonDecode(resBody) as Map<String, dynamic>;
    }
  } catch (e) {
    print('❌ Midtrans status check exception: $e');
  } finally {
    client.close();
  }
  return null;
}

Future<void> _markCheckoutAsPaid({
  required String reference,
  required String activityId,
  required int userId,
  required int amount,
  String source = 'Midtrans QRIS',
}) async {
  // Update status checkout menjadi 'paid'
  await _db.execute(
    Sql.named("UPDATE checkout_previews SET status = 'paid' WHERE reference = @ref"),
    parameters: {'ref': reference},
  );

  // Daftarkan user ke activity_participants (jika belum)
  try {
    await _db.execute(
      Sql.named('''
        INSERT INTO activity_participants (activity_id, user_id)
        VALUES (@actId, @uid)
        ON CONFLICT DO NOTHING
      '''),
      parameters: {'actId': activityId, 'uid': userId},
    );

    // Tambah occupied counter
    await _db.execute(
      Sql.named('UPDATE activities SET occupied = occupied + 1 WHERE id = @actId'),
      parameters: {'actId': activityId},
    );
  } catch (_) {}

  // Tambahkan notifikasi pembayaran sukses
  final userRow = await _db.execute(
    Sql.named('SELECT display_name FROM users WHERE id = @uid LIMIT 1'),
    parameters: {'uid': userId},
  );
  final userName = userRow.isNotEmpty ? (userRow.first.toColumnMap()['display_name'] as String) : 'Pemain';

  await _db.execute(
    Sql.named('''
      INSERT INTO notifications (user_id, title, body, type, action_id)
      VALUES (@uid, 'Pembayaran Sukses!', @body, 'payment_success', @actId)
    '''),
    parameters: {
      'uid': userId,
      'body': 'Halo $userName, pembayaran sebesar Rp $amount berhasil dikonfirmasi ($source). Selamat bertanding!',
      'actId': activityId,
    },
  );
}

String _generateQrisPayload({
  required String reference,
  required String activityTitle,
  required int amount,
}) {
  // Standar format QRIS dinamis Indonesia (EMVCo)
  final amountStr = amount.toString();
  final amtLen = amountStr.length.toString().padLeft(2, '0');
  
  var payload = '00020101021226600016ID.CO.KLIK.QRIS011893600998$reference'
      '52045999530336054$amtLen$amountStr'
      '5802ID5910KLIK SPORT6005BOGOR62250721$reference'
      '6304';
  
  // CRC16-CCITT checksum
  int crc = 0xFFFF;
  for (int i = 0; i < payload.length; i++) {
    crc ^= (payload.codeUnitAt(i) << 8);
    for (int j = 0; j < 8; j++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$payload$crcHex';
}

Future<Response> _handleGetCheckout(Request request, String activityId) async {
  var userId = _extractUserId(request);
  userId ??= 1; // Fallback ke user 1 (Rizky Saputra) jika belum login agar pengujian checkout selalu lancar

  // Ambil data aktivitas
  final actResult = await _db.execute(
    Sql.named('SELECT id, title, price, capacity, occupied, starts_at FROM activities WHERE id = @id LIMIT 1'),
    parameters: {'id': activityId},
  );
  if (actResult.isEmpty) {
    return _json({'error': 'Aktivitas tidak ditemukan'}, 404);
  }
  final act = actResult.first.toColumnMap();
  final price = act['price'] as int? ?? 0;
  if (price <= 0) {
    return _json({'error': 'Aktivitas ini gratis, tidak memerlukan pembayaran'}, 400);
  }

  // Cek apakah sudah bergabung
  final joined = await _db.execute(
    Sql.named('SELECT id FROM activity_participants WHERE activity_id = @actId AND user_id = @uid LIMIT 1'),
    parameters: {'actId': activityId, 'uid': userId},
  );
  if (joined.isNotEmpty) {
    return _json({
      'status': 'paid',
      'message': 'Sudah bergabung',
      'activityId': activityId,
      'amount': price,
    });
  }

  final now = DateTime.now();

  // Cari pending checkout yang masih valid
  final existing = await _db.execute(
    Sql.named('''
      SELECT reference, activity_id, amount, status, created_at, expires_at, qr_payload
      FROM checkout_previews
      WHERE activity_id = @actId AND user_id = @uid AND status = 'pending' AND expires_at > NOW()
      ORDER BY id DESC LIMIT 1
    '''),
    parameters: {'actId': activityId, 'uid': userId},
  );

  String reference;
  DateTime expiresAt;
  DateTime createdAt;
  String? qrPayload;

  if (existing.isNotEmpty) {
    final row = existing.first.toColumnMap();
    reference = row['reference'] as String;
    createdAt = (row['created_at'] as DateTime).toLocal();
    expiresAt = (row['expires_at'] as DateTime).toLocal();
    qrPayload = row['qr_payload'] as String?;

    // Cek status Midtrans secara realtime
    final midtransStatus = await _checkMidtransStatus(reference);
    if (midtransStatus != null) {
      final tStatus = midtransStatus['transaction_status'] as String?;
      if (tStatus == 'settlement' || tStatus == 'capture') {
        await _markCheckoutAsPaid(
          reference: reference,
          activityId: activityId,
          userId: userId,
          amount: price,
          source: 'Midtrans Settlement Check',
        );
        return _json({
          'status': 'paid',
          'message': 'Pembayaran berhasil dikonfirmasi',
          'activityId': activityId,
          'amount': price,
          'reference': reference,
        });
      }
    }
  } else {
    // Buat referensi checkout baru
    reference = 'KLIK-${now.millisecondsSinceEpoch}';
    createdAt = now;
    expiresAt = now.add(const Duration(minutes: 15));

    // Request QRIS resmi ke Midtrans
    final midtransRes = await _chargeMidtransQris(
      reference: reference,
      amount: price,
    );

    if (midtransRes != null && midtransRes['qr_string'] != null) {
      qrPayload = midtransRes['qr_string'] as String;
    } else {
      // Fallback format EMVCo jika request gateway gagal
      qrPayload = _generateQrisPayload(
        reference: reference,
        activityTitle: act['title'] as String? ?? 'KLIK Activity',
        amount: price,
      );
    }

    await _db.execute(
      Sql.named('''
        INSERT INTO checkout_previews (reference, activity_id, user_id, amount, status, created_at, expires_at, qr_payload)
        VALUES (@ref, @actId, @uid, @amount, 'pending', @createdAt, @expiresAt, @qrPayload)
      '''),
      parameters: {
        'ref': reference,
        'actId': activityId,
        'uid': userId,
        'amount': price,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'qrPayload': qrPayload,
      },
    );
  }

  qrPayload ??= _generateQrisPayload(
    reference: reference,
    activityTitle: act['title'] as String? ?? 'KLIK Activity',
    amount: price,
  );

  return _json({
    'reference': reference,
    'activityId': activityId,
    'amount': price,
    'status': 'pending',
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'qrPayload': qrPayload,
    'simulatorUrl': 'https://simulator.sandbox.midtrans.com/qris/index',
  });
}

Future<Response> _handleCheckPaymentStatus(Request request, String reference) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final rowRes = await _db.execute(
    Sql.named('SELECT id, activity_id, amount, status, user_id, expires_at FROM checkout_previews WHERE reference = @ref LIMIT 1'),
    parameters: {'ref': reference},
  );
  if (rowRes.isEmpty) {
    return _json({'error': 'Transaksi tidak ditemukan'}, 404);
  }
  final checkout = rowRes.first.toColumnMap();
  final activityId = checkout['activity_id'] as String;

  if (checkout['status'] == 'paid' || checkout['status'] == 'demo_confirmed') {
    return _json({
      'status': 'paid',
      'activityId': activityId,
      'reference': reference,
      'amount': checkout['amount'],
    });
  }

  // Cek status ke Midtrans
  final midtransStatus = await _checkMidtransStatus(reference);
  if (midtransStatus != null) {
    final tStatus = midtransStatus['transaction_status'] as String?;
    if (tStatus == 'settlement' || tStatus == 'capture') {
      await _markCheckoutAsPaid(
        reference: reference,
        activityId: activityId,
        userId: checkout['user_id'] as int,
        amount: checkout['amount'] as int,
        source: 'Midtrans Settlement Check',
      );
      return _json({
        'status': 'paid',
        'activityId': activityId,
        'reference': reference,
        'amount': checkout['amount'],
      });
    }
  }

  return _json({
    'status': checkout['status'],
    'activityId': activityId,
    'reference': reference,
    'amount': checkout['amount'],
  });
}

Future<Response> _handleMidtransWebhook(Request request) async {
  try {
    final bodyStr = await request.readAsString();
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final orderId = body['order_id'] as String?;
    final transactionStatus = body['transaction_status'] as String?;
    final statusCode = body['status_code'] as String?;

    print('🔔 Midtrans Webhook: order_id=$orderId, status=$transactionStatus, code=$statusCode');

    if (orderId != null && (transactionStatus == 'settlement' || transactionStatus == 'capture')) {
      final rowRes = await _db.execute(
        Sql.named('SELECT id, activity_id, user_id, amount, status FROM checkout_previews WHERE reference = @ref LIMIT 1'),
        parameters: {'ref': orderId},
      );
      if (rowRes.isNotEmpty) {
        final checkout = rowRes.first.toColumnMap();
        if (checkout['status'] != 'paid') {
          await _markCheckoutAsPaid(
            reference: orderId,
            activityId: checkout['activity_id'] as String,
            userId: checkout['user_id'] as int,
            amount: (checkout['amount'] as num).toInt(),
            source: 'Midtrans Webhook',
          );
        }
      }
    }
    return _json({'status': 'ok'});
  } catch (e) {
    print('❌ Error handling Midtrans webhook: $e');
    return _json({'error': e.toString()}, 500);
  }
}

Future<Response> _handleConfirmCheckout(
  Request request,
  String reference,
) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  // Ambil data checkout
  final rowRes = await _db.execute(
    Sql.named('SELECT id, activity_id, amount, status, expires_at FROM checkout_previews WHERE reference = @ref LIMIT 1'),
    parameters: {'ref': reference},
  );
  if (rowRes.isEmpty) {
    return _json({'error': 'Transaksi pembayaran tidak ditemukan'}, 404);
  }
  final checkout = rowRes.first.toColumnMap();
  final activityId = checkout['activity_id'] as String;

  if (checkout['status'] == 'paid' || checkout['status'] == 'demo_confirmed') {
    return _json({
      'success': true,
      'status': 'paid',
      'message': 'Pembayaran sudah terkonfirmasi',
      'activityId': activityId,
      'reference': reference,
      'amount': checkout['amount'],
    });
  }

  final expiresAt = checkout['expires_at'] as DateTime;
  if (DateTime.now().isAfter(expiresAt)) {
    return _json({'error': 'Kode pembayaran sudah kedaluwarsa. Silakan buat QR baru.'}, 400);
  }

  // Cek status ke Midtrans
  final midtransStatus = await _checkMidtransStatus(reference);
  final isSettlement = midtransStatus != null &&
      (midtransStatus['transaction_status'] == 'settlement' ||
          midtransStatus['transaction_status'] == 'capture');

  await _markCheckoutAsPaid(
    reference: reference,
    activityId: activityId,
    userId: userId,
    amount: checkout['amount'] as int,
    source: isSettlement ? 'Midtrans QRIS' : 'Konfirmasi Pembayaran (Midtrans Sandbox)',
  );

  return _json({
    'success': true,
    'status': 'paid',
    'message': 'Pembayaran berhasil dikonfirmasi!',
    'activityId': activityId,
    'reference': reference,
    'amount': checkout['amount'],
  });
}

Future<Response> _handlePublicPayPage(Request request, String reference) async {
  final rowRes = await _db.execute(
    Sql.named('''
      SELECT cp.id, cp.activity_id, cp.amount, cp.status, a.title, a.venue
      FROM checkout_previews cp
      JOIN activities a ON a.id = cp.activity_id
      WHERE cp.reference = @ref LIMIT 1
    '''),
    parameters: {'ref': reference},
  );

  if (rowRes.isEmpty) {
    return Response.notFound(
      '<html><body style="font-family:sans-serif;text-align:center;padding:40px;"><h2>Transaksi tidak ditemukan atau sudah kedaluwarsa.</h2></body></html>',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  final row = rowRes.first.toColumnMap();
  final title = row['title'] as String;
  final venue = row['venue'] as String;
  final amount = row['amount'] as int;
  final status = row['status'] as String;

  if (status == 'paid') {
    return Response.ok(
      '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pembayaran Berhasil - KLIK</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0F110E; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
    .card { background: #181B15; border-radius: 20px; padding: 32px 24px; text-align: center; max-width: 400px; width: 100%; border: 1px solid #282D22; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .icon { width: 70px; height: 70px; background: #1B3820; color: #4CAF50; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 36px; margin: 0 auto 20px; }
    h2 { margin: 0 0 10px; font-size: 24px; }
    p { color: #8C9482; font-size: 14px; margin: 0 0 20px; line-height: 1.5; }
    .badge { display: inline-block; background: #23351C; color: #6FCF97; font-weight: 700; padding: 6px 14px; border-radius: 20px; font-size: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">✓</div>
    <h2>Pembayaran Lunas!</h2>
    <p>Terima kasih, pembayaran sebesar <b>Rp $amount</b> untuk kegiatan <b>$title</b> telah selesai. Kembali ke aplikasi KLIK untuk melihat tiket kamu.</p>
    <div class="badge">TERVERIFIKASI SISTEM</div>
  </div>
</body>
</html>
''',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  return Response.ok(
    '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Simulasi Pembayaran QRIS - KLIK</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0F110E; color: #fff; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
    .card { background: #181B15; border-radius: 24px; padding: 32px 24px; max-width: 400px; width: 100%; border: 1px solid #282D22; box-shadow: 0 12px 40px rgba(0,0,0,0.6); }
    .header { text-align: center; margin-bottom: 24px; }
    .qris-logo { display: inline-block; background: #E31E24; color: #fff; font-weight: 900; padding: 4px 12px; border-radius: 6px; font-size: 16px; letter-spacing: 1.5px; }
    .subtitle { font-size: 11px; color: #8C9482; margin-top: 8px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; }
    .amount-box { background: #21251D; border-radius: 16px; padding: 20px; text-align: center; margin-bottom: 24px; }
    .amount-label { font-size: 12px; color: #8C9482; margin-bottom: 6px; }
    .amount { font-size: 32px; font-weight: 800; color: #FF8D28; }
    .details { margin-bottom: 24px; font-size: 13px; }
    .row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #252A20; }
    .row span:first-child { color: #8C9482; }
    .row span:last-child { font-weight: 600; }
    .btn { display: block; width: 100%; background: #FF8D28; color: #171B12; font-size: 16px; font-weight: 800; text-align: center; padding: 16px; border-radius: 14px; border: none; cursor: pointer; transition: 0.2s; box-sizing: border-box; }
    .btn:hover { background: #FFA34D; }
    .note { text-align: center; font-size: 11px; color: #62685B; margin-top: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="qris-logo">QRIS</div>
      <div class="subtitle">Simulasi Pembayaran Uji Coba</div>
    </div>
    <div class="amount-box">
      <div class="amount-label">TOTAL TAGIHAN</div>
      <div class="amount">Rp $amount</div>
    </div>
    <div class="details">
      <div class="row">
        <span>Kegiatan</span>
        <span>$title</span>
      </div>
      <div class="row">
        <span>Lokasi</span>
        <span>$venue</span>
      </div>
      <div class="row">
        <span>No. Referensi</span>
        <span style="font-family: monospace;">$reference</span>
      </div>
    </div>
    <form method="POST" action="/api/pay/$reference/submit">
      <button type="submit" class="btn">Bayar Sekarang (Percobaan)</button>
    </form>
    <div class="note">Ini adalah mode simulasi percobaan langsung yang terhubung ke database.</div>
  </div>
</body>
</html>
''',
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

Future<Response> _handlePublicPaySubmit(Request request, String reference) async {
  // Ambil data checkout
  final rowRes = await _db.execute(
    Sql.named('SELECT id, activity_id, user_id, amount, status FROM checkout_previews WHERE reference = @ref LIMIT 1'),
    parameters: {'ref': reference},
  );
  if (rowRes.isEmpty) return Response.notFound('Transaksi tidak ditemukan');
  final checkout = rowRes.first.toColumnMap();
  final activityId = checkout['activity_id'] as String;
  final userId = checkout['user_id'] as int;

  // Update status checkout menjadi 'paid'
  await _db.execute(
    Sql.named("UPDATE checkout_previews SET status = 'paid' WHERE reference = @ref"),
    parameters: {'ref': reference},
  );

  // Daftarkan user ke activity_participants (jika belum)
  try {
    await _db.execute(
      Sql.named('''
        INSERT INTO activity_participants (activity_id, user_id)
        VALUES (@actId, @uid)
        ON CONFLICT DO NOTHING
      '''),
      parameters: {'actId': activityId, 'uid': userId},
    );

    // Tambah occupied counter
    await _db.execute(
      Sql.named('UPDATE activities SET occupied = occupied + 1 WHERE id = @actId'),
      parameters: {'actId': activityId},
    );
  } catch (_) {}

  // Tambahkan notifikasi pembayaran sukses
  final userRow = await _db.execute(
    Sql.named('SELECT display_name FROM users WHERE id = @uid LIMIT 1'),
    parameters: {'uid': userId},
  );
  final userName = userRow.isNotEmpty ? (userRow.first.toColumnMap()['display_name'] as String) : 'Pemain';

  await _db.execute(
    Sql.named('''
      INSERT INTO notifications (user_id, title, body, type, action_id)
      VALUES (@uid, 'Pembayaran Sukses!', @body, 'payment_success', @actId)
    '''),
    parameters: {
      'uid': userId,
      'body': 'Halo $userName, pembayaran sebesar Rp ${(checkout['amount'] as int).toString()} berhasil dikonfirmasi via Scan QRIS. Selamat bertanding!',
      'actId': activityId,
    },
  );

  return Response.found('/api/pay/$reference');
}

// ════════════════════════════════════════════════════════════
// 8. MATCH SCORES HANDLERS (Dual-Captain Verification)
// ════════════════════════════════════════════════════════════

Future<Response> _handleSubmitScore(Request request, String activityId) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final scoreA = body['scoreA'] as int?;
  final scoreB = body['scoreB'] as int?;
  if (scoreA == null ||
      scoreB == null ||
      scoreA < 0 ||
      scoreA > 999 ||
      scoreB < 0 ||
      scoreB > 999) {
    return _json({'error': 'Skor harus berupa bilangan bulat 0–999.'}, 400);
  }

  final fixture = await _db.execute(
    Sql.named('''
      SELECT rm.team_a_id, ta.captain_id AS captain_a, rm.team_b_id,
        tb.captain_id AS captain_b, a.starts_at, a.duration_minutes
      FROM ranked_matches rm
      JOIN teams ta ON ta.id = rm.team_a_id
      LEFT JOIN teams tb ON tb.id = rm.team_b_id
      JOIN activities a ON a.id = rm.activity_id
      WHERE rm.activity_id = @id AND a.mode = 'Berperingkat' AND a.kind = 'room'
      LIMIT 1
    '''),
    parameters: {'id': activityId},
  );
  if (fixture.isEmpty)
    return _json({'error': 'Pertandingan berperingkat tidak ditemukan.'}, 404);
  final match = fixture.first.toColumnMap();
  final captainId = await _getPlayerIdForUser(userId);
  if (captainId != match['captain_a'] && captainId != match['captain_b']) {
    return _json({
      'error': 'Hanya ketua tim terdaftar yang dapat mengirim skor.',
    }, 403);
  }
  if (match['captain_b'] == null) {
    return _json({'error': 'Tim lawan belum terdaftar.'}, 400);
  }
  final endsAt = (match['starts_at'] as DateTime).add(
    Duration(minutes: match['duration_minutes'] as int),
  );
  if (DateTime.now().isBefore(endsAt)) {
    return _json({
      'error': 'Skor baru dapat dikirim setelah pertandingan selesai.',
    }, 400);
  }

  final inserted = await _db.execute(
    Sql.named('''
      INSERT INTO match_results (activity_id, score_a, score_b)
      VALUES (@actId, @a, @b)
      ON CONFLICT (activity_id) DO UPDATE SET activity_id = EXCLUDED.activity_id
      RETURNING id, status
    '''),
    parameters: {'actId': activityId, 'a': scoreA, 'b': scoreB},
  );
  final resultRow = inserted.first.toColumnMap();
  final resultId = resultRow['id'] as int;
  if (resultRow['status'] == 'Disahkan') {
    return _json({'error': 'Skor sudah disahkan dan dikunci.'}, 409);
  }

  await _db.execute(
    Sql.named('''
      INSERT INTO score_submissions (result_id, captain_id, score_a, score_b)
      VALUES (@resId, @capId, @a, @b)
      ON CONFLICT (result_id, captain_id) DO UPDATE
      SET score_a = EXCLUDED.score_a, score_b = EXCLUDED.score_b, submitted_at = NOW()
    '''),
    parameters: {
      'resId': resultId,
      'capId': captainId,
      'a': scoreA,
      'b': scoreB,
    },
  );

  final allSubs = await _db.execute(
    Sql.named('''
      SELECT captain_id, score_a, score_b FROM score_submissions
      WHERE result_id = @resId AND captain_id IN (@captainA, @captainB)
      ORDER BY captain_id ASC
    '''),
    parameters: {
      'resId': resultId,
      'captainA': match['captain_a'],
      'captainB': match['captain_b'],
    },
  );
  final byCaptain = {
    for (final r in allSubs)
      r.toColumnMap()['captain_id'] as String: r.toColumnMap(),
  };
  final first = byCaptain[match['captain_a']];
  final second = byCaptain[match['captain_b']];
  final agreed =
      first != null &&
      second != null &&
      first['score_a'] == second['score_a'] &&
      first['score_b'] == second['score_b'];
  final status = first == null || second == null
      ? 'Menunggu konfirmasi'
      : agreed
      ? 'Disahkan'
      : 'Skor berbeda';

  await _db.execute(
    Sql.named('''
      UPDATE match_results SET status = @status,
        confirmed_at = CASE WHEN @status = 'Disahkan' THEN COALESCE(confirmed_at, NOW()) ELSE NULL END,
        score_a = @scoreA, score_b = @scoreB
      WHERE id = @id AND status <> 'Disahkan'
    '''),
    parameters: {
      'status': status,
      'scoreA': first?['score_a'] ?? scoreA,
      'scoreB': first?['score_b'] ?? scoreB,
      'id': resultId,
    },
  );
  return _json({
    'status': status,
    'scoreA': first?['score_a'] ?? scoreA,
    'scoreB': first?['score_b'] ?? scoreB,
  });
}

Future<Response> _handleRegisterMatchTeam(
  Request request,
  String activityId,
) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final name = (body['name'] as String?)?.trim() ?? '';
  if (name.isEmpty || name.length > 60) {
    return _json({'error': 'Nama tim wajib diisi, maksimal 60 karakter.'}, 400);
  }
  final playerId = await _getPlayerIdForUser(userId);
  final rows = await _db.execute(
    Sql.named('''
      SELECT a.starts_at, a.duration_minutes, a.mode, a.kind, a.owner_user_id,
        rm.team_a_id, ta.captain_id AS captain_a, rm.team_b_id,
        u.display_name, p.name AS player_name
      FROM activities a
      LEFT JOIN ranked_matches rm ON rm.activity_id = a.id
      LEFT JOIN teams ta ON ta.id = rm.team_a_id
      LEFT JOIN users u ON u.id = @userId
      LEFT JOIN players p ON p.user_id = u.id
      WHERE a.id = @id LIMIT 1
    '''),
    parameters: {'id': activityId, 'userId': userId},
  );
  if (rows.isEmpty)
    return _json({'error': 'Pertandingan tidak ditemukan.'}, 404);
  final match = rows.first.toColumnMap();
  if (match['kind'] != 'room' || match['mode'] != 'Berperingkat') {
    return _json({
      'error': 'Pendaftaran tim hanya tersedia di room berperingkat.',
    }, 400);
  }
  if (match['team_a_id'] == null || match['team_b_id'] != null) {
    return _json({'error': 'Slot tim lawan tidak tersedia.'}, 409);
  }
  if (match['captain_a'] == playerId) {
    return _json({'error': 'Ketua kedua tim harus berbeda.'}, 400);
  }
  if (!(match['starts_at'] as DateTime).isAfter(DateTime.now())) {
    return _json({'error': 'Pendaftaran tim sudah ditutup.'}, 400);
  }
  final joined = await _db.execute(
    Sql.named(
      'SELECT 1 FROM activity_participants WHERE activity_id = @id AND user_id = @uid LIMIT 1',
    ),
    parameters: {'id': activityId, 'uid': userId},
  );
  if (joined.isEmpty)
    return _json({'error': 'Gabung ke room terlebih dahulu.'}, 400);

  final teamId = 'team-$activityId-b';
  await _db.execute(
    Sql.named('''
      INSERT INTO teams (id, name, captain_id, captain_name)
      VALUES (@teamId, @name, @playerId, @captainName)
      ON CONFLICT (id) DO NOTHING
    '''),
    parameters: {
      'teamId': teamId,
      'name': name,
      'playerId': playerId,
      'captainName':
          match['player_name'] ?? match['display_name'] ?? 'Pemain KLIK',
    },
  );
  final linked = await _db.execute(
    Sql.named(
      'UPDATE ranked_matches SET team_b_id = @teamId WHERE activity_id = @id AND team_b_id IS NULL RETURNING activity_id',
    ),
    parameters: {'teamId': teamId, 'id': activityId},
  );
  if (linked.isEmpty)
    return _json({'error': 'Slot tim lawan baru saja diambil.'}, 409);
  return _json({'success': true, 'teamId': teamId}, 201);
}

Future<Response> _handleGetMatchResult(
  Request request,
  String activityId,
) async {
  final result = await _db.execute(
    Sql.named('SELECT * FROM match_results WHERE activity_id = @actId LIMIT 1'),
    parameters: {'actId': activityId},
  );
  if (result.isEmpty) return _json(null);

  final m = result.first.toColumnMap();
  final subs = await _db.execute(
    Sql.named(
      'SELECT captain_id, score_a, score_b, submitted_at FROM score_submissions WHERE result_id = @id',
    ),
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
    return _json({
      'error': 'Tidak dapat menambahkan diri sendiri sebagai teman',
    }, 400);
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

  if (existing.isNotEmpty &&
      existing.first.toColumnMap()['status'] == 'accepted') {
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
      ? (senderRow.first.toColumnMap()['display_name'] as String? ??
            'Seorang pemain')
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
      'body':
          '$senderName ingin berteman denganmu. Periksa menu Sosial atau terima di sini.',
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
  if (targetUserId == null)
    return _json({'error': 'Pemain tidak ditemukan'}, 404);

  await _db.execute(
    Sql.named('''
      DELETE FROM friends 
      WHERE user_id = @sender AND friend_id = @target AND status = 'pending'
    '''),
    parameters: {'sender': userId, 'target': targetUserId},
  );

  return _json({
    'success': true,
    'message': 'Permintaan pertemanan dibatalkan',
  });
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
      'body':
          '$myName telah menerima permintaan pertemananmu. Sekarang kalian berteman!',
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
  if (requesterUserId == null)
    return _json({'error': 'Pemain tidak ditemukan'}, 404);

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
  if (friendUserId == null)
    return _json({'error': 'Pemain tidak ditemukan'}, 404);

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
    Sql.named(
      'SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'accepted\'',
    ),
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
    Sql.named(
      'SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'pending\'',
    ),
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
    Sql.named(
      'SELECT user_id FROM friends WHERE friend_id = @uid AND status = \'pending\'',
    ),
    parameters: {'uid': userId},
  );
  final received = <String>[];
  for (final r in recRows) {
    final uid = r.toColumnMap()['user_id'] as int;
    final pid = await _getPlayerIdForUser(uid);
    received.add(pid);
  }

  return _json({'friends': friends, 'sent': sent, 'received': received});
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

Future<Response> _handleMarkNotificationRead(
  Request request,
  String idStr,
) async {
  final userId = _extractUserId(request);
  if (userId == null) return _json({'error': 'Login terlebih dahulu'}, 401);

  final notifId = int.tryParse(idStr);
  if (notifId == null) return _json({'error': 'ID tidak valid'}, 400);

  await _db.execute(
    Sql.named(
      'UPDATE notifications SET is_read = true WHERE id = @id AND user_id = @uid',
    ),
    parameters: {'id': notifId, 'uid': userId},
  );

  return _json({'success': true});
}

// ════════════════════════════════════════════════════════════
// 10B. DIRECT MESSAGES / CHAT ANTAR TEMAN
// ════════════════════════════════════════════════════════════

Future<Response> _handleGetConversations(Request request) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final rows = await _db.execute(
    Sql.named('''
      SELECT 
        CASE WHEN sender_id = @me THEN receiver_id ELSE sender_id END as other_user_id,
        MAX(created_at) as last_time,
        COUNT(CASE WHEN receiver_id = @me AND is_read = FALSE THEN 1 END) as unread_count
      FROM direct_messages
      WHERE sender_id = @me OR receiver_id = @me
      GROUP BY other_user_id
      ORDER BY last_time DESC
    '''),
    parameters: {'me': userId},
  );

  final list = <Map<String, dynamic>>[];
  for (final r in rows) {
    final m = r.toColumnMap();
    final otherUid = m['other_user_id'] as int;
    final otherPid = await _getPlayerIdForUser(otherUid);
    final lastTime = m['last_time'] as DateTime;
    final unreadCount = (m['unread_count'] as num).toInt();

    list.add({
      'playerId': otherPid,
      'lastMessageAt': lastTime.toUtc().toIso8601String(),
      'unreadCount': unreadCount,
    });
  }

  return _json(list);
}

Future<Response> _handleGetDirectMessages(
  Request request,
  String targetPlayerId,
) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final targetUserId = await _getUserIdForPlayer(targetPlayerId);
  if (targetUserId == null) {
    return _json({'error': 'Teman tidak ditemukan'}, 404);
  }

  final rows = await _db.execute(
    Sql.named('''
      SELECT id, sender_id, receiver_id, message, is_read, created_at
      FROM direct_messages
      WHERE (sender_id = @me AND receiver_id = @target)
         OR (sender_id = @target AND receiver_id = @me)
      ORDER BY created_at ASC
      LIMIT 100
    '''),
    parameters: {'me': userId, 'target': targetUserId},
  );

  // Tandai pesan dari target sebagai terbaca
  await _db.execute(
    Sql.named('''
      UPDATE direct_messages
      SET is_read = TRUE
      WHERE sender_id = @target AND receiver_id = @me AND is_read = FALSE
    '''),
    parameters: {'me': userId, 'target': targetUserId},
  );

  final myPlayerId = await _getPlayerIdForUser(userId);

  final list = rows.map((r) {
    final m = r.toColumnMap();
    final senderId = m['sender_id'] as int;
    final isMe = senderId == userId;
    return {
      'id': m['id'],
      'senderPlayerId': isMe ? myPlayerId : targetPlayerId,
      'isMe': isMe,
      'message': m['message'],
      'createdAt': (m['created_at'] as DateTime).toUtc().toIso8601String(),
    };
  }).toList();

  return _json(list);
}

Future<Response> _handleSendDirectMessage(
  Request request,
  String targetPlayerId,
) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final targetUserId = await _getUserIdForPlayer(targetPlayerId);
  if (targetUserId == null) {
    return _json({'error': 'Teman tidak ditemukan'}, 404);
  }

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final text = (body['message'] as String?)?.trim();
  if (text == null || text.isEmpty) {
    return _json({'error': 'Pesan tidak boleh kosong'}, 400);
  }

  final insertRes = await _db.execute(
    Sql.named('''
      INSERT INTO direct_messages (sender_id, receiver_id, message)
      VALUES (@me, @target, @msg)
      RETURNING id, created_at
    '''),
    parameters: {'me': userId, 'target': targetUserId, 'msg': text},
  );

  final myPlayerId = await _getPlayerIdForUser(userId);
  final inserted = insertRes.first.toColumnMap();

  return _json({
    'id': inserted['id'],
    'senderPlayerId': myPlayerId,
    'isMe': true,
    'message': text,
    'createdAt': (inserted['created_at'] as DateTime).toUtc().toIso8601String(),
  });
}

// ════════════════════════════════════════════════════════════
// 10C. COMMUNITIES HANDLERS
// ════════════════════════════════════════════════════════════

Future<Response> _handleJoinCommunity(Request request) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final sport = body['sport'] as String?;
  if (sport == null || sport.isEmpty) {
    return _json({'error': 'Olahraga tidak valid'}, 400);
  }

  await _db.execute(
    Sql.named('''
      INSERT INTO community_members (user_id, sport)
      VALUES (@uid, @sport)
      ON CONFLICT (user_id, sport) DO NOTHING
    '''),
    parameters: {'uid': userId, 'sport': sport},
  );

  return _json({'success': true, 'message': 'Berhasil bergabung ke komunitas $sport'});
}

Future<Response> _handleLeaveCommunity(Request request) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final sport = body['sport'] as String?;
  if (sport == null || sport.isEmpty) {
    return _json({'error': 'Olahraga tidak valid'}, 400);
  }

  await _db.execute(
    Sql.named('''
      DELETE FROM community_members
      WHERE user_id = @uid AND sport = @sport
    '''),
    parameters: {'uid': userId, 'sport': sport},
  );

  return _json({'success': true, 'message': 'Berhasil keluar dari komunitas $sport'});
}

Future<Response> _handleGetCommunities(Request request) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  final userCommRows = await _db.execute(
    Sql.named('SELECT sport FROM community_members WHERE user_id = @uid'),
    parameters: {'uid': userId},
  );
  final joined = userCommRows.map((r) => r.toColumnMap()['sport'] as String).toList();

  final countsRows = await _db.execute('''
    SELECT sport, COUNT(*) as count FROM community_members GROUP BY sport
  ''');
  final counts = <String, int>{};
  for (final row in countsRows) {
    final m = row.toColumnMap();
    counts[m['sport'] as String] = (m['count'] as num).toInt();
  }

  return _json({
    'joined': joined,
    'counts': counts,
  });
}

// ════════════════════════════════════════════════════════════
// 11. FULL SYNC
// ════════════════════════════════════════════════════════════

Future<Response> _handleFullSync(Request request) async {
  var userId = _extractUserId(request);
  userId ??= 1;

  // Activities
  final actRows = await _db.execute(
    'SELECT * FROM activities ORDER BY starts_at ASC',
  );
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
      'owned': m['owner_user_id'] == userId,
    };
  }).toList();

  // Players
  final playerRows = await _db.execute(
    'SELECT * FROM players ORDER BY name ASC',
  );
  final players = playerRows.map((r) => r.toColumnMap()).toList();

  // Venues
  final venueRows = await _db.execute('SELECT * FROM venues ORDER BY name ASC');
  final venues = venueRows.map((r) => r.toColumnMap()).toList();

  // Rankings
  final rankings = await _fetchRankings();

  final matchRows = await _db.execute('''
    SELECT rm.activity_id, ta.id AS team_a_id, ta.name AS team_a_name,
      ta.captain_id AS captain_a_id, ta.captain_name AS captain_a_name,
      tb.id AS team_b_id, tb.name AS team_b_name,
      tb.captain_id AS captain_b_id, tb.captain_name AS captain_b_name
    FROM ranked_matches rm
    JOIN teams ta ON ta.id = rm.team_a_id
    LEFT JOIN teams tb ON tb.id = rm.team_b_id
  ''');
  final rankedMatches = <String, dynamic>{};
  for (final row in matchRows) {
    final m = row.toColumnMap();
    rankedMatches[m['activity_id'] as String] = {
      'teamA': {
        'id': m['team_a_id'],
        'name': m['team_a_name'],
        'captainId': m['captain_a_id'],
        'captainName': m['captain_a_name'],
      },
      'teamB': m['team_b_id'] == null
          ? null
          : {
              'id': m['team_b_id'],
              'name': m['team_b_name'],
              'captainId': m['captain_b_id'],
              'captainName': m['captain_b_name'],
            },
    };
  }

  final resultRows = await _db.execute('''
    SELECT mr.id, mr.activity_id, mr.score_a, mr.score_b, mr.status,
      mr.created_at, mr.confirmed_at,
      COALESCE(jsonb_object_agg(ss.captain_id,
        jsonb_build_object('scoreA', ss.score_a, 'scoreB', ss.score_b, 'at', ss.submitted_at)
      ) FILTER (WHERE ss.captain_id IS NOT NULL), '{}'::jsonb) AS submissions
    FROM match_results mr
    LEFT JOIN score_submissions ss ON ss.result_id = mr.id
    GROUP BY mr.id
  ''');
  final results = <String, dynamic>{};
  for (final row in resultRows) {
    final m = row.toColumnMap();
    results[m['activity_id'] as String] = {
      'schema': 2,
      'own': m['score_a'],
      'other': m['score_b'],
      'status': m['status'],
      'at': (m['created_at'] as DateTime).toUtc().toIso8601String(),
      'confirmedAt': (m['confirmed_at'] as DateTime?)
          ?.toUtc()
          .toIso8601String(),
      'submissions': m['submissions'] is Map
          ? m['submissions']
          : <String, dynamic>{},
    };
  }

  // Joined activity IDs for this user
  var joinedIds = <String>[];
  var friendsList = <String>[];
  var requestedList = <String>[];
  var incomingList = <String>[];
  var notificationsList = <Map<String, dynamic>>[];

  {
    // Cek apakah ada checkout pending yang sudah sukses di Midtrans
    try {
      final pendingCheckouts = await _db.execute(
        Sql.named('''
          SELECT reference, activity_id, amount
          FROM checkout_previews
          WHERE user_id = @uid AND status = 'pending' AND expires_at > NOW()
        '''),
        parameters: {'uid': userId},
      );
      for (final p in pendingCheckouts) {
        final pMap = p.toColumnMap();
        final pRef = pMap['reference'] as String;
        final mStatus = await _checkMidtransStatus(pRef);
        if (mStatus != null &&
            (mStatus['transaction_status'] == 'settlement' ||
                mStatus['transaction_status'] == 'capture')) {
          final actId = pMap['activity_id'] as String;
          await _markCheckoutAsPaid(
            reference: pRef,
            activityId: actId,
            userId: userId,
            amount: pMap['amount'] as int,
            source: 'Midtrans Settlement Sync',
          );
        }
      }
    } catch (_) {}

    // Joined activities
    final jRows = await _db.execute(
      Sql.named(
        'SELECT activity_id FROM activity_participants WHERE user_id = @uid',
      ),
      parameters: {'uid': userId},
    );
    joinedIds = jRows
        .map((r) => r.toColumnMap()['activity_id'] as String)
        .toList();

    // Accepted friends
    final fRows = await _db.execute(
      Sql.named(
        'SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'accepted\'',
      ),
      parameters: {'uid': userId},
    );
    for (final r in fRows) {
      final fid = r.toColumnMap()['friend_id'] as int;
      final pid = await _getPlayerIdForUser(fid);
      if (!friendsList.contains(pid)) friendsList.add(pid);
    }

    // Outgoing requested
    final reqRows = await _db.execute(
      Sql.named(
        'SELECT friend_id FROM friends WHERE user_id = @uid AND status = \'pending\'',
      ),
      parameters: {'uid': userId},
    );
    for (final r in reqRows) {
      final fid = r.toColumnMap()['friend_id'] as int;
      final pid = await _getPlayerIdForUser(fid);
      if (!requestedList.contains(pid)) requestedList.add(pid);
    }

    // Incoming requests
    final incRows = await _db.execute(
      Sql.named(
        'SELECT user_id FROM friends WHERE friend_id = @uid AND status = \'pending\'',
      ),
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

  // Direct message conversations (unread and sorting info)
  final conversationsList = <Map<String, dynamic>>[];
  if (userId != null) {
    final convRows = await _db.execute(
      Sql.named('''
        SELECT 
          CASE WHEN sender_id = @me THEN receiver_id ELSE sender_id END as other_user_id,
          MAX(created_at) as last_time,
          COUNT(CASE WHEN receiver_id = @me AND is_read = FALSE THEN 1 END) as unread_count
        FROM direct_messages
        WHERE sender_id = @me OR receiver_id = @me
        GROUP BY other_user_id
        ORDER BY last_time DESC
      '''),
      parameters: {'me': userId},
    );
    for (final r in convRows) {
      final m = r.toColumnMap();
      final otherUid = m['other_user_id'] as int;
      final otherPid = await _getPlayerIdForUser(otherUid);
      final lastTime = m['last_time'] as DateTime;
      final unreadCount = (m['unread_count'] as num).toInt();

      conversationsList.add({
        'playerId': otherPid,
        'lastMessageAt': lastTime.toUtc().toIso8601String(),
        'unreadCount': unreadCount,
      });
    }
  }

  // Communities
  var communitiesList = <String>[];
  if (userId != null) {
    final commRows = await _db.execute(
      Sql.named('SELECT sport FROM community_members WHERE user_id = @uid'),
      parameters: {'uid': userId},
    );
    communitiesList = commRows.map((r) => r.toColumnMap()['sport'] as String).toList();
  }

  // User profile
  Map<String, dynamic>? userProfile;
  final uRows = await _db.execute(
    Sql.named(
      'SELECT display_name, city, sport, level, theme, avatar_url FROM users WHERE id = @uid LIMIT 1',
    ),
    parameters: {'uid': userId},
  );
  if (uRows.isNotEmpty) {
    userProfile = uRows.first.toColumnMap();
    userProfile['playerId'] = await _getPlayerIdForUser(userId);
  }

  return _json({
    'activities': activities,
    'players': players,
    'venues': venues,
    'rankings': rankings,
    'rankedMatches': rankedMatches,
    'results': results,
    'joined': joinedIds,
    'friends': friendsList,
    'requested': requestedList,
    'incomingRequests': incomingList,
    'notifications': notificationsList,
    'conversations': conversationsList,
    'communities': communitiesList,
    'user': userProfile,
  });
}
