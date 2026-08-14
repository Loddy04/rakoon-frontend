import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile / Account screen showing user identity, sync status, app metadata,
/// and authentication controls.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggingOut = false;

  void _showLoginSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      backgroundColor: AppColors.paper,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const LoginBottomSheet(),
        );
      },
    );
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.l,
              ),
              child: Text(
                'Profil Saya',
                style: AppTextStyles.titleLarge,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    color: AppColors.muted,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                Text(
                  'Belum Masuk Akun',
                  style: AppTextStyles.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Masuk untuk menyinkronkan riwayat belanja dan menikmati semua fitur Rakoon secara maksimal.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Semantics(
                    button: true,
                    label: 'Masuk atau Buat Akun',
                    child: ElevatedButton(
                      key: const Key('signin_invitation_button'),
                      onPressed: () => _showLoginSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.paper,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                      ),
                      child: Text(
                        'Masuk',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          _buildAppInfoCard(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context, Session session) {
    final email = (session.user.email != null && session.user.email!.trim().isNotEmpty)
        ? session.user.email!.trim()
        : 'Email belum terdaftar';
    final displayName = _getDisplayName(session);
    final initials = _getInitials(displayName);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.03),
                  blurRadius: 10,
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Text(
                  displayName,
                  style: AppTextStyles.titleSmall,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.m),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.accent,
                        size: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'Akun Terverifikasi',
                          style: AppTextStyles.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.line, height: 1),
                const SizedBox(height: AppSpacing.xl),
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Semantics(
                    button: true,
                    label: 'Keluar dari Akun',
                    child: ElevatedButton.icon(
                      key: const Key('profile_logout_button'),
                      onPressed: _isLoggingOut ? null : _handleSignOut,
                      icon: _isLoggingOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.paper,
                              ),
                            )
                          : const Icon(Icons.logout, size: 20),
                      label: Text(
                        _isLoggingOut ? 'Sedang Keluar...' : 'Keluar dari Akun',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.paper,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor: AppColors.error.withValues(alpha: 0.6),
                        foregroundColor: AppColors.paper,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // Cloud Sync Info Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_outlined,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        'Status Sinkronisasi',
                        style: AppTextStyles.bodyLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Riwayat belanja dan perbandingan harga Anda disinkronkan secara aman ke cloud.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.l),
          _buildAppInfoCard(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.muted,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  'Informasi Aplikasi',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          _buildInfoRow('Versi Aplikasi', '1.0.0 (Release Candidate)'),
          const Divider(color: AppColors.line, height: AppSpacing.l),
          _buildInfoRow('Engine AI', 'Computer Vision & OCR'),
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
            style: AppTextStyles.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          flex: 6,
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
