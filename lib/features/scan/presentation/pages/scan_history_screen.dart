import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_session_detail_screen.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';

class ScanHistoryScreen extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  const ScanHistoryScreen({
    super.key,
    this.baseUrl,
    this.httpClient,
  });

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<RecentScan>? _scans;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getBaseUrl() {
    if (widget.baseUrl != null && widget.baseUrl!.isNotEmpty) {
      return widget.baseUrl!;
    }
    const envBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    return kIsWeb ? 'http://localhost:8000' : 'https://rakoon-backend.onrender.com';
  }

  Future<void> _fetchScans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final scans = await ScanService.getRecentScans(
        limit: 50,
        baseUrl: _getBaseUrl(),
        client: widget.httpClient,
      );
      if (!mounted) return;
      setState(() {
        _scans = scans;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final localDt = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = localDt.day.toString().padLeft(2, '0');
    final month = months[localDt.month - 1];
    final year = localDt.year;
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  String _getDateGroup(DateTime dt) {
    final now = DateTime.now();
    final localDt = dt.toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(localDt.year, localDt.month, localDt.day);
    final diffDays = today.difference(itemDate).inDays;

    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    if (diffDays == 0) {
      return 'HARI INI - ${localDt.day} ${months[localDt.month - 1]}';
    } else if (diffDays == 1) {
      return 'KEMARIN - ${localDt.day} ${months[localDt.month - 1]}';
    } else if (diffDays <= 7) {
      return 'MINGGU INI';
    } else if (now.year == localDt.year && now.month == localDt.month) {
      return 'BULAN INI';
    } else {
      return '${months[localDt.month - 1].toUpperCase()} ${localDt.year}';
    }
  }

  List<RecentScan> _getFilteredScans() {
    if (_scans == null) return [];
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _scans!;

    final monthsIndo = [
      'januari', 'februari', 'maret', 'april', 'mei', 'juni',
      'juli', 'agustus', 'september', 'oktober', 'november', 'desember'
    ];

    return _scans!.where((scan) {
      final storeName = (scan.storeName ?? '').toLowerCase();
      final dt = scan.timestamp.toLocal();
      final dateFormatted = _formatDateTime(dt).toLowerCase();
      final monthName = monthsIndo[dt.month - 1];

      final matchesStore = storeName.contains(query);
      final matchesDate = dateFormatted.contains(query) ||
          monthName.contains(query) ||
          dt.year.toString().contains(query);

      return matchesStore || matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        title: Text(
          'Riwayat Scan',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D2818),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0D2818)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE8E4DC), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        key: const Key('scan_history_loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: Color(0xFF0D2818),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Memuat riwayat scan...',
              style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const Key('scan_history_error'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: const Color(0xFF0D2818), fontSize: 14),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('retry_scan_history_button'),
                onPressed: _fetchScans,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Coba Lagi', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFF059669)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_scans == null || _scans!.isEmpty) {
      return Center(
        key: const Key('scan_history_empty'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF059669),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Riwayat Scan',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: const Color(0xFF0D2818),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pindai label harga rak produk di toko untuk mulai mencatat dan melihat riwayat scan Anda di sini.',
                style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 13, height: 1.45),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filteredScans = _getFilteredScans();

    return RefreshIndicator(
      onRefresh: _fetchScans,
      color: const Color(0xFF0D2818),
      child: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {}),
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D2818),
                ),
                decoration: InputDecoration(
                  hintText: 'Cari riwayat scan (contoh: Indomaret, Superindo)...',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          Container(color: const Color(0xFFE8E4DC), height: 1.0),

          // Scan Cards List (Full Width, Grouped)
          Expanded(
            child: filteredScans.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada riwayat yang cocok',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const Key('scan_history_list'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: filteredScans.length,
                    itemBuilder: (context, index) {
                      final scan = filteredScans[index];
                      final currentGroup = _getDateGroup(scan.timestamp);
                      final prevGroup = index > 0 ? _getDateGroup(filteredScans[index - 1].timestamp) : null;
                      final showGroupHeader = prevGroup != currentGroup;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showGroupHeader) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 10.0),
                              child: Text(
                                currentGroup,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                          _buildScanCard(scan),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(RecentScan scan) {
    final String storeName = scan.storeName ?? 'Toko Terdekat';
    final String productCountText = '${scan.productCount} produk dipindai';
    final String formattedDate = _formatDateTime(scan.timestamp);
    final String? address = scan.storeAddress;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InteractiveScale(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanSessionDetailScreen(
                scanSessionId: scan.id,
                baseUrl: _getBaseUrl(),
                httpClient: widget.httpClient,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8E4DC), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Store Logo
              BrandAssets.buildStoreLogo(storeName, size: 44, borderRadius: 12),
              const SizedBox(width: 14),

              // Store Name & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: const Color(0xFF0D2818),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Timestamp row
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (address != null && address.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address.trim(),
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: const Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Product Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            size: 12,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            productCountText,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Chevron indicator
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
