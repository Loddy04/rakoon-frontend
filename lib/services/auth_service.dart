import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Sign Up with Email and Password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    if (_mockSession != null) {
      return AuthResponse(session: _mockSession, user: _mockSession?.user);
    }
    if (_client == null) {
      throw Exception('Supabase belum diinisialisasi.');
    }
    return await _client!.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign In with Email and Password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (_mockSession != null) {
      return AuthResponse(session: _mockSession, user: _mockSession?.user);
    }
    if (_client == null) {
      throw Exception('Supabase belum diinisialisasi.');
    }
    return await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign Out
  static Future<void> signOut() async {
    _mockSession = null;
    _mockIsAdmin = null;
    await _client?.auth.signOut();
  }

  static Session? _mockSession;
  static bool? _mockIsAdmin;

  /// Set a mock session for unit/widget testing purposes
  static set mockSession(Session? session) => _mockSession = session;

  /// Set mock admin status for unit/widget testing purposes
  static set mockIsAdmin(bool? isAdmin) => _mockIsAdmin = isAdmin;

  /// Current Session
  static Session? get currentSession {
    if (_mockSession != null) return _mockSession;
    return _client?.auth.currentSession;
  }

  /// Current User
  static User? get currentUser {
    if (_mockSession != null) return _mockSession?.user;
    return _client?.auth.currentUser;
  }

  /// Cek apakah pengguna aktif memiliki peran Admin (berdasarkan metadata lokal)
  static bool get isAdmin {
    if (_mockIsAdmin != null) return _mockIsAdmin!;
    final user = currentUser;
    if (user == null) return false;

    // 1. Cek user_metadata
    final userMeta = user.userMetadata;
    if (userMeta != null) {
      if (userMeta['role'] == 'admin' || userMeta['is_admin'] == true) {
        return true;
      }
    }

    // 2. Cek app_metadata
    final appMeta = user.appMetadata;
    if (appMeta['role'] == 'admin' || appMeta['is_admin'] == true) {
      return true;
    }

    return false;
  }

  /// Validasi status admin dengan memanggil endpoint backend /auth/me
  static Future<bool> checkAdminStatus({
    String? baseUrl,
    http.Client? client,
  }) async {
    if (_mockIsAdmin != null) return _mockIsAdmin!;
    if (isAdmin) return true;

    final token = currentSession?.accessToken;
    if (token == null) return false;

    final effectiveBaseUrl = baseUrl ?? AppConfig.apiBaseUrl;
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.get(
        Uri.parse('$effectiveBaseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final role = data['role'] as String?;
        return role == 'admin';
      }
    } catch (_) {
      // Fallback ke metadata lokal
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    return false;
  }

  /// Auth State Stream
  static Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();
}
