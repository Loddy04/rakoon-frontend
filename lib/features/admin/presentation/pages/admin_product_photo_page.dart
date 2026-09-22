import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/admin_product_service.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/bouncy_button.dart';
import 'package:rakoon_frontend/widgets/playful_card.dart';

class AdminProductPhotoPage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;
  final ImagePicker? imagePicker;

  const AdminProductPhotoPage({
    super.key,
    this.baseUrl,
    this.httpClient,
    this.imagePicker,
  });

  @override
  State<AdminProductPhotoPage> createState() => _AdminProductPhotoPageState();
}

class _AdminProductPhotoPageState extends State<AdminProductPhotoPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    'Semua',
    'Makanan Pokok',
    'Makanan Instan',
    'Minuman',
    'Susu & Olahan',
    'Camilan',
    'Bumbu & Saus',
    'Perawatan Diri',
    'Produk Rumah Tangga',
    'Kesehatan',
    'Bayi',
    'Lainnya',
  ];

  String _selectedCategory = 'Semua';
  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String get _effectiveBaseUrl => widget.baseUrl ?? AppConfig.apiBaseUrl;

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await ProductsService.getProducts(
        baseUrl: _effectiveBaseUrl,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        category: _selectedCategory == 'Semua' ? null : _selectedCategory,
        limit: 100,
        client: widget.httpClient,
      );
      if (mounted) {
        setState(() {
          _products = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchProducts();
    });
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _fetchProducts();
  }

  String _resolveImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanBase = _effectiveBaseUrl.endsWith('/')
        ? _effectiveBaseUrl.substring(0, _effectiveBaseUrl.length - 1)
        : _effectiveBaseUrl;
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }

  void _openEditPhotoModal(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _EditPhotoSheet(
            product: product,
            baseUrl: _effectiveBaseUrl,
            httpClient: widget.httpClient,
            imagePicker: widget.imagePicker,
            onPhotoUpdated: (newPhotoUrl) {
              setState(() {
                final idx = _products.indexWhere((p) => p.id == product.id);
                if (idx != -1) {
                  _products[idx] = Product(
                    id: product.id,
                    nama: product.nama,
                    kategori: product.kategori,
                    ukuran: product.ukuran,
                    satuan: product.satuan,
                    fotoUrl: newPhotoUrl,
                  );
                }
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KELOLA FOTO PRODUK',
              style: AppTextStyles.subheading.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.graphite,
              ),
            ),
            Text(
              'Panel Administrator',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.paper,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.line, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: AppColors.paper,
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: TextField(
                    key: const Key('admin_product_search_input'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.fog),
                      prefixIcon: const Icon(Icons.search, color: AppColors.graphite),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _fetchProducts();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),

                // Category Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      return ChoiceChip(
                        label: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.paper : AppColors.graphite,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.graphite,
                        backgroundColor: AppColors.paper,
                        side: BorderSide(
                          color: isSelected ? AppColors.graphite : AppColors.line,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        onSelected: (_) => _onCategorySelected(category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),

          // Main Product List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Gagal memuat produk',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.l),
              ElevatedButton.icon(
                onPressed: _fetchProducts,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.graphite,
                  foregroundColor: AppColors.paper,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.fog, size: 32),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Tidak ada produk ditemukan',
                style: AppTextStyles.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Coba ubah kata kunci pencarian atau pilih kategori lain.',
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProducts,
      color: AppColors.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.m),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (context, index) {
          final product = _products[index];
          final resolvedImage = _resolveImageUrl(product.fotoUrl);

          return PlayfulCard(
            backgroundColor: AppColors.paper,
            border: Border.all(color: AppColors.line),
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                // Product Thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    child: resolvedImage.isNotEmpty
                        ? Image.network(
                            resolvedImage,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                          )
                        : _buildFallbackThumbnail(),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nama,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.graphite,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.kategori,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (product.ukuran != null && product.satuan != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${product.ukuran} ${product.satuan}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.fog),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),

                // Action Button
                BouncyButton(
                  key: Key('edit_photo_btn_${product.id}'),
                  onPressed: () => _openEditPhotoModal(product),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                          ? AppColors.paper
                          : AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color: product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                            ? AppColors.graphite
                            : AppColors.accent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                              ? Icons.edit_outlined
                              : Icons.add_a_photo_outlined,
                          size: 14,
                          color: product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                              ? AppColors.graphite
                              : AppColors.paper,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                              ? 'Ubah'
                              : 'Upload',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: product.fotoUrl != null && product.fotoUrl!.isNotEmpty
                                ? AppColors.graphite
                                : AppColors.paper,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackThumbnail() {
    return const Center(
      child: Icon(Icons.image_not_supported_outlined, color: AppColors.fog, size: 24),
    );
  }
}

class _EditPhotoSheet extends StatefulWidget {
  final Product product;
  final String baseUrl;
  final http.Client? httpClient;
  final ImagePicker? imagePicker;
  final ValueChanged<String> onPhotoUpdated;

  const _EditPhotoSheet({
    required this.product,
    required this.baseUrl,
    this.httpClient,
    this.imagePicker,
    required this.onPhotoUpdated,
  });

  @override
  State<_EditPhotoSheet> createState() => _EditPhotoSheetState();
}

class _EditPhotoSheetState extends State<_EditPhotoSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();

  XFile? _selectedFile;
  Uint8List? _fileBytes;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.product.fotoUrl != null &&
        (widget.product.fotoUrl!.startsWith('http://') ||
            widget.product.fotoUrl!.startsWith('https://'))) {
      _urlController.text = widget.product.fotoUrl!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedFile = picked;
          _fileBytes = bytes;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memilih gambar: $e';
      });
    }
  }

  Future<void> _savePhoto() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      String updatedUrl = '';
      if (_tabController.index == 0) {
        // Upload File Tab
        if (_selectedFile == null && _fileBytes == null) {
          throw Exception('Silakan pilih berkas foto terlebih dahulu.');
        }

        updatedUrl = await AdminProductService.uploadProductPhotoFile(
          productId: widget.product.id,
          filePath: _selectedFile?.path,
          fileBytes: _fileBytes,
          fileName: _selectedFile?.name,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      } else {
        // URL Tab
        final url = _urlController.text.trim();
        if (url.isEmpty) {
          throw Exception('URL gambar tidak boleh kosong.');
        }
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          throw Exception('URL gambar harus diawali dengan http:// atau https://');
        }

        updatedUrl = await AdminProductService.updateProductPhotoUrl(
          productId: widget.product.id,
          photoUrl: url,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      }

      widget.onPhotoUpdated(updatedUrl);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Foto produk "${widget.product.nama}" berhasil diperbarui!',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.paper),
            ),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),

          // Title & Product Info
          Text(
            'Ubah Foto Produk',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.product.nama,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.m),

          // Tabs: Upload vs Link URL
          TabBar(
            controller: _tabController,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.fog,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(icon: Icon(Icons.upload_file, size: 20), text: 'Upload Berkas'),
              Tab(icon: Icon(Icons.link, size: 20), text: 'Input URL'),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // Tab View Content
          SizedBox(
            height: 220,
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. File Upload Tab
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_fileBytes != null)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          child: Image.memory(
                            _fileBytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: AppColors.fog),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.fog,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('admin_pick_gallery_button'),
                          onPressed: _isSaving ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Galeri'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.graphite,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        OutlinedButton.icon(
                          key: const Key('admin_pick_camera_button'),
                          onPressed: _isSaving ? null : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('Kamera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.graphite,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2. URL Input Tab
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Masukkan Tautan URL Gambar Langsung:',
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TextField(
                      key: const Key('admin_photo_url_input'),
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/foto-produk.png',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.fog),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                          vertical: AppSpacing.s12,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      'Pastikan tautan dapat diakses secara publik dan berakhiran .jpg, .png, atau .webp.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.fog),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              _errorMessage!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.l),

          // Save Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const Key('admin_save_photo_button'),
              onPressed: _isSaving ? null : _savePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.paper,
                      ),
                    )
                  : Text(
                      'Simpan Foto Produk',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.paper,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
  }
}
