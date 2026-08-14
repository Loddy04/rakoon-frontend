import 'package:flutter/material.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/features/auth/presentation/pages/register_page.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rakoon Logo / Header
              const Icon(
                Icons.analytics_outlined,
                size: 80,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Rakoon',
                style: AppTextStyles.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Belanja Cerdas dengan AI Computer Vision',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Card container containing LoginForm
              Card(
                color: AppColors.paper,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: LoginForm(
                    onSuccess: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AppShell(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Register Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Belum punya akun? ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  GestureDetector(
                    key: const Key('goto_register_button'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Daftar Sekarang',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
