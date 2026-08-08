import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';

class ScanCameraScreen extends StatefulWidget {
  final String baseUrl;

  const ScanCameraScreen({
    super.key,
    required this.baseUrl,
  });

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isScanning = false;
  String? _errorMessage;

  /// Opens the device camera to capture a photo
  Future<void> _takePhoto() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Balance file size and resolution
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
        // Automatically start the scanning process
        await _scanPhoto();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengakses kamera: $e';
      });
    }
  }

  /// Opens the gallery to select a photo
  Future<void> _pickFromGallery() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Balance file size and resolution
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
        // Automatically start the scanning process
        await _scanPhoto();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengakses galeri: $e';
      });
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

      if (mounted) {
        // Navigate to the result correction screen
        final bool? saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              baseUrl: widget.baseUrl,
              detectedItems: items,
            ),
          ),
        );

        if (saved == true && mounted) {
          // If successfully saved, return to the home dashboard page
          Navigator.pop(context);
          
          // Show a floating success snackbar on the home dashboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Berhasil memproses scan dan menyimpan hasil ke database!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Shelf Scan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Ambil foto rak produk supermarket. AI akan secara otomatis '
                  'mendeteksi nama, harga, dan ukuran produk untuk divalidasi.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Camera preview / image selected box
            _buildImageBox(),
            const SizedBox(height: 20),

            // Action Buttons for Camera or Gallery source
            if (_imageFile == null && !_isScanning)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galeri'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

            // Display loading indicator during AI analysis
            if (_isScanning) _buildScanningIndicator(),

            // Error display card
            if (_errorMessage != null) _buildErrorCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBox() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageFile != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                ),
                if (!_isScanning)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => setState(() => _imageFile = null),
                        tooltip: 'Hapus & Pilih Ulang',
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Belum ada foto', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
    );
  }

  Widget _buildScanningIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Menganalisis rak dengan AI...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Model Vision sedang memproses foto Anda. Mohon tunggu...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _scanPhoto,
                child: const Text('Coba Scan Ulang'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
