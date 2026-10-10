import 'package:flutter/services.dart';
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
        String? createdCampaignId;
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
                        paymentRef: paymentRef ?? 'INV-PENDING',
                        campaignId: createdCampaignId,
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
                                'Konfirmasi Kampanye Iklan',
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
                          _buildPaymentNoticeCard(),

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
                                      final created = await AdsService.createCampaign(
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
                                          createdCampaignId = created.id;
                                          paymentRef = created.paymentRef ?? created.id;
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setModalState(() {
                                          isProcessing = false;
                                          errorMessage = 'Gagal membuat kampanye iklan: $e';
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
                                        'Menerbitkan Invoice...',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Buat Kampanye & Terbitkan Invoice (${_formatRupiah(_selectedPrice)})',
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

  Widget _buildPaymentNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF166534)),
              const SizedBox(width: 8),
              Text(
                'Mekanisme Penayangan Iklan',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Setelah kampanye didaftarkan, sistem akan menerbitkan invoice dengan status Menunggu Pembayaran. Iklan promo flyer toko Anda akan otomatis aktif dan tayang di Beranda Rakoon segera setelah pembayaran diselesaikan dan diverifikasi oleh payment gateway resmi.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF374151),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, PaymentCheckoutData checkout) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF166534)),
            const SizedBox(width: 8),
            Text('Checkout Xendit', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tagihan: Rp ${checkout.amount}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              'Silakan selesaikan pembayaran Sandbox di browser dengan link berikut:',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4B5563)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                checkout.invoiceUrl ?? '-',
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1D4ED8)),
              ),
            ),
          ],
        ),
        actions: [
          if (checkout.invoiceUrl != null)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: checkout.invoiceUrl!));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Link checkout berhasil disalin ke clipboard!'),
                    backgroundColor: Color(0xFF166534),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Link'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSuccessView({
    required String paymentRef,
    String? campaignId,
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
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A), width: 2),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFB45309),
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Kampanye Iklan Dibuat',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              'Menunggu Pembayaran',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Invoice kampanye iklan berhasil diterbitkan. Iklan promo Anda akan otomatis aktif dan tayang di Beranda setelah pembayaran diverifikasi oleh sistem.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: const Color(0xFF4B5563),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        // Rincian Invoice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _buildReceiptRow('Nomor Invoice Kampanye', paymentRef),
              const Divider(height: 16),
              _buildReceiptRow('Status Pembayaran', 'Menunggu Pembayaran'),
              const Divider(height: 16),
              _buildReceiptRow('Toko Pengiklan', widget.storeName),
              const Divider(height: 16),
              _buildReceiptRow('Masa Tayang', '$_selectedDurationDays Hari Promo'),
              const Divider(height: 16),
              _buildReceiptRow('Total Tagihan', _formatRupiah(_selectedPrice), isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Integrasi pembayaran resmi (Xendit) sedang disiapkan. Anda dapat memantau status aktivasi iklan pada Dasbor Merchant.',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (campaignId != null && campaignId.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final checkout = await AdsService.initiatePayment(
                  campaignId: campaignId,
                  baseUrl: widget.baseUrl,
                  client: widget.httpClient,
                );
                if (mounted) {
                  _showCheckoutDialog(context, checkout);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memulai checkout: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF166534), size: 18),
            label: Text(
              'Buka Checkout Xendit Sandbox',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF166534),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF166534)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
            'Selesai & Lihat Dasbor Merchant',
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
