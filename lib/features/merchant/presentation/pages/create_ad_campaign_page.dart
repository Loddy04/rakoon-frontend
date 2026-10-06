import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/ads_service.dart';

class CreateAdCampaignPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String? baseUrl;
  final http.Client? httpClient;

  const CreateAdCampaignPage({
    super.key,
    required this.storeId,
    required this.storeName,
    this.baseUrl,
    this.httpClient,
  });

  @override
  State<CreateAdCampaignPage> createState() => _CreateAdCampaignPageState();
}

class _CreateAdCampaignPageState extends State<CreateAdCampaignPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  int _selectedDurationDays = 7;

  // Presets untuk kemudahan demo / juri tanpa perlu upload manual
  final List<Map<String, String>> _sampleBanners = [
    {
      "label": "Flyer Promo JSM Sembako",
      "url": "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=800&q=80",
    },
    {
      "label": "Flyer Diskon Susu & Makanan Segar",
      "url": "https://images.unsplash.com/photo-1578916171728-46686eac8d58?auto=format&fit=crop&w=800&q=80",
    },
    {
      "label": "Flyer Aneka Snack & Minuman Dingin",
      "url": "https://images.unsplash.com/photo-1588964895597-cfccd6e2dbf9?auto=format&fit=crop&w=800&q=80",
    },
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = 'Promo JSM Akhir Pekan ${widget.storeName}';
    _imageUrlController.text = _sampleBanners.first["url"]!;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  int get _selectedPrice {
    switch (_selectedDurationDays) {
      case 3:
        return 15000;
      case 7:
        return 30000;
      case 14:
        return 50000;
      default:
        return 30000;
    }
  }

  String _formatRupiah(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _showPaymentModal() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul promo tidak boleh kosong.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL foto flyer iklan tidak boleh kosong.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isProcessing = false;
        bool isSuccess = false;
        String? paymentRef;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: SingleChildScrollView(
                child: isSuccess
                    ? _buildPaymentSuccessView(
                        paymentRef: paymentRef ?? 'QRIS-2026-OK',
                        onFinish: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, true);
                        },
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pembayaran Iklan Promo',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rincian Tagihan:',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Paket Durasi $_selectedDurationDays Hari',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                    Text(
                                      _formatRupiah(_selectedPrice),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Biaya Layanan Platform',
                                      style: GoogleFonts.outfit(color: const Color(0xFF6B7280), fontSize: 12),
                                    ),
                                    Text(
                                      'Rp 0 (Gratis)',
                                      style: GoogleFonts.outfit(color: const Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Biaya:',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                    Text(
                                      _formatRupiah(_selectedPrice),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: const Color(0xFF0D2818),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Kartu QRIS Resmi
                          _buildOfficialQrisCard(),

                          if (errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF991B1B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    setModalState(() {
                                      isProcessing = true;
                                      errorMessage = null;
                                    });
                                    final genRef = 'QRIS-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                    try {
                                      await AdsService.createCampaign(
                                        storeId: widget.storeId,
                                        title: _titleController.text.trim(),
                                        bannerUrl: _imageUrlController.text.trim(),
                                        durationDays: _selectedDurationDays,
                                        paymentMethod: 'QRIS',
                                        paymentRef: genRef,
                                        baseUrl: widget.baseUrl,
                                        client: widget.httpClient,
                                      );
                                      if (mounted) {
                                        setModalState(() {
                                          isProcessing = false;
                                          isSuccess = true;
                                          paymentRef = genRef;
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setModalState(() {
                                          isProcessing = false;
                                          errorMessage = 'Pembayaran gagal diproses: $e';
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D2818),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: isProcessing
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Memproses Verifikasi QRIS...',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Selesaikan Pembayaran (${_formatRupiah(_selectedPrice)})',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOfficialQrisCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header merah QRIS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'QRIS',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STANDAR PEMBAYARAN NASIONAL',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                Text(
                  'ASPI / BI',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  widget.storeName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'NMID: ID102026RAKOON01  •  YOGYAKARTA',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),

                // QR Canvas
                Container(
                  width: 140,
                  height: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: CustomPaint(
                    painter: _QrisPatternPainter(),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF92400E)),
                      const SizedBox(width: 4),
                      Text(
                        'Selesaikan pembayaran dalam 15:00',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BCA • Mandiri • GoPay • OVO • ShopeePay • DANA',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSuccessView({
    required String paymentRef,
    required VoidCallback onFinish,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF86EFAC), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF166534),
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pembayaran Berhasil!',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Iklan brosur promo toko Anda telah aktif dan otomatis tayang di Beranda Rakoon selama $_selectedDurationDays hari.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF4B5563),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Bukti Transaksi
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _buildReceiptRow('Nomor Referensi', paymentRef),
              const Divider(height: 16),
              _buildReceiptRow('Metode', 'QRIS Dinamis (Verified)'),
              const Divider(height: 16),
              _buildReceiptRow('Toko Pengiklan', widget.storeName),
              const Divider(height: 16),
              _buildReceiptRow('Masa Tayang', '$_selectedDurationDays Hari Promo'),
              const Divider(height: 16),
              _buildReceiptRow('Total Dibayar', _formatRupiah(_selectedPrice), isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: onFinish,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D2818),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Selesai & Lihat Iklan',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            color: const Color(0xFF6B7280),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? const Color(0xFF0D2818) : const Color(0xFF111827),
          ),
        ),
      ],
    );
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
          'Pasang Iklan Promo',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D2818),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Store badge
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: Color(0xFF0D2818)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toko Pengiklan',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          widget.storeName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D2818),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form Judul
            Text(
              'Judul Flyer Promo',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Contoh: Promo JSM Minyak Goreng & Beras Hemat',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0D2818), width: 1.5),
                ),
              ),
              style: GoogleFonts.outfit(fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Foto Flyer Iklan
            Text(
              'Foto Flyer / Brosur Promo',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih template flyer ritel siap pakai atau masukkan URL foto flyer toko Anda:',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 10),

            // Preset flyer options
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sampleBanners.map((sample) {
                  final isSelected = _imageUrlController.text == sample["url"];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: ChoiceChip(
                      label: Text(
                        sample["label"]!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D2818),
                      backgroundColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _imageUrlController.text = sample["url"]!;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _imageUrlController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'https://... (URL Gambar Flyer)',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              style: GoogleFonts.outfit(fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Preview Flyer
            if (_imageUrlController.text.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _imageUrlController.text.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE5E7EB),
                      child: const Center(
                        child: Text('Gagal memuat pratinjau gambar.'),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Pilihan Durasi & Biaya
            Text(
              'Pilih Durasi Masa Tayang',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),

            _buildDurationOption(
              days: 3,
              name: 'Paket Kilat (3 Hari)',
              price: 15000,
              desc: 'Cocok untuk promo akhir pekan JSM',
            ),
            const SizedBox(height: 10),
            _buildDurationOption(
              days: 7,
              name: 'Paket Mingguan (7 Hari)',
              price: 30000,
              desc: 'Pilihan terpopuler untuk flyer mingguan',
            ),
            const SizedBox(height: 10),
            _buildDurationOption(
              days: 14,
              name: 'Paket 2 Mingguan (14 Hari)',
              price: 50000,
              desc: 'Maksimum eksposur ke pembeli Jogja',
            ),
            const SizedBox(height: 28),

            // Tombol Submit
            ElevatedButton(
              onPressed: _showPaymentModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2818),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Text(
                'Lanjut Pembayaran (${_formatRupiah(_selectedPrice)})',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption({
    required int days,
    required String name,
    required int price,
    required String desc,
  }) {
    final isSelected = _selectedDurationDays == days;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDurationDays = days;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F8F4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF166534) : const Color(0xFFE5E7EB),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF166534) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatRupiah(price),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: const Color(0xFF0D2818),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrisPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / 21.0;

    void drawFinder(double startX, double startY) {
      // 7x7 outer square
      canvas.drawRect(Rect.fromLTWH(startX, startY, 7 * cellSize, 7 * cellSize), paint);
      // 5x5 white inner
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(startX + cellSize, startY + cellSize, 5 * cellSize, 5 * cellSize), whitePaint);
      // 3x3 center square
      canvas.drawRect(Rect.fromLTWH(startX + 2 * cellSize, startY + 2 * cellSize, 3 * cellSize, 3 * cellSize), paint);
    }

    // Top-left finder
    drawFinder(0, 0);
    // Top-right finder
    drawFinder(14 * cellSize, 0);
    // Bottom-left finder
    drawFinder(0, 14 * cellSize);

    // Timing patterns & data cells
    const List<int> pattern = [
      0x5A, 0xA5, 0x3C, 0xC3, 0x66, 0x99, 0xF0, 0x0F,
      0xAA, 0x55, 0xCC, 0x33, 0x96, 0x69, 0x5A, 0xA5,
    ];

    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        // Skip finder areas
        if ((r < 8 && c < 8) || (r < 8 && c >= 13) || (r >= 13 && c < 8)) {
          continue;
        }
        // Timing pattern
        if (r == 6 || c == 6) {
          if ((r + c) % 2 == 0) {
            canvas.drawRect(Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize), paint);
          }
          continue;
        }
        // Data bits
        int val = pattern[(r * 3 + c) % pattern.length];
        if (((val >> (c % 8)) & 1) == 1) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize + 0.5, r * cellSize + 0.5, cellSize - 1, cellSize - 1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

