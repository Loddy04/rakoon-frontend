import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/auth/presentation/widgets/social_icon_widgets.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String googleCancelledMessage = 'Login dibatalkan. Coba lagi bila ingin melanjutkan.';
const String googleFailedMessage = 'Gagal masuk dengan Google. Coba lagi.';

/// Login hanya lewat Google (provider email/password dimatikan di Supabase).
class LoginForm extends StatefulWidget {
  final VoidCallback? onSuccess;

  /// Hanya untuk test: pengganti AuthService.signInWithGoogle.
  final Future<AuthResponse> Function()? signInWithGoogle;

  const LoginForm({
    super.key,
    this.onSuccess,
    this.signInWithGoogle,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _isGoogleLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await (widget.signInWithGoogle ?? AuthService.signInWithGoogle)();
      if (response.session != null) widget.onSuccess?.call();
    } on AuthException catch (e) {
      final cancelled = e.message.toLowerCase().contains('batal') || e.message.toLowerCase().contains('cancel');
      if (mounted) setState(() => _errorMessage = cancelled ? googleCancelledMessage : googleFailedMessage);
    } on SocketException {
      if (mounted) setState(() => _errorMessage = noConnectionMessage);
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = noConnectionMessage);
    } on http.ClientException {
      if (mounted) setState(() => _errorMessage = noConnectionMessage);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = googleFailedMessage);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_errorMessage != null) ...[
          Container(
            key: const Key('error_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.outfit(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 46,
          child: OutlinedButton(
            key: const Key('google_login_button'),
            onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.authFieldBorder, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
              padding: EdgeInsets.zero,
            ),
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.authSageGreen),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GoogleLogoWidget(size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Masuk dengan Google',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
