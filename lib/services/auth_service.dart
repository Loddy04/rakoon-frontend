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
    _cachedIsAdmin = null;
    await _client?.auth.signOut();
  }

  static Session? _mockSession;
  static bool? _mockIsAdmin;
  static bool? _cachedIsAdmin;

  /// Set a mock session for unit/widget testing purposes
  static set mockSession(Session? session) => _mockSession = session;

  /// Set mock admin status for unit/widget testing purposes
  static set mockIsAdmin(bool? isAdmin) => _mockIsAdmin = isAdmin;

  /// Reset internal admin cache (useful for testing or session refresh)
  static void resetAdminCache() {
    _cachedIsAdmin = null;
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

  /// Cek apakah pengguna aktif memiliki peran Admin (berdasarkan metadata lokal atau cache verifikasi backend)
  static bool get isAdmin {
    if (_mockIsAdmin != null) return _mockIsAdmin!;
    if (_cachedIsAdmin != null) return _cachedIsAdmin!;
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

    final user = currentUser;
    if (user == null) {
      _cachedIsAdmin = false;
      return false;
    }

    // Cek metadata lokal terlebih dahulu
    final userMeta = user.userMetadata;
    if (userMeta != null && (userMeta['role'] == 'admin' || userMeta['is_admin'] == true)) {
      _cachedIsAdmin = true;
      return true;
    }

    final appMeta = user.appMetadata;
    if (appMeta['role'] == 'admin' || appMeta['is_admin'] == true) {
      _cachedIsAdmin = true;
      return true;
    }

    final token = currentSession?.accessToken;
    if (token == null) {
      _cachedIsAdmin = false;
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
        final role = data['role'] as String?;
        final isServerAdmin = role == 'admin';
        _cachedIsAdmin = isServerAdmin;
        return isServerAdmin;
      } else {
        _cachedIsAdmin = false;
      }
    } catch (_) {
      // Fallback ke metadata lokal
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    return _cachedIsAdmin ?? false;
  }

  /// Auth State Stream
  static Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();
}
