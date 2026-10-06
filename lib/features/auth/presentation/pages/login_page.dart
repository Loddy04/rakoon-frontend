import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/auth/presentation/pages/register_page.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_form.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _handleSuccess(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AppShell(),
        ),
      );
    }
  }

  Future<void> _navigateToRegister(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterPage(),
      ),
    );
    if (result == true && context.mounted) {
      _handleSuccess(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authDarkBg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Header Section with Dark Background
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Navigation & Branding Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_rounded,
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
                                        'Rakoon',
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
                                'Masuk Ke Akun Anda',
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
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // White Bottom Card Container
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 16,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                                    // Active Login Tab
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
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
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Login',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1F2937),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Inactive Register Tab
                                    Expanded(
                                      child: GestureDetector(
                                        key: const Key('goto_register_tab'),
                                        onTap: () =>
                                            _navigateToRegister(context),
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Register',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Form
                              LoginForm(
                                onSuccess: () => _handleSuccess(context),
                                showRegisterLink: true,
                                onRegisterTap: () =>
                                    _navigateToRegister(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
