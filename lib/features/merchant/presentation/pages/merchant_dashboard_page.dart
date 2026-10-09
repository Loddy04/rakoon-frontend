import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_product_photo_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/create_ad_campaign_page.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';

class MerchantDashboardPage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  const MerchantDashboardPage({
    super.key,
    this.baseUrl,
    this.httpClient,
  });

  @override
  State<MerchantDashboardPage> createState() => _MerchantDashboardPageState();
}

class _MerchantDashboardPageState extends State<MerchantDashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;
  MyStoreData? _myStoreData;
  List<StoreNearby> _availableStores = [];
  String? _selectedStoreId;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storeData = await AdsService.getMyStore(
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      List<StoreNearby> stores = [];
      if (!storeData.isClaimed && storeData.claimStatus != 'pending') {
        final resp = await StoresService.getNearbyStores(
          baseUrl: widget.baseUrl ?? AppConfig.apiBaseUrl,
          client: widget.httpClient,
          lat: -7.7829,
          lng: 110.4083,
          radiusKm: 25.0,
        );
        stores = resp.stores;
      }

      if (mounted) {
        setState(() {
          _myStoreData = storeData;
          _availableStores = stores;
          if (stores.isNotEmpty) {
            _selectedStoreId = stores.first.storeId;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data toko: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleClaimStore() async {
    if (_selectedStoreId == null || _isClaiming) return;

    setState(() {
      _isClaiming = true;
    });

    try {
      final result = await AdsService.claimStore(
        storeId: _selectedStoreId!,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      if (mounted) {
        setState(() {
          _myStoreData = result;
          _isClaiming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan klaim toko dikirim. Tunggu verifikasi admin sebelum memasang iklan.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengklaim toko: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0D2818)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mitra Toko Rakoon',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D2818),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D2818)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D2818),
                strokeWidth: 2.5,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: const Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D2818),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _myStoreData?.isClaimed == true
                  ? _buildClaimedDashboard()
                  : _myStoreData?.claimStatus == 'pending'
                      ? _buildPendingState()
                      : _buildUnclaimedState(),
    );
  }

  Widget _buildPendingState() {
    final store = _myStoreData!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pending_actions_rounded, size: 56, color: Color(0xFFB45309)),
            const SizedBox(height: 16),
            Text(
              'Klaim toko menunggu verifikasi',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Permintaan untuk ${store.storeNama ?? 'toko ini'} sudah dikirim. Admin akan memeriksa kepemilikan toko sebelum fitur iklan tersedia.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _loadData,
              child: const Text('Periksa Status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnclaimedState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner intro
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2818), Color(0xFF1E4830)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D2818).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '★ Kemitraan Ritel DIY Yogyakarta',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kelola Toko & Pasang Iklan Promo Offline',
                  style: GoogleFonts.dmSerifDisplay(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ajak pembeli di sekitar toko Anda untuk datang dan nikmati diskon langsung. Hubungkan akun Anda dengan toko di Yogyakarta.',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pilihan toko
          Text(
            'Pilih Toko Anda di Yogyakarta',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),

          if (_availableStores.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                'Tidak ada toko yang tersedia saat ini di database.',
                style: GoogleFonts.outfit(color: const Color(0xFF6B7280)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedStoreId,
                  items: _availableStores.map((store) {
                    return DropdownMenuItem<String>(
                      value: store.storeId,
                      child: Text(
                        '${store.nama} (${store.alamat ?? "Yogyakarta"})',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedStoreId = val;
                    });
                  },
                ),
              ),
            ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isClaiming ? null : _handleClaimStore,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D2818),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isClaiming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Klaim & Kelola Toko Ini',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedDashboard() {
    final store = _myStoreData!;
    final campaigns = store.campaigns;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Info Card
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: const Color(0xFFE8E4DC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            'Toko Terverifikasi',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Yogyakarta',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  store.storeNama ?? 'Toko Anda',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 22,
                    color: const Color(0xFF0D2818),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  store.storeAlamat ?? 'Alamat toko terdaftar di Yogyakarta',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 14),

                // Quick buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminProductPhotoPage(
                                baseUrl: widget.baseUrl,
                                httpClient: widget.httpClient,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: const Text('Kelola Foto Produk'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D2818),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Header Kampanye Iklan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Iklan Brosur Promo Anda',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 20,
                  color: const Color(0xFF0D2818),
                ),
              ),
              InteractiveScale(
                onTap: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateAdCampaignPage(
                        storeId: store.storeId!,
                        storeName: store.storeNama ?? 'Toko Saya',
                        baseUrl: widget.baseUrl,
                        httpClient: widget.httpClient,
                      ),
                    ),
                  );
                  if (created == true) {
                    _loadData();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2818),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Pasang Iklan',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (campaigns.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.campaign_outlined, size: 48, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 12),
                  Text(
                    'Belum Ada Iklan Promo yang Tayang',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pasang foto flyer promo toko Anda untuk menjangkau pengguna Rakoon di sekitar Jogja.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateAdCampaignPage(
                            storeId: store.storeId!,
                            storeName: store.storeNama ?? 'Toko Saya',
                            baseUrl: widget.baseUrl,
                            httpClient: widget.httpClient,
                          ),
                        ),
                      );
                      if (created == true) {
                        _loadData();
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Pasang Iklan Pertama'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2818),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: campaigns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final c = campaigns[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8E4DC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          c.bannerUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFE5E7EB),
                            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCampaignStatusBadge(c),
                                Text(
                                  'Paket ${c.durationDays} Hari',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.title,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Biaya: Rp ${c.pricePaid.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF166534),
                              ),
                            ),
                            if (c.status == 'pending_payment' || c.paymentStatus == 'unpaid') ...[
                              const SizedBox(height: 4),
                              Text(
                                'Belum tayang di beranda • Menunggu verifikasi pembayaran',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCampaignStatusBadge(HomePromoBanner c) {
    if (c.status == 'pending_payment' || c.paymentStatus == 'unpaid') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFB45309)),
            const SizedBox(width: 4),
            Text(
              'Menunggu Pembayaran',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    }

    if (c.daysLeft <= 0 || c.status == 'expired') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          'Kedaluwarsa',
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFDC2626),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        'Aktif • Sisa ${c.daysLeft} Hari',
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF059669),
        ),
      ),
    );
  }

}
