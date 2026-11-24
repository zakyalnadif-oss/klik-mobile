import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApiClient {
  AuthApiClient(this._baseUrl);

  final String _baseUrl;
  String? _token;

  String? get token => _token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Register a new user. Returns user data or throws.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
    String? city,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName ?? '',
        if (city != null && city.isNotEmpty) 'city': city,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      _token = data['token'] as String;
      return data['user'] as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? 'Pendaftaran gagal.');
  }

  /// Login with email and password. Returns user data or throws.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      _token = data['token'] as String;
      return data['user'] as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? 'Login gagal.');
  }

  /// Get current user info using stored token.
  Future<Map<String, dynamic>?> me() async {
    if (_token == null) return null;
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['user'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Fetch full sync data from PostgreSQL database via API.
  Future<Map<String, dynamic>?> fetchSync() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/sync'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Backend unavailable; fallback to offline cache/catalog
    }
    return null;
  }

  /// Create a new activity (Room or Event) in PostgreSQL database.
  Future<String?> createActivity(Map<String, dynamic> activityData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/activities'),
        headers: _headers,
        body: jsonEncode(activityData),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Send a friend request to another player.
  Future<void> sendFriendRequest(String targetPlayerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/friends/request'),
      headers: _headers,
      body: jsonEncode({'targetPlayerId': targetPlayerId}),
    );
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw StateError(data['error'] as String? ?? 'Gagal mengirim permintaan.');
      } catch (e) {
        if (e is StateError) rethrow;
        throw StateError('Gagal mengirim permintaan pertemanan.');
      }
    }
  }

  /// Cancel a pending friend request sent by current user.
  Future<void> cancelFriendRequest(String targetPlayerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/friends/cancel'),
      headers: _headers,
      body: jsonEncode({'targetPlayerId': targetPlayerId}),
    );
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw StateError(data['error'] as String? ?? 'Gagal membatalkan permintaan.');
      } catch (e) {
        if (e is StateError) rethrow;
        throw StateError('Gagal membatalkan permintaan.');
      }
    }
  }

  /// Accept an incoming friend request from another player.
  Future<void> acceptFriendRequest(String requesterPlayerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/friends/accept'),
      headers: _headers,
      body: jsonEncode({'requesterPlayerId': requesterPlayerId}),
    );
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw StateError(data['error'] as String? ?? 'Gagal menerima permintaan.');
      } catch (e) {
        if (e is StateError) rethrow;
        throw StateError('Gagal menerima permintaan pertemanan.');
      }
    }
  }

  /// Reject an incoming friend request from another player.
  Future<void> rejectFriendRequest(String requesterPlayerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/friends/reject'),
      headers: _headers,
      body: jsonEncode({'requesterPlayerId': requesterPlayerId}),
    );
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw StateError(data['error'] as String? ?? 'Gagal menolak permintaan.');
      } catch (e) {
        if (e is StateError) rethrow;
        throw StateError('Gagal menolak permintaan pertemanan.');
      }
    }
  }

  /// Remove an existing friend.
  Future<void> removeFriend(String friendPlayerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/friends/remove'),
      headers: _headers,
      body: jsonEncode({'friendPlayerId': friendPlayerId}),
    );
    if (response.statusCode != 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw StateError(data['error'] as String? ?? 'Gagal menghapus pertemanan.');
      } catch (e) {
        if (e is StateError) rethrow;
        throw StateError('Gagal menghapus pertemanan.');
      }
    }
  }

  /// Fetch notifications.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/notifications'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Mark notification as read.
  Future<void> markNotificationRead(int id) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/$id/read'),
        headers: _headers,
      );
    } catch (_) {}
  }

  /// Clear local token (logout).
  void logout() {
    _token = null;
  }
}
