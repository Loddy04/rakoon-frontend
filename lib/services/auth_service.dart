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
    await _client?.auth.signOut();
  }

  static Session? _mockSession;

  /// Set a mock session for unit/widget testing purposes
  static set mockSession(Session? session) => _mockSession = session;

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

  /// Auth State Stream
  static Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();
}
