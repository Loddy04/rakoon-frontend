import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart' show FilePickerFn;

class EditAdCampaignPage extends StatefulWidget {
  final HomePromoBanner campaign;
  final String storeName;
  final String? baseUrl;
  final http.Client? httpClient;
  final FilePickerFn? photoPicker;

  const EditAdCampaignPage({
    super.key,
    required this.campaign,
    required this.storeName,
    this.baseUrl,
    this.httpClient,
    this.photoPicker,
  });

  @override
  State<EditAdCampaignPage> createState() => _EditAdCampaignPageState();
}

class _EditAdCampaignPageState extends State<EditAdCampaignPage> {
  late TextEditingController _titleController;
  late String _currentBannerUrl;
  Uint8List? _newBannerBytes;
  String? _newBannerFilename;
  bool _isUploadingBanner = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isOpeningCheckout = false;

  int _selectedRenewalDurationDays = 7;

  bool get isExpired => widget.campaign.daysLeft <= 0 || widget.campaign.status == 'expired';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.campaign.title);
    _currentBannerUrl = widget.campaign.bannerUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _selectedRenewalPrice {
    switch (_selectedRenewalDurationDays) {
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

  Future<void> _pickNewBannerImage() async {
    if (isExpired) return;

    try {
      if (widget.photoPicker != null) {
        final picked = await widget.photoPicker!(allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
        if (picked != null) {
          setState(() {
            _newBannerBytes = picked.bytes;
            _newBannerFilename = picked.name;
          });
          await _uploadBanner();
        }
        return;
      }

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _newBannerBytes = bytes;
          _newBannerFilename = picked.name;
        });
        await _uploadBanner();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _uploadBanner() async {
    if (_newBannerBytes == null) return;
    setState(() => _isUploadingBanner = true);
    try {
      final url = await AdsService.uploadBannerImage(
        bytes: _newBannerBytes!,
        filename: _newBannerFilename ?? 'flyer_promo.jpg',
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted) {
        setState(() {
          _currentBannerUrl = url;
          _isUploadingBanner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto flyer baru berhasil diunggah!'),
            backgroundColor: Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingBanner = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah foto flyer: ${userMessage(e)}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleSaveChanges() async {
    if (isExpired) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul promo tidak boleh kosong.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AdsService.updateCampaign(
        campaignId: widget.campaign.id,
        title: title,
        bannerUrl: _currentBannerUrl,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Materi iklan berhasil diperbarui!'),
            backgroundColor: Color(0xFF166534),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui iklan: ${userMessage(e)}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isDeleting,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hapus Iklan Promo?',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus iklan promo ini dari peredaran? Penghapusan iklan tidak akan mengembalikan uang jika masa berlaku masih ada.',
            style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF4B5563), height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              key: const Key('btn_confirm_delete_ad'),
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Ya, Hapus Iklan',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await AdsService.deleteCampaign(
        campaignId: widget.campaign.id,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );

      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Iklan berhasil dihapus.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus iklan: ${userMessage(e)}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showRenewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isRenewing = false;
        String? renewError;

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Perbarui Langganan Iklan',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: isRenewing ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih paket masa tayang baru agar promo toko Anda kembali aktif dan tayang di Beranda Rakoon.',
                      style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 16),

                    // Opsi Durasi
                    _buildRenewalDurationOption(
                      days: 3,
                      name: 'Paket Kilat (3 Hari)',
                      price: 15000,
                      desc: 'Cocok untuk promo akhir pekan JSM',
                      setModalState: setModalState,
                    ),
                    const SizedBox(height: 10),
                    _buildRenewalDurationOption(
                      days: 7,
                      name: 'Paket Mingguan (7 Hari)',
                      price: 30000,
                      desc: 'Paling populer untuk flyer mingguan',
                      setModalState: setModalState,
                    ),
                    const SizedBox(height: 10),
                    _buildRenewalDurationOption(
                      days: 14,
                      name: 'Paket 2 Mingguan (14 Hari)',
                      price: 50000,
                      desc: 'Maksimum eksposur pembeli',
                      setModalState: setModalState,
                    ),

                    if (renewError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          renewError!,
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF991B1B)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isRenewing
                          ? null
                          : () async {
                              setModalState(() {
                                isRenewing = true;
                                renewError = null;
                              });

                              try {
                                final checkout = await AdsService.renewCampaign(
                                  campaignId: widget.campaign.id,
                                  durationDays: _selectedRenewalDurationDays,
                                  baseUrl: widget.baseUrl,
                                  client: widget.httpClient,
                                );

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  _showCheckoutDialog(checkout);
                                }
                              } catch (e) {
                                if (mounted) {
                                  setModalState(() {
                                    isRenewing = false;
                                    renewError = 'Gagal memperbarui langganan: ${userMessage(e)}';
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
                      child: isRenewing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Lanjut Pembayaran (${_formatRupiah(_selectedRenewalPrice)})',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
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

  Widget _buildRenewalDurationOption({
    required int days,
    required String name,
    required int price,
    required String desc,
    required StateSetter setModalState,
  }) {
    final isSelected = _selectedRenewalDurationDays == days;
    return InkWell(
      onTap: () {
        setModalState(() {
          _selectedRenewalDurationDays = days;
        });
        setState(() {
          _selectedRenewalDurationDays = days;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F8F4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF111827)),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Text(
              _formatRupiah(price),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF0D2818)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutDialog(PaymentCheckoutData checkout) {
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
          if (checkout.hasValidCheckoutUrl)
            ElevatedButton.icon(
              key: const Key('open_renewal_checkout_url_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isOpeningCheckout
                  ? null
                  : () async {
                      setState(() => _isOpeningCheckout = true);
                      try {
                        await AdsService.launchCheckoutUrl(checkout.invoiceUrl);
                      } finally {
                        if (mounted) setState(() => _isOpeningCheckout = false);
                      }
                    },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                _isOpeningCheckout ? 'Membuka...' : 'Buka Checkout',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          if (checkout.invoiceUrl != null && checkout.invoiceUrl!.trim().isNotEmpty)
            TextButton.icon(
              key: const Key('copy_renewal_checkout_url_button'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: checkout.invoiceUrl!.trim()));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Link checkout berhasil disalin!'),
                    backgroundColor: Color(0xFF166534),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Link'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
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
          isExpired ? 'Detail Iklan (Kedaluwarsa)' : 'Edit Iklan Promo',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D2818),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('btn_appbar_delete_ad'),
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            tooltip: 'Hapus Iklan',
            onPressed: (_isSaving || _isDeleting) ? null : _handleDeleteCampaign,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Notice jika Kedaluwarsa
            if (isExpired) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.timer_off_rounded, color: Color(0xFFDC2626), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Masa Tayang Iklan Telah Berakhir',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Iklan ini saat ini tidak tayang di beranda. Seluruh formulir dinonaktifkan (read-only). Silakan perbarui langganan iklan untuk mengubah materi dan menayangkannya kembali.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFFB91C1C),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Toko Pengiklan
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
                          style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280)),
                        ),
                        Text(
                          widget.storeName,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0D2818)),
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
              enabled: !isExpired,
              decoration: InputDecoration(
                filled: true,
                fillColor: isExpired ? const Color(0xFFF3F4F6) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                disabledBorder: OutlineInputBorder(
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
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: isExpired ? const Color(0xFF6B7280) : const Color(0xFF111827),
              ),
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
              isExpired
                  ? 'Foto flyer yang tayang pada periode sebelumnya (read-only):'
                  : 'Pratinjau foto flyer. Anda dapat mengganti foto baru dari galeri:',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),

            // Wadah Foto
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _newBannerBytes != null
                        ? Image.memory(_newBannerBytes!, fit: BoxFit.cover)
                        : Image.network(
                            _currentBannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Center(
                                child: Text('Gagal memuat gambar.'),
                              ),
                            ),
                          ),
                  ),
                ),
                if (_isUploadingBanner)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 10),
                            Text(
                              'Mengunggah foto baru...',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Tombol Ganti Foto (Hanya jika belum expired)
            if (!isExpired)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _isUploadingBanner ? null : _pickNewBannerImage,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Ganti Foto Flyer'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF166534),
                      textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 10),

            const SizedBox(height: 24),

            // Tombol Aksi Utama
            if (isExpired)
              ElevatedButton.icon(
                key: const Key('renew_ad_subscription_button'),
                onPressed: _showRenewModal,
                icon: const Icon(Icons.autorenew_rounded),
                label: const Text('Perbarui Langganan Iklan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2818),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              )
            else
              ElevatedButton(
                key: const Key('save_ad_changes_button'),
                onPressed: _isSaving ? null : _handleSaveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2818),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Simpan Perubahan',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),

            const SizedBox(height: 14),

            // Tombol Hapus Iklan Promo (dengan konfirmasi pop-up non-refundable)
            OutlinedButton.icon(
              key: const Key('btn_delete_ad_campaign'),
              onPressed: (_isSaving || _isDeleting) ? null : _handleDeleteCampaign,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                    )
                  : const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
              label: Text(
                _isDeleting ? 'Menghapus Iklan...' : 'Hapus Iklan Promo',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: const Color(0xFFFEF2F2),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
