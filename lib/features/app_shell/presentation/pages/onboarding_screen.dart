import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _cameraGranted = false;
  bool _locationGranted = false;
  bool _isRequestingLocation = false;
  bool _isRequestingCamera = false;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'AI Shelf Scanning',
      'subtitle': 'Bandingkan & Deteksi',
      'description':
          'Arahkan kamera Anda langsung ke rak supermarket. AI kami akan secara otomatis membandingkan harga serta volume produk agar belanja Anda lebih efisien.',
      'icon': Icons.camera_alt_outlined,
      'color': AppColors.accent,
    },
    {
      'title': 'Smart Budget Shopping',
      'subtitle': 'Alokasi Cerdas',
      'description':
          'Tentukan pagu belanja Anda. Aplikasi akan pintar membagi budget ke daftar barang belanjaan Anda berdasarkan toko dengan harga terendah.',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Color(0xFF0369A1), // Sky Blue Accent
    },
    {
      'title': 'Riwayat & Tren Harga',
      'subtitle': 'Transparansi Penuh',
      'description':
          'Pantau fluktuasi naik-turun harga barang dari waktu ke waktu secara akurat untuk menghindari membeli produk saat harga sedang melambung tinggi.',
      'icon': Icons.analytics_outlined,
      'color': Color(0xFF6B21A8), // Purple Accent
    },
    {
      'title': 'Izin Akses Perangkat',
      'subtitle': 'Akses Fitur Utama',
      'description':
          'Untuk menggunakan fitur AI Rakoon secara maksimal, kami memerlukan beberapa perizinan akses dasar untuk kamera dan lokasi GPS Anda.',
      'icon': Icons.security_outlined,
      'color': AppColors.warning,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isRequestingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() {
          _locationGranted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi berhasil diberikan!'),
            backgroundColor: AppColors.accent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi ditolak.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal meminta izin lokasi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingLocation = false;
        });
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    setState(() {
      _isRequestingCamera = true;
    });

    // Simulate requesting camera permission with a brief dialog explain and delay
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _cameraGranted = true;
      _isRequestingCamera = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin kamera berhasil disimulasikan & diberikan!'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.m,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicator count
                  Text(
                    '${_currentPage + 1}/${_onboardingData.length}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Skip button (only shown if not on the last page)
                  if (_currentPage < _onboardingData.length - 1)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          _onboardingData.length - 1,
                          duration: const Duration(milliseconds: 500),
                          curve: curvesEaseOut,
                        );
                      },
                      child: Text(
                        'Lewati',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Slide content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  final isPermissionsPage = index == _onboardingData.length - 1;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        // Premium Rounded Art Icon container
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: data['color'].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: data['color'].withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            data['icon'],
                            size: 68,
                            color: data['color'],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),

                        // Captions
                        Text(
                          data['subtitle'].toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: data['color'],
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Text(
                          data['title'],
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: 26,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.l),
                        Text(
                          data['description'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        // Interactive cards if permissions page
                        if (isPermissionsPage) ...[
                          _buildPermissionCard(
                            title: 'Izin Akses Kamera',
                            description:
                                'Diperlukan untuk memindai harga barang di rak via AI Vision.',
                            icon: Icons.camera_alt,
                            isGranted: _cameraGranted,
                            isLoading: _isRequestingCamera,
                            onPressed: _requestCameraPermission,
                          ),
                          const SizedBox(height: AppSpacing.l),
                          _buildPermissionCard(
                            title: 'Izin Akses Lokasi',
                            description:
                                'Diperlukan untuk mendeteksi ritel / toko di sekitar Anda.',
                            icon: Icons.location_on,
                            isGranted: _locationGranted,
                            isLoading: _isRequestingLocation,
                            onPressed: _requestLocationPermission,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicator row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.ink
                              : AppColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Bottom Button (Next or Start)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Complete onboarding
                          _completeOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _onboardingData.length - 1
                            ? 'Mulai Aplikasi'
                            : 'Lanjut',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Card(
      color: AppColors.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(
          color: isGranted
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.line,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            // Leading Icon
            CircleAvatar(
              backgroundColor: isGranted
                  ? AppColors.accentSoft
                  : AppColors.background,
              child: Icon(
                icon,
                color: isGranted ? AppColors.accent : AppColors.muted,
              ),
            ),
            const SizedBox(width: AppSpacing.l),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),

            // Grant Action Button / State
            if (isGranted)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 28)
            else
              TextButton(
                onPressed: isLoading ? null : onPressed,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                      )
                    : Text(
                        'Izinkan',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  // Animation curve definition
  static const Curve curvesEaseOut = Curves.easeOutCubic;
}
