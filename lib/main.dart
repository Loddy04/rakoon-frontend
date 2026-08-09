import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';

void main() {
  runApp(const RakoonApp());
}

class RakoonApp extends StatelessWidget {
  const RakoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rakoon Integration Test',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light, // Menyesuaikan dengan visual referensi light theme
      home: const IntegrationDashboardPage(),
    );
  }
}

class IntegrationDashboardPage extends StatefulWidget {
  const IntegrationDashboardPage({super.key});

  @override
  State<IntegrationDashboardPage> createState() => _IntegrationDashboardPageState();
}

class _IntegrationDashboardPageState extends State<IntegrationDashboardPage> {
  // Input Controller untuk Base URL Backend FastAPI
  final TextEditingController _urlController = TextEditingController(text: 'http://10.0.2.2:8000');

  // Input Controllers untuk POST /price
  final TextEditingController _productIdPostController = TextEditingController(text: 'product-123');
  final TextEditingController _storeIdPostController = TextEditingController(text: 'store-456');
  final TextEditingController _hargaController = TextEditingController(text: '15000');
  final TextEditingController _userIdController = TextEditingController(text: 'user-001');

  // Input Controller untuk GET /price/product/{id}
  final TextEditingController _productIdGetController = TextEditingController(text: 'product-123');

  // State / status variabel
  bool _isLoadingConnection = false;
  bool _isLoadingPost = false;
  bool _isLoadingGet = false;
  String _connectionStatus = 'Belum diuji';
  Color _statusColor = Colors.grey;
  
  Map<String, dynamic>? _backendInfo;
  String _postResult = '';
  List<dynamic> _historyResult = [];
  String _historyMessage = '';

  @override
  void dispose() {
    _urlController.dispose();
    _productIdPostController.dispose();
    _storeIdPostController.dispose();
    _hargaController.dispose();
    _userIdController.dispose();
    _productIdGetController.dispose();
    super.dispose();
  }

