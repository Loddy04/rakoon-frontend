import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Sign In with Google OAuth (Native Google Sign-In via ID Token)
  static Future<AuthResponse> signInWithGoogle({
    String? webClientId,
    GoogleSignIn? googleSignInClient,
  }) async {
    if (_mockSession != null) {
      return AuthResponse(session: _mockSession, user: _mockSession?.user);
    }
    if (_client == null) {
      throw Exception('Supabase belum diinisialisasi.');
    }

    final effectiveClientId = webClientId ?? AppConfig.googleWebClientId;
    final googleSignIn = googleSignInClient ??
        GoogleSignIn(
          serverClientId: effectiveClientId.isNotEmpty ? effectiveClientId : null,
          scopes: const ['email', 'profile'],
        );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Login Google dibatalkan oleh pengguna.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException('Tidak dapat memperoleh ID Token dari Google.');
    }

    return await _client!.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Sign Out
  static Future<void> signOut() async {
    _mockSession = null;
    _mockIsAdmin = null;
    resetAdminCache();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Abaikan jika platform channel tidak tersedia / mock mode
    }
    await _client?.auth.signOut();
  }

  static Session? _mockSession;
  static bool? _mockIsAdmin;
  static bool? _cachedIsAdmin;
  static String? _cachedAdminUserId;

  /// Set a mock session for unit/widget testing purposes
  static set mockSession(Session? session) => _mockSession = session;

  /// Set mock admin status for unit/widget testing purposes
  static set mockIsAdmin(bool? isAdmin) => _mockIsAdmin = isAdmin;

  /// Reset internal admin cache (dipanggil saat sign-out; juga berguna untuk test)
  static void resetAdminCache() {
    _cachedIsAdmin = null;
    _cachedAdminUserId = null;
  }

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

  /// Apakah pengguna aktif admin. HANYA berasal dari hasil GET /auth/me (cache per user id);
  /// user_metadata/app_metadata sengaja tidak dipakai karena bisa diubah pengguna sendiri.
  static bool get isAdmin {
    if (_mockIsAdmin != null) return _mockIsAdmin!;
    final user = currentUser;
    if (user == null || _cachedAdminUserId != user.id) return false;
    return _cachedIsAdmin ?? false;
  }

  /// Validasi status admin dengan memanggil endpoint backend /auth/me.
  /// Gagal terhubung = hasil sebelumnya untuk user yang sama dipertahankan, tanpa fallback ke metadata.
  static Future<bool> checkAdminStatus({
    String? baseUrl,
    http.Client? client,
  }) async {
    if (_mockIsAdmin != null) return _mockIsAdmin!;

    final user = currentUser;
    final token = currentSession?.accessToken;
    if (user == null || token == null) {
      resetAdminCache();
      return false;
    }

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
        _cachedIsAdmin = data['role'] == 'admin';
      } else {
        _cachedIsAdmin = false;
      }
      _cachedAdminUserId = user.id;
    } catch (_) {
      // Backend tidak terjangkau: biarkan cache user ini apa adanya (default bukan admin).
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    return isAdmin;
  }

  /// Auth State Stream
  static Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();
}
