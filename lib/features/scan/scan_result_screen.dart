import 'package:flutter/material.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';

class ScanResultScreen extends StatefulWidget {
  final String baseUrl;
  final List<ScanResultItem> detectedItems;
  final String defaultStoreId;
  final String defaultUserId;

  const ScanResultScreen({
    super.key,
    required this.baseUrl,
    required this.detectedItems,
    this.defaultStoreId =
        '21ba0855-bf71-4e6a-9718-b7ac79d8cfd2', // Valid UUID from database
    this.defaultUserId =
        'c61b0cfa-3512-4fb3-96b6-3974c05ef1c8', // Valid UUID from database
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _isSaving = false;
  String? _errorMessage;

  // Controllers for Store & User information
  late TextEditingController _storeIdController;
  late TextEditingController _userIdController;

  // Controllers for editing detected items
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _priceControllers = [];
  final List<TextEditingController> _sizeControllers = [];
  final List<TextEditingController> _unitControllers = [];

  // Selected categories for each detected item
  final List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _storeIdController = TextEditingController(text: widget.defaultStoreId);
    _userIdController = TextEditingController(text: widget.defaultUserId);

    // Initialize text controllers and category values for each detected item
    for (var item in widget.detectedItems) {
      _nameControllers.add(TextEditingController(text: item.namaProduk ?? ''));
      _priceControllers.add(
        TextEditingController(text: item.harga?.toInt().toString() ?? ''),
      );
      _sizeControllers.add(
        TextEditingController(text: item.ukuran?.toString() ?? ''),
      );
      _unitControllers.add(TextEditingController(text: item.satuan ?? ''));

      String itemCategory = item.kategori ?? 'Lainnya';
      if (!productCategories.contains(itemCategory)) {
        itemCategory = 'Lainnya';
      }
      _selectedCategories.add(itemCategory);
    }
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _userIdController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    for (var controller in _priceControllers) {
      controller.dispose();
    }
    for (var controller in _sizeControllers) {
      controller.dispose();
    }
    for (var controller in _unitControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Collects inputs and calls the confirm endpoint
  Future<void> _saveResults() async {
    // Progressive Auth check: show bottom sheet if session does not exist
    if (AuthService.currentSession == null) {
      final bool? loginSuccess = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const LoginBottomSheet(),
        ),
      );

      if (loginSuccess != true) {
        // User cancelled, return to screen as is
        return;
      }

      // Update the user ID text field controller with the newly logged-in user id
      if (AuthService.currentUser != null) {
        setState(() {
          _userIdController.text = AuthService.currentUser!.id;
        });
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final String storeId = _storeIdController.text.trim();
    final String userId = _userIdController.text.trim();

    if (storeId.isEmpty || userId.isEmpty) {
      setState(() {
        _errorMessage = 'Store ID dan User ID tidak boleh kosong!';
        _isSaving = false;
      });
      return;
    }

    // Build the list of confirmed items from controllers
    final List<ScanResultItem> confirmedItems = [];
    for (int i = 0; i < widget.detectedItems.length; i++) {
      final String name = _nameControllers[i].text.trim();
      final double? price = double.tryParse(_priceControllers[i].text.trim());
      final double? size = double.tryParse(_sizeControllers[i].text.trim());
      final String unit = _unitControllers[i].text.trim();

      if (name.isEmpty) {
        setState(() {
          _errorMessage = 'Nama produk Item #${i + 1} tidak boleh kosong!';
          _isSaving = false;
        });
        return;
      }

      if (price == null) {
        setState(() {
          _errorMessage = 'Harga Item #${i + 1} harus berupa angka valid!';
          _isSaving = false;
        });
        return;
      }

      confirmedItems.add(
        ScanResultItem(
          namaProduk: name,
          harga: price,
          ukuran: size,
          satuan: unit.isEmpty ? null : unit,
          kategori: _selectedCategories[i],
          confidence: widget.detectedItems[i].confidence,
          needsVerification: widget.detectedItems[i].needsVerification,
        ),
      );
    }

    try {
      final response = await ScanService.confirmScan(
        storeId: storeId,
        userId: userId,
        items: confirmedItems,
        baseUrl: widget.baseUrl,
      );

      final int saved = response['items_saved'] ?? 0;
      final int created = response['products_created'] ?? 0;
      final String msg = response['message'] ?? 'Berhasil disimpan!';

      if (mounted) {
        // Show success alert dialog, then pop back to home page
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Simpan Berhasil'),
            content: Text(
              '$msg\n\n'
              '• Entri Harga Baru: $saved\n'
              '• Produk Baru Dibuat: $created',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Pop back to camera screen with success result
                },
                child: const Text('Selesai'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Collects current form inputs and navigates to RecommendationScreen
  void _evaluateBestValue() {
    final List<RecommendationCandidate> candidates = [];
    for (int i = 0; i < widget.detectedItems.length; i++) {
      final String name = _nameControllers[i].text.trim();
      final double? price = double.tryParse(_priceControllers[i].text.trim());
      final double? size = double.tryParse(_sizeControllers[i].text.trim());
      final String unit = _unitControllers[i].text.trim();

      candidates.add(
        RecommendationCandidate(
          productId: 'item-${i + 1}',
          namaProduk: name.isEmpty ? null : name,
          harga: price,
          ukuran: size,
          satuan: unit.isEmpty ? null : unit,
          kategori: _selectedCategories[i],
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecommendationScreen(
          baseUrl: widget.baseUrl,
          initialCandidates: candidates,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koreksi Hasil Scan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              'Tinjau & Koreksi Hasil Deteksi AI:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Error Display Card
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // List of detected items to review and edit
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.detectedItems.length,
              itemBuilder: (context, index) {
                final item = widget.detectedItems[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: item.needsVerification
                          ? AppColors.warning
                          : AppColors.line,
                      width: item.needsVerification ? 1.8 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Item ID & verification warnings
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Produk #${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                if (item.needsVerification)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6.0),
                                    child: Text(
                                      '⚠️ Perlu Verifikasi',
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                StatusBadge(
                                  status: item.confidence == 'tinggi'
                                      ? 'Tinggi'
                                      : 'Rendah',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Nama Produk Input
                        TextField(
                          controller: _nameControllers[index],
                          decoration: const InputDecoration(
                            labelText: 'Nama Produk',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Kategori Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategories[index],
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: productCategories.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedCategories[index] = newValue;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),

                        // Harga Input
                        TextField(
                          controller: _priceControllers[index],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga (Rupiah)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Ukuran & Satuan Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _sizeControllers[index],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Ukuran',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _unitControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Satuan (ml/gr/kg/pcs)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Button to evaluate Best Value Recommendation directly from scan results
            ElevatedButton.icon(
              onPressed: _evaluateBestValue,
              icon: const Icon(Icons.emoji_events, size: 24),
              label: const Text('🏆 Hitung Best Value Recommendation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.accentSoft,
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '💾 Konfigurasi Penyimpanan Database:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Store UUID Input
            TextField(
              controller: _storeIdController,
              decoration: const InputDecoration(
                labelText: 'Store UUID (Database)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // User UUID Input
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User UUID (Database)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveResults,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Simpan Konfirmasi ke Database'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
