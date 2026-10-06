import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_form.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/register_form.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class LoginBottomSheet extends StatefulWidget {
  final bool initialIsRegister;
  final VoidCallback? onSuccess;

  const LoginBottomSheet({
    super.key,
    this.initialIsRegister = false,
    this.onSuccess,
  });

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  late bool _isRegister;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialIsRegister;
  }

  void _handleSuccess() {
    if (!mounted) return;
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.authDarkBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top Header Section with Dark Background
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Navigation & Branding Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dismiss / Close Button
                        GestureDetector(
                          key: const Key('close_login_sheet_button'),
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        // Rakoon Identity Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.eco_rounded,
                                size: 14,
                                color: Color(0xFF86EFAC),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isRegister ? 'Daftar Rakoon' : 'Rakoon',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Eyebrow Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isRegister ? 'Buat Akun Baru' : 'Masuk Ke Akun Anda',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF86EFAC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Headline
                    Text(
                      'Go ahead and set up\nyour account',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),

              // White Bottom Card Container
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented Switcher (Login | Register)
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.authTabBg,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          // Login Tab
                          Expanded(
                            child: GestureDetector(
                              key: const Key('goto_login_tab'),
                              onTap: () {
                                if (_isRegister) {
                                  setState(() {
                                    _isRegister = false;
                                  });
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                decoration: !_isRegister
                                    ? BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      )
                                    : null,
                                alignment: Alignment.center,
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: !_isRegister
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: !_isRegister
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Register Tab
                          Expanded(
                            child: GestureDetector(
                              key: const Key('goto_register_tab'),
                              onTap: () {
                                if (!_isRegister) {
                                  setState(() {
                                    _isRegister = true;
                                  });
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                decoration: _isRegister
                                    ? BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      )
                                    : null,
                                alignment: Alignment.center,
                                child: Text(
                                  'Register',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: _isRegister
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _isRegister
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // In-Place Mode Switcher (Login or Register)
                    if (!_isRegister)
                      LoginForm(
                        showRegisterLink: true,
                        onSuccess: _handleSuccess,
                        onRegisterTap: () {
                          setState(() {
                            _isRegister = true;
                          });
                        },
                      )
                    else
                      RegisterForm(
                        showLoginLink: true,
                        onSuccess: _handleSuccess,
                        onLoginTap: () {
                          setState(() {
                            _isRegister = false;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience bottom sheet widget for opening directly in Register mode.
class RegisterBottomSheet extends StatelessWidget {
  final VoidCallback? onSuccess;

  const RegisterBottomSheet({super.key, this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return LoginBottomSheet(
      initialIsRegister: true,
      onSuccess: onSuccess,
    );
  }
}
