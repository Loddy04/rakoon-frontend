import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/google_sign_in_button.dart' show GoogleSignInNote, googleLoginErrorMessage;
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_product_photo_page.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_store_claims_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rakoon_frontend/features/profile/data/static_legal_content.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/document_viewer_page.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile / Account screen showing user identity, sync status, app metadata,
/// and authentication controls.
class ProfilePage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  /// Hanya untuk test: pengganti AuthService.signInWithGoogle.
  final Future<AuthResponse> Function()? signInWithGoogle;

  /// Hanya untuk test: penyedia PackageInfo agar test tidak memanggil platform channel.
  final Future<PackageInfo> Function()? getPackageInfo;

  const ProfilePage({
    super.key,
    this.baseUrl,
    this.httpClient,
    this.signInWithGoogle,
    this.getPackageInfo,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggingOut = false;
  bool _isSigningIn = false;
  bool _isCheckingAdmin = false;
  String _appVersion = '-';
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadAppVersion();
    _authSubscription = AuthService.authStateChanges.listen((_) {
      _checkAdminStatus();
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await (widget.getPackageInfo ?? PackageInfo.fromPlatform)();
      final formatted = info.buildNumber.trim().isNotEmpty
          ? '${info.version} (${info.buildNumber})'
          : info.version;
      if (mounted) {
        setState(() {
          _appVersion = formatted;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = '-';
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    if (AuthService.currentSession == null) return;
    if (_isCheckingAdmin) return;
    _isCheckingAdmin = true;

    try {
      final wasAdmin = AuthService.isAdmin;
      final isAdmin = await AuthService.checkAdminStatus(
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted && (wasAdmin != isAdmin || isAdmin)) {
        setState(() {});
      }
    } catch (_) {
      // Abaikan jika offline / koneksi backend belum terjangkau
    } finally {
      if (mounted) {
        _isCheckingAdmin = false;
      }
    }
  }

  /// Langsung membuka pemilih akun Google, tanpa popup.
  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      await (widget.signInWithGoogle ?? AuthService.signInWithGoogle)();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              googleLoginErrorMessage(e),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.paper),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal keluar akun. Silakan periksa koneksi internet Anda.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.paper),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Rakoon?',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('logout_cancel_button'),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          TextButton(
            key: const Key('logout_confirm_button'),
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 48),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _handleSignOut();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getDisplayName(Session session) {
    final metadata = session.user.userMetadata;
    if (metadata != null) {
      if (metadata['name'] is String && (metadata['name'] as String).trim().isNotEmpty) {
        return (metadata['name'] as String).trim();
      }
      if (metadata['full_name'] is String && (metadata['full_name'] as String).trim().isNotEmpty) {
        return (metadata['full_name'] as String).trim();
      }
      if (metadata['display_name'] is String && (metadata['display_name'] as String).trim().isNotEmpty) {
        return (metadata['display_name'] as String).trim();
      }
      if (metadata['username'] is String && (metadata['username'] as String).trim().isNotEmpty) {
        return (metadata['username'] as String).trim();
      }
    }

    final email = session.user.email;
    if (email != null && email.contains('@')) {
      final localPart = email.split('@')[0].trim();
      if (localPart.isNotEmpty) {
        return localPart;
      }
    }

    return 'Pengguna Rakoon';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'R';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: const Text(
                'Profil Saya',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Scrollable Content
            Expanded(
              child: StreamBuilder<AuthState>(
                stream: AuthService.authStateChanges,
                builder: (context, snapshot) {
                  final session = AuthService.currentSession;
                  if (session != null) {
                    return _buildProfileInfo(context, session);
                  } else {
                    return _buildLoginInvitation(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginInvitation(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    color: Color(0xFF059669),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Masuk Akun',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masuk untuk menyinkronkan riwayat belanja dan menikmati semua fitur Rakoon secara maksimal.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Semantics(
                    button: true,
                    label: 'Masuk dengan Google',
                    child: ElevatedButton(
                      key: const Key('signin_invitation_button'),
                      onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF059669).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Masuk dengan Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const GoogleSignInNote(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildAppInfoCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context, Session session) {
    if (!AuthService.isAdmin && !_isCheckingAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !AuthService.isAdmin && !_isCheckingAdmin) {
          _checkAdminStatus();
        }
      });
    }

    final email = (session.user.email != null && session.user.email!.trim().isNotEmpty)
        ? session.user.email!.trim()
        : 'Email belum terdaftar';
    final displayName = _getDisplayName(session);
    final initials = _getInitials(displayName);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar with user initials
                Semantics(
                  label: 'Avatar $displayName',
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                // Status Badges (Admin + Verified)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (AuthService.isAdmin)
                      Container(
                        key: const Key('profile_admin_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Admin Rakoon',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (AuthService.isAdmin) ...[
            _buildSectionHeader('Admin'),
            Semantics(
              button: true,
              label: 'Kelola Foto Produk',
              child: InkWell(
                key: const Key('admin_panel_tile'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminProductPhotoPage(
                        baseUrl: widget.baseUrl,
                        httpClient: widget.httpClient,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Color(0xFF2563EB),
                          size: 24,
                          semanticLabel: 'Kelola Foto Produk',
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kelola Foto Produk',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Upload atau masukkan tautan foto produk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                        semanticLabel: 'Buka Kelola Foto Produk',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Verifikasi Klaim Toko',
              child: InkWell(
                key: const Key('admin_claim_approval_tile'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminStoreClaimsPage(
                        baseUrl: widget.baseUrl,
                        httpClient: widget.httpClient,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF059669),
                          size: 24,
                          semanticLabel: 'Verifikasi Klaim Toko',
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verifikasi Klaim Toko',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tinjau, setujui, atau tolak klaim toko merchant',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                        semanticLabel: 'Buka Verifikasi Klaim Toko',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          _buildSectionHeader('Toko'),
          Semantics(
            button: true,
            label: 'Mode Mitra Toko',
            child: InkWell(
              key: const Key('merchant_hub_tile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MerchantDashboardPage(
                      baseUrl: widget.baseUrl,
                      httpClient: widget.httpClient,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF059669),
                        size: 24,
                        semanticLabel: 'Mode Mitra Toko',
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Mitra Toko',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Pasang flyer promo offline & kelola etalase toko',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                      semanticLabel: 'Buka Mode Mitra Toko',
                    ),
                  ],
                ),
              ),
            ),
          ),

          _buildSectionHeader('Akun'),
          Semantics(
            button: true,
            label: 'Riwayat Scan',
            child: InkWell(
              key: const Key('scan_history_tile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScanHistoryScreen(
                      baseUrl: widget.baseUrl,
                      httpClient: widget.httpClient,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Color(0xFF059669),
                        size: 24,
                        semanticLabel: 'Riwayat Scan',
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Riwayat Scan',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Daftar sesi pemindaian rak belanja',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                      semanticLabel: 'Buka Riwayat Scan',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Bantuan',
            child: InkWell(
              key: const Key('help_center_tile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentViewerPage(
                      content: helpContent,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFF059669),
                        size: 24,
                        semanticLabel: 'Bantuan',
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bantuan',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Panduan penggunaan, fitur, dan kontak',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                      semanticLabel: 'Buka Bantuan',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Kebijakan Privasi',
            child: InkWell(
              key: const Key('privacy_policy_tile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentViewerPage(
                      content: privacyPolicyContent,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.privacy_tip_outlined,
                        color: Color(0xFF059669),
                        size: 24,
                        semanticLabel: 'Kebijakan Privasi',
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kebijakan Privasi',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Kepatuhan privasi dan perlindungan data',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                      semanticLabel: 'Buka Kebijakan Privasi',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Syarat & Ketentuan',
            child: InkWell(
              key: const Key('terms_of_service_tile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DocumentViewerPage(
                      content: termsOfServiceContent,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF059669),
                        size: 24,
                        semanticLabel: 'Syarat & Ketentuan',
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Syarat & Ketentuan',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Ketentuan penggunaan layanan aplikasi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                      semanticLabel: 'Buka Syarat & Ketentuan',
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          _buildAppInfoCard(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Semantics(
              button: true,
              label: 'Keluar dari Akun',
              child: OutlinedButton.icon(
                key: const Key('profile_logout_button'),
                onPressed: _isLoggingOut ? null : _showLogoutConfirmationDialog,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEF4444),
                        ),
                      )
                    : const Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: Color(0xFFEF4444),
                        semanticLabel: 'Keluar dari Akun',
                      ),
                label: Text(
                  _isLoggingOut ? 'Sedang Keluar...' : 'Keluar dari Akun',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(
                    color: Color(0xFFFCA5A5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                  semanticLabel: 'Informasi Aplikasi',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Informasi Aplikasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Versi Aplikasi', _appVersion),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
