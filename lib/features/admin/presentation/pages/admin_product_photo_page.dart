import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/admin_product_service.dart';
import 'package:rakoon_frontend/services/products_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';

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
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KELOLA FOTO PRODUK',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: const Color(0xFF0D2818),
              ),
            ),
            Text(
              'Panel Administrator',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF00A86B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D2818)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E4DC), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: const Color(0xFFFAF7F2),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                // 1. Search Bar Modern Rounded with Soft Shadow
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    key: const Key('admin_product_search_input'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: const Color(0xFF0D2818),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF00A86B),
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF6B7280)),
                              onPressed: () {
                                _searchController.clear();
                                _fetchProducts();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Horizontal Pill Tabs for Category Filter
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      return InteractiveScale(
                        onTap: () => _onCategorySelected(category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF00A86B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00A86B)
                                  : const Color(0xFFE8E4DC),
                              width: 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00A86B).withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              category,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

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
        child: CircularProgressIndicator(color: Color(0xFF00A86B)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat produk',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D2818),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                InteractiveScale(
                  onTap: _fetchProducts,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Coba Lagi',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8E4DC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada produk ditemukan',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D2818),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Coba ubah kata kunci pencarian atau pilih kategori lain.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProducts,
      color: const Color(0xFF00A86B),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = _products[index];
          final resolvedImage = _resolveImageUrl(product.fotoUrl);

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Product Thumbnail or Dashed Placeholder
                _buildProductThumbnail(product, resolvedImage),
                const SizedBox(width: 12),

                // 2. Product Info (Expanded with maxLines: 1 and TextOverflow.ellipsis)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.nama,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D2818),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                              ),
                              child: Text(
                                product.kategori,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF059669),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (product.ukuran != null && product.satuan != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${product.ukuran! % 1 == 0 ? product.ukuran!.toInt() : product.ukuran} ${product.satuan}',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Standalone Rounded/Pill Upload Button (No double border)
                InteractiveScale(
                  key: Key('edit_photo_btn_${product.id}'),
                  onTap: () => _openEditPhotoModal(product),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A86B),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A86B).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Upload',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

  Widget _buildProductThumbnail(Product product, String resolvedImage) {
    if (resolvedImage.isNotEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            resolvedImage,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildDashedPlaceholder(),
          ),
        ),
      );
    }
    return _buildDashedPlaceholder();
  }

  Widget _buildDashedPlaceholder() {
    return CustomPaint(
      painter: const DashedRoundedBorderPainter(
        color: Color(0xFFCBD5E1),
        strokeWidth: 1.2,
        radius: 12.0,
        dashWidth: 4.0,
        dashSpace: 3.0,
      ),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              'Upload Foto',
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  const DashedRoundedBorderPainter({
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.0,
    this.radius = 12.0,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + len);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
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
                            errorBuilder: (_, _, _) => const Center(
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
                backgroundColor: AppColors.primaryEmerald,
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
