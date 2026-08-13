import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await AuthService.signUp(email: email, password: password);
      
      if (response.user != null) {
        setState(() {
          _isSuccess = true;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Registrasi gagal. Periksa data dan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
              // Rakoon Header
              const Icon(
                Icons.analytics_outlined,
                size: 80,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                'Daftar Rakoon',
                style: AppTextStyles.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Success View / Registration Form
              Card(
                color: AppColors.paper,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: _isSuccess
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 60,
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: AppSpacing.l),
                            Text(
                              'Registrasi Berhasil!',
                              style: AppTextStyles.titleSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.m),
                            Text(
                              'Akun kamu berhasil dibuat. Silakan klik tombol di bawah untuk masuk.',
                              style: AppTextStyles.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context); // Go back to login
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.paper,
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.l),
                                ),
                              ),
                              child: Text(
                                'Masuk Sekarang',
                                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.paper),
                              ),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Buat Akun Baru',
                                style: AppTextStyles.titleSmall,
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // Error Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.m),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorSoft,
                                    borderRadius: BorderRadius.circular(AppRadius.m),
                                    border: Border.all(color: AppColors.error),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                      const SizedBox(width: AppSpacing.s),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.l),
                              ],

                              // Email Field
                              TextFormField(
                                key: const Key('email_field'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: AppTextStyles.bodyMedium,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Email tidak boleh kosong.';
                                  }
                                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Format email tidak valid.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.l),

                              // Password Field
                              TextFormField(
                                key: const Key('password_field'),
                                controller: _passwordController,
                                obscureText: true,
                                style: AppTextStyles.bodyMedium,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password tidak boleh kosong.';
                                  }
                                  if (value.length < 6) {
                                    return 'Password minimal 6 karakter.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.l),

                              // Confirm Password Field
                              TextFormField(
                                key: const Key('confirm_password_field'),
                                controller: _confirmPasswordController,
                                obscureText: true,
                                style: AppTextStyles.bodyMedium,
                                decoration: const InputDecoration(
                                  labelText: 'Konfirmasi Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Konfirmasi password tidak boleh kosong.';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Konfirmasi password tidak cocok.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xxl),

                              // Register Button
                              ElevatedButton(
                                key: const Key('register_button'),
                                onPressed: _isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.paper,
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.l),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.paper,
                                        ),
                                      )
                                    : Text(
                                        'Daftar',
                                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.paper),
                                      ),
                              ),
                            ],
                          ),
                        ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.xxl),

              // Login Navigation
              if (!_isSuccess)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sudah punya akun? ',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                    ),
                    GestureDetector(
                      key: const Key('goto_login_button'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Masuk',
                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.accent),
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
