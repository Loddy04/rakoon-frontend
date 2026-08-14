import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class ScanCameraScreen extends StatefulWidget {
  final String baseUrl;
  final VoidCallback? onClose;
  final bool isActive;
  final CameraController? customCameraController;

  const ScanCameraScreen({
    super.key,
    required this.baseUrl,
    this.onClose,
    this.isActive = true,
    this.customCameraController,
  });

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isScanning = false;
  String? _errorMessage;

  // Camera settings
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;
  bool _isCameraInitializing = false;
  int _initToken = 0;

  // Scanline animation settings
  late AnimationController _scanlineController;
  late Animation<double> _scanlineAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _initializeCamera();
    }
    _initScanlineAnimation();
  }

  @override
  void didUpdateWidget(covariant ScanCameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _initializeCamera();
        if (!Platform.environment.containsKey('FLUTTER_TEST')) {
          _scanlineController.repeat(reverse: true);
        }
      } else {
        _deinitializeCamera();
        _scanlineController.stop();
      }
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _initToken++;
    _cameraController?.dispose();
    _cameraController = null;
    _scanlineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _deinitializeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted && !_isDisposed && widget.isActive) {
        _initializeCamera();
      }
    }
  }

  Future<void> _deinitializeCamera() async {
    _initToken++;
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
    if (mounted && !_isDisposed) {
      setState(() {
        _isCameraInitialized = false;
        _isCameraInitializing = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (!widget.isActive || _isCameraInitializing) return;

    final token = ++_initToken;

    setState(() {
      _isCameraInitializing = true;
      _isCameraPermissionDenied = false;
    });

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (widget.customCameraController != null) {
        final controller = widget.customCameraController!;
        try {
          if (!controller.value.isInitialized) {
            await controller.initialize();
          }
          if (!mounted || !widget.isActive || token != _initToken) {
            await controller.dispose();
            return;
          }
          _cameraController = controller;
          setState(() {
            _isCameraInitialized = true;
            _isCameraInitializing = false;
          });
          return;
        } catch (e) {
          if (mounted && token == _initToken) {
            setState(() {
              _isCameraInitializing = false;
              _isCameraInitialized = false;
            });
          }
          return;
        }
      }

      setState(() {
        _isCameraInitializing = false;
        _isCameraInitialized = false;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (!mounted || !widget.isActive || token != _initToken) return;

      if (_cameras.isEmpty) {
        setState(() {
          _isCameraInitializing = false;
          _isCameraInitialized = false;
        });
        return;
      }

      final controller = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted || !widget.isActive || token != _initToken) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;

      setState(() {
        _isCameraInitialized = true;
        _isCameraInitializing = false;
      });
    } catch (e) {
      if (mounted && token == _initToken) {
        setState(() {
          _isCameraInitializing = false;
          _isCameraInitialized = false;
          if (e is CameraException && e.code == 'CameraAccessDenied') {
            _isCameraPermissionDenied = true;
          }
        });
      }
    }
  }

  void _initScanlineAnimation() {
    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _scanlineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanlineController, curve: Curves.easeInOut),
    );
    if (widget.isActive && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _scanlineController.repeat(reverse: true);
    }
  }

  /// Takes picture using in-app camera viewfinder
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _imageFile = File(photo.path);
      });
      await _scanPhoto();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengambil gambar: $e';
        });
      }
    }
  }

  /// Opens the gallery to select a photo as fallback
  Future<void> _pickFromGallery() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
        await _scanPhoto();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengakses galeri: $e';
        });
      }
    }
  }

  /// Sends the photo file to the backend /scan/ endpoint
  Future<void> _scanPhoto() async {
    if (_imageFile == null) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final items = await ScanService.scanPhoto(
        _imageFile!,
        baseUrl: widget.baseUrl,
      );

      if (!mounted) return;

      final bool? saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ScanResultScreen(
            baseUrl: widget.baseUrl,
            detectedItems: items,
          ),
        ),
      );

      if (!mounted) return;

      if (saved == true) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else if (widget.onClose != null) {
          widget.onClose!();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil memproses scan dan menyimpan hasil ke database!'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double height = constraints.maxHeight;

            // Determine 3:4 Scan Frame dimensions and position
            final double rectWidth = width * 0.85;
            final double rectHeight = rectWidth * (4 / 3);
            final double rectLeft = (width - rectWidth) / 2;
            final double rectTop = (height - rectHeight) / 2 - 40;
            final Rect scanRect = Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight);

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Camera Preview or Fallback View
                if (_isCameraInitialized && _cameraController != null && _imageFile == null)
                  Center(
                    child: ClipRect(
                      child: AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio > 1.0
                            ? 1.0 / _cameraController!.value.aspectRatio
                            : _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else
                  _buildCameraFallbackView(),

                // 2. Dark Overlay & Corner decorations
                if (_isCameraInitialized && !_isScanning && _imageFile == null && !_isCameraPermissionDenied)
                  CustomPaint(
                    painter: ViewfinderPainter(scanRect: scanRect),
                  ),

                // 3. Animated Scanline
                if (_isCameraInitialized && !_isScanning && _imageFile == null && !_isCameraPermissionDenied)
                  AnimatedBuilder(
                    animation: _scanlineAnimation,
                    builder: (context, child) {
                      final double topOffset = rectTop + (_scanlineAnimation.value * rectHeight);
                      return Positioned(
                        left: rectLeft + 8,
                        right: rectLeft + 8,
                        top: topOffset,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // 4. Header (Close button & Title)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        key: const Key('scan_close_button'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: widget.onClose ?? () => Navigator.pop(context),
                      ),
                      Text(
                        'Pindai Rak',
                        style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                      ),
                      const SizedBox(width: 48), // Spacer to balance close button
                    ],
                  ),
                ),

                // 5. Instruction text
                if (_imageFile == null && !_isScanning && _isCameraInitialized && !_isCameraPermissionDenied)
                  Positioned(
                    top: rectTop + rectHeight + 20,
                    left: 24,
                    right: 24,
                    child: Text(
                      'Posisikan label harga di dalam bingkai',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 6. Bottom Control Area
                if (_imageFile == null && !_isScanning && _isCameraInitialized && !_isCameraPermissionDenied)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery Button
                        Semantics(
                          label: 'Pilih dari galeri',
                          child: InkWell(
                            key: const Key('gallery_fallback_button'),
                            onTap: _pickFromGallery,
                            child: const CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.photo_library, color: Colors.white),
                            ),
                          ),
                        ),
                        // Capture Button
                        Semantics(
                          label: 'Ambil foto rak',
                          child: InkWell(
                            key: const Key('capture_button'),
                            onTap: _captureImage,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.accent, width: 4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Spacer
                        const SizedBox(width: 52),
                      ],
                    ),
                  ),

                // 7. Processing / Error overlay
                if (_isScanning)
                  _buildScanningIndicatorOverlay(scanRect),

                if (_errorMessage != null)
                  _buildErrorOverlay(scanRect),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCameraFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_enhance_outlined, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              _isCameraPermissionDenied
                  ? 'Izin Kamera Ditolak'
                  : _isCameraInitializing
                      ? 'Memulai kamera...'
                      : 'Kamera Tidak Tersedia',
              style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _isCameraPermissionDenied
                  ? 'Aktifkan izin kamera di pengaturan perangkat untuk memindai.'
                  : _isCameraInitializing
                      ? 'Harap tunggu saat kami menghubungkan ke sensor kamera.'
                      : 'Perangkat ini tidak memiliki kamera aktif atau sedang berjalan di emulator.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: const Key('gallery_picker_fallback_btn'),
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Pilih dari Galeri'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
              ),
            ),
            if (_isCameraPermissionDenied) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _initializeCamera,
                child: const Text('Coba Minta Izin Lagi', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanningIndicatorOverlay(Rect scanRect) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_imageFile != null)
          Positioned.fill(
            child: Image.file(_imageFile!, fit: BoxFit.cover),
          ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            margin: const EdgeInsets.symmetric(horizontal: 32.0),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Menganalisis rak...',
                  style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI sedang mengenali produk dan harga.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorOverlay(Rect scanRect) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_imageFile != null)
          Positioned.fill(
            child: Image.file(_imageFile!, fit: BoxFit.cover),
          ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Analisis Gagal',
                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('retake_button'),
                        onPressed: () {
                          setState(() {
                            _imageFile = null;
                            _errorMessage = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.muted),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.l),
                          ),
                        ),
                        child: Text(
                          'Foto Baru',
                          style: TextStyle(color: AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('retry_scan_button'),
                        onPressed: _scanPhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.l),
                          ),
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ViewfinderPainter extends CustomPainter {
  final Rect scanRect;

  ViewfinderPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Darken overlay outside scanRect
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));
    final path = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(path, paint);

    // 2. Draw emerald framing corners
    final borderPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const double cornerLength = 24.0;
    const double radius = 16.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.top + cornerLength)
        ..lineTo(scanRect.left, scanRect.top + radius)
        ..quadraticBezierTo(scanRect.left, scanRect.top, scanRect.left + radius, scanRect.top)
        ..lineTo(scanRect.left + cornerLength, scanRect.top),
      borderPaint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLength, scanRect.top)
        ..lineTo(scanRect.right - radius, scanRect.top)
        ..quadraticBezierTo(scanRect.right, scanRect.top, scanRect.right, scanRect.top + radius)
        ..lineTo(scanRect.right, scanRect.top + cornerLength),
      borderPaint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.left, scanRect.bottom - cornerLength)
        ..lineTo(scanRect.left, scanRect.bottom - radius)
        ..quadraticBezierTo(scanRect.left, scanRect.bottom, scanRect.left + radius, scanRect.bottom)
        ..lineTo(scanRect.left + cornerLength, scanRect.bottom),
      borderPaint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
        ..lineTo(scanRect.right - radius, scanRect.bottom)
        ..quadraticBezierTo(scanRect.right, scanRect.bottom, scanRect.right, scanRect.bottom - radius)
        ..lineTo(scanRect.right, scanRect.bottom - cornerLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ViewfinderPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect;
  }
}
