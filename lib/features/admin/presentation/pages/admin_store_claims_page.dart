import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/ads_service.dart';

class AdminStoreClaimsPage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  const AdminStoreClaimsPage({
    super.key,
    this.baseUrl,
    this.httpClient,
  });

  @override
  State<AdminStoreClaimsPage> createState() => _AdminStoreClaimsPageState();
}

class _AdminStoreClaimsPageState extends State<AdminStoreClaimsPage> {
  // ponytail: client-side filter; add backend pagination and search when claims exceed 50/day
  List<PendingStoreClaimData> _claims = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _processingClaimId;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await AdsService.getPendingClaims(
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted) {
        setState(() {
          _claims = list;
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

  Future<void> _handleApprove(PendingStoreClaimData claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 24),
            const SizedBox(width: 8),
            Text(
              'Setujui Klaim Toko?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Toko "${claim.storeNama}" akan diverifikasi untuk merchant "${claim.userNama ?? claim.userEmail ?? claim.userId}".\n\nMerchant ini akan mendapatkan akses kelola toko dan pasang flyer iklan.',
          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            key: const Key('cancel_approve_button'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.outfit(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            key: const Key('confirm_approve_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Setujui', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingClaimId = claim.storeId);
    try {
      await AdsService.verifyStoreClaim(
        userId: claim.userId,
        storeId: claim.storeId,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Klaim toko "${claim.storeNama}" berhasil disetujui!'),
            backgroundColor: const Color(0xFF166534),
          ),
        );
        _loadClaims();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyetujui klaim: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingClaimId = null);
      }
    }
  }

  Future<void> _handleReject(PendingStoreClaimData claim) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 8),
            Text(
              'Tolak Klaim Toko?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menolak klaim toko "${claim.storeNama}" dari merchant "${claim.userNama ?? claim.userEmail ?? claim.userId}"?',
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reject_reason_input'),
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Alasan penolakan (opsional)',
                hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.outfit(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('cancel_reject_button'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.outfit(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            key: const Key('confirm_reject_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Tolak Klaim', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingClaimId = claim.storeId);
    try {
      await AdsService.rejectStoreClaim(
        userId: claim.userId,
        storeId: claim.storeId,
        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Klaim toko "${claim.storeNama}" telah ditolak.'),
            backgroundColor: const Color(0xFFB45309),
          ),
        );
        _loadClaims();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak klaim: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingClaimId = null);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verifikasi Klaim Toko',
              style: GoogleFonts.outfit(
                color: const Color(0xFF0D2818),
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Text(
              'Panel Administrator',
              style: GoogleFonts.outfit(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('refresh_claims_button'),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0D2818)),
            tooltip: 'Segarkan',
            onPressed: _isLoading ? null : _loadClaims,
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
                          onPressed: _loadClaims,
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
              : _claims.isEmpty
                  ? _buildEmptyState()
                  : _buildClaimsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 40,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Semua Klaim Sudah Diproses',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saat ini tidak ada permohonan klaim toko yang menunggu verifikasi admin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _claims.length,
      itemBuilder: (context, index) {
        final claim = _claims[index];
        final isProcessing = _processingClaimId == claim.storeId;

        return Card(
          key: Key('claim_card_${claim.storeId}'),
          margin: const EdgeInsets.only(bottom: 14.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Store Name & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Color(0xFF059669),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claim.storeNama,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (claim.storeAlamat != null && claim.storeAlamat!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                claim.storeAlamat!,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Menunggu Verifikasi',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 12),

                // Merchant Details Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              claim.userNama ?? 'Merchant (Nama belum disetel)',
                              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                            ),
                          ),
                        ],
                      ),
                      if (claim.userEmail != null && claim.userEmail!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                claim.userEmail!,
                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Diajukan: ${claim.createdAt}',
                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9CA3AF)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: Key('reject_claim_${claim.storeId}'),
                      onPressed: isProcessing ? null : () => _handleReject(claim),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Tolak'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      key: Key('approve_claim_${claim.storeId}'),
                      onPressed: isProcessing ? null : () => _handleApprove(claim),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(isProcessing ? 'Memproses...' : 'Setujui'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF166534),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
