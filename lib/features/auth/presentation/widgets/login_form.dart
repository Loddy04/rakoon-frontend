import 'package:flutter/material.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginForm extends StatefulWidget {
  final VoidCallback? onSuccess;

  const LoginForm({super.key, this.onSuccess});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await AuthService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null && response.session == null) {
        setState(() {
          _errorMessage = 'Silakan verifikasi email terlebih dahulu.';
        });
      } else if (response.session != null) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('Invalid credentials')) {
        setState(() {
          _errorMessage = 'Email atau password salah.';
        });
      } else if (e.message.contains('Email not confirmed')) {
        setState(() {
          _errorMessage = 'Silakan verifikasi email terlebih dahulu.';
        });
      } else {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Koneksi bermasalah. Coba lagi.';
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Masuk Ke Akun Anda', style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.xl),

          // Error Banner
          if (_errorMessage != null) ...[
            Container(
              key: const Key('error_banner'),
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
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
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Login Button
          ElevatedButton(
            key: const Key('login_button'),
            onPressed: _isLoading ? null : _handleLogin,
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
                    'Masuk',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.paper,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