  // Fungsi untuk menguji koneksi (GET /health)
  Future<void> _testConnection() async {
    setState(() {
      _isLoadingConnection = true;
      _connectionStatus = 'Menghubungkan...';
      _statusColor = Colors.blue;
      _backendInfo = null;
    });

    final String baseUrl = _urlController.text.trim();
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _connectionStatus = 'Terhubung!';
          _statusColor = Colors.green;
          _backendInfo = data;
        });
      } else {
        setState(() {
          _connectionStatus = 'Gagal (HTTP ${response.statusCode})';
          _statusColor = Colors.orange;
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error Koneksi: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoadingConnection = false;
      });
    }
  }

  // Fungsi untuk mengirim data (POST /price)
  Future<void> _sendPriceEntry() async {
    setState(() {
      _isLoadingPost = true;
      _postResult = 'Mengirim data...';
    });

    final String baseUrl = _urlController.text.trim();
    final String productId = _productIdPostController.text.trim();
    final String storeId = _storeIdPostController.text.trim();
    final int? harga = int.tryParse(_hargaController.text.trim());
    final String userId = _userIdController.text.trim();

    if (harga == null) {
      setState(() {
        _isLoadingPost = false;
        _postResult = 'Harga harus berupa angka!';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/price/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'product_id': productId,
          'store_id': storeId,
          'harga': harga,
          'sumber_user_id': userId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _postResult = 'Sukses Dikirim!\nResponse:\n${const JsonEncoder.withIndent('  ').convert(data)}';
        });
      } else {
        setState(() {
          _postResult = 'Gagal (HTTP ${response.statusCode}):\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _postResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoadingPost = false;
      });
    }
  }

  // Fungsi untuk mengambil riwayat harga (GET /price/product/{product_id})
  Future<void> _fetchPriceHistory() async {
    setState(() {
      _isLoadingGet = true;
      _historyResult = [];
      _historyMessage = 'Mengambil data...';
    });

    final String baseUrl = _urlController.text.trim();
    final String productId = _productIdGetController.text.trim();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/price/product/$productId'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('message')) {
          // Jika backend mengembalikan status pesan kosong / "Belum ada data historis"
          setState(() {
            _historyMessage = decoded['message'];
          });
        } else if (decoded is List) {
          setState(() {
            _historyResult = decoded;
            _historyMessage = _historyResult.isEmpty ? 'Data kosong' : 'Berhasil memuat ${_historyResult.length} riwayat';
          });
        } else {
          setState(() {
            _historyMessage = 'Format data tidak dikenali';
          });
        }
      } else {
        setState(() {
          _historyMessage = 'Gagal (HTTP ${response.statusCode}): ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _historyMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoadingGet = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rakoon Dev Integration', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tips emulator info
              Card(
                color: isDark ? const Color(0xFF0F3733) : Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Petunjuk IP Address Backend:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.teal.shade200 : Colors.teal.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('• Android Emulator: http://10.0.2.2:8000'),
                      const Text('• iOS Simulator/Web/Windows: http://localhost:8000'),
                      const Text('• HP Fisik: http://<IP_KOMPUTER_ANDA>:8000 (Hubungkan Wi-Fi sama)'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 1: KONEKSI SERVER
              _buildSectionCard(
                title: '🔌 Konfigurasi Koneksi Server',
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL Backend FastAPI',
                        border: OutlineInputBorder(),
                        hintText: 'http://10.0.2.2:8000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingConnection ? null : _testConnection,
                            icon: _isLoadingConnection
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync),
                            label: const Text('Cek Koneksi (GET /health)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.15),
                        border: Border.all(color: _statusColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: _statusColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Status: $_connectionStatus',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_backendInfo != null) ...[
                            const SizedBox(height: 8),
                            Text('App Name: ${_backendInfo!['app'] ?? '-'}'),
                            Text('Version: ${_backendInfo!['version'] ?? '-'}'),
                            Text('Status: ${_backendInfo!['status'] ?? '-'}'),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NearbyStoresScreen(
                        baseUrl: _urlController.text.trim(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.location_on, size: 24),
                label: const Text(
                  '📍 Uji Fitur Toko Terdekat (Nearby Stores)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.accentSoft,
                  foregroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 2: TEST POST /price
              _buildSectionCard(
                title: '➕ Tambah Data (POST /price/)',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productIdPostController,
                            decoration: const InputDecoration(labelText: 'Product ID', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _storeIdPostController,
                            decoration: const InputDecoration(labelText: 'Store ID', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hargaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Harga (Rupiah)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _userIdController,
                            decoration: const InputDecoration(labelText: 'Sumber User ID', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingPost ? null : _sendPriceEntry,
                            icon: _isLoadingPost
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                            label: const Text('Kirim Entri Harga'),
                          ),
                        ),
                      ],
                    ),
                    if (_postResult.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          _postResult,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 3: TEST GET /price/product/{product_id}
              _buildSectionCard(
                title: '🔍 Riwayat Harga (GET /price/product/{id})',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productIdGetController,
                            decoration: const InputDecoration(
                              labelText: 'Cari Product ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isLoadingGet ? null : _fetchPriceHistory,
                          icon: _isLoadingGet
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_historyMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _historyMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_historyResult.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _historyResult.length,
                        itemBuilder: (context, index) {
                          final item = _historyResult[index];
                          final harga = item['harga'] ?? 0;
                          final storeId = item['store_id'] ?? '-';
                          final timestamp = item['timestamp'] ?? '-';
                          final verified = item['status_verifikasi'] ?? '-';
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.sell, color: Colors.teal),
                              title: Text('Rp $harga'),
                              subtitle: Text('Toko: $storeId\nWaktu: $timestamp'),
                              trailing: Chip(
                                label: Text(verified, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                backgroundColor: verified == 'pending' ? Colors.amber.shade200 : Colors.green.shade200,
                              ),
                            ),
                          );
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

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1.2),
            child,
          ],
        ),
      ),
    );
  }
}
