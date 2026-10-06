import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/social_icon_widgets.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterForm extends StatefulWidget {
  final VoidCallback? onSuccess;
  final bool showLoginLink;
  final VoidCallback? onLoginTap;

  const RegisterForm({
    super.key,
    this.onSuccess,
    this.showLoginLink = true,
    this.onLoginTap,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSuccess() {
    if (!mounted) return;
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    }
  }

  Future<void> _handleGoogleRegister() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.signInWithGoogle();
      if (response.session != null) {
        _handleSuccess();
      }
    } on AuthException catch (e) {
      if (!e.message.toLowerCase().contains('batal') &&
          !e.message.toLowerCase().contains('cancel')) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mendaftar dengan Google: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
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

      final response =
          await AuthService.signUp(email: email, password: password);

      if (response.session != null) {
        _handleSuccess();
      } else if (response.user != null) {
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

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 52,
          color: AppColors.authSageGreen,
        ),
        const SizedBox(height: 14),
        Text(
          'Registrasi Berhasil!',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Registrasi berhasil. Silakan periksa kotak masuk email Anda untuk melakukan verifikasi sebelum masuk ke akun Rakoon.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF4B5563),
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _isSuccess = false;
              });
              if (widget.onLoginTap != null) {
                widget.onLoginTap!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.authSageGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              'Masuk Sekarang',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessView();
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
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

          // Email Field
          FormField<String>(
            initialValue: _emailController.text,
            validator: (_) {
              final val = _emailController.text;
              if (val.trim().isEmpty) {
                return 'Email tidak boleh kosong.';
              }
              final emailRegex =
                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(val.trim())) {
                return 'Format email tidak valid.';
              }
              return null;
            },
            builder: (FormFieldState<String> state) {
              final hasError = state.hasError;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasError
                            ? AppColors.error
                            : AppColors.authFieldBorder,
                        width: hasError ? 1.5 : 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          color: hasError
                              ? AppColors.error
                              : const Color(0xFF5B8268),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Email Address',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                              TextFormField(
                                key: const Key('email_field'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'micahmad@potarastudio.com',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  errorStyle: const TextStyle(
                                    height: 0,
                                    fontSize: 0,
                                  ),
                                ),
                                onChanged: (val) {
                                  state.didChange(val);
                                  if (state.hasError) {
                                    state.validate();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 3),
                      child: Text(
                        state.errorText ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Password Field
          FormField<String>(
            initialValue: _passwordController.text,
            validator: (_) {
              final val = _passwordController.text;
              if (val.isEmpty) {
                return 'Password tidak boleh kosong.';
              }
              if (val.length < 6) {
                return 'Password minimal 6 karakter.';
              }
              return null;
            },
            builder: (FormFieldState<String> state) {
              final hasError = state.hasError;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasError
                            ? AppColors.error
                            : AppColors.authFieldBorder,
                        width: hasError ? 1.5 : 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: hasError
                              ? AppColors.error
                              : const Color(0xFF5B8268),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Password',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                              TextFormField(
                                key: const Key('password_field'),
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  errorStyle: const TextStyle(
                                    height: 0,
                                    fontSize: 0,
                                  ),
                                ),
                                onChanged: (val) {
                                  state.didChange(val);
                                  if (state.hasError) {
                                    state.validate();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF9CA3AF),
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 3),
                      child: Text(
                        state.errorText ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Confirm Password Field
          FormField<String>(
            initialValue: _confirmPasswordController.text,
            validator: (_) {
              final val = _confirmPasswordController.text;
              if (val.isEmpty) {
                return 'Konfirmasi password tidak boleh kosong.';
              }
              if (val != _passwordController.text) {
                return 'Konfirmasi password tidak cocok.';
              }
              return null;
            },
            builder: (FormFieldState<String> state) {
              final hasError = state.hasError;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasError
                            ? AppColors.error
                            : AppColors.authFieldBorder,
                        width: hasError ? 1.5 : 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: hasError
                              ? AppColors.error
                              : const Color(0xFF5B8268),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Konfirmasi Password',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                ),
                              ),
                              TextFormField(
                                key: const Key('confirm_password_field'),
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  errorStyle: const TextStyle(
                                    height: 0,
                                    fontSize: 0,
                                  ),
                                ),
                                onChanged: (val) {
                                  state.didChange(val);
                                  if (state.hasError) {
                                    state.validate();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF9CA3AF),
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 3),
                      child: Text(
                        state.errorText ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Register Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('register_button'),
              onPressed: (_isLoading || _isGoogleLoading)
                  ? null
                  : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.authSageGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Register',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Divider 'Or register with'
          Row(
            children: [
              const Expanded(
                child: Divider(
                  color: Color(0xFFE5E7EB),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Or register with',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              const Expanded(
                child: Divider(
                  color: Color(0xFFE5E7EB),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Google Register Button (Full Width)
          SizedBox(
            height: 46,
            child: OutlinedButton(
              key: const Key('google_register_button'),
              onPressed: (_isLoading || _isGoogleLoading)
                  ? null
                  : _handleGoogleRegister,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(
                  color: AppColors.authFieldBorder,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.authSageGreen,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleLogoWidget(size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Daftar dengan Google',
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

          // Bottom Navigation Link (if enabled)
          if (widget.showLoginLink) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sudah punya akun? ',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                GestureDetector(
                  key: const Key('goto_login_button'),
                  onTap: widget.onLoginTap,
                  child: Text(
                    'Masuk',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5B8268),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
