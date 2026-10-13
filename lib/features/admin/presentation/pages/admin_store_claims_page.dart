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
    final isNewStore = claim.claimType == 'new_store';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 24),
            const SizedBox(width: 8),
            Text(
              isNewStore ? 'Setujui Toko Baru?' : 'Setujui Klaim Toko?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isNewStore
              ? 'Toko baru "${claim.storeNama}" akan diaktifkan ke katalog publik Rakoon dan diverifikasi untuk pemohon "${claim.applicantName ?? claim.userNama ?? claim.userEmail ?? claim.userId}".'
              : 'Toko "${claim.storeNama}" akan diverifikasi untuk merchant "${claim.applicantName ?? claim.userNama ?? claim.userEmail ?? claim.userId}".\n\nMerchant ini akan mendapatkan akses kelola toko dan pasang flyer iklan.',
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

    final claimKey = claim.submissionId ?? claim.storeId;
    setState(() => _processingClaimId = claimKey);
    try {
      if (isNewStore) {
        await AdsService.verifyNewStore(
          submissionId: claim.submissionId ?? claim.storeId,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      } else {
        await AdsService.verifyStoreClaim(
          userId: claim.userId,
          storeId: claim.storeId,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNewStore
                  ? 'Pengajuan toko baru "${claim.storeNama}" berhasil disetujui & aktif di katalog!'
                  : 'Klaim toko "${claim.storeNama}" berhasil disetujui!',
            ),
            backgroundColor: const Color(0xFF166534),
          ),
        );
        _loadClaims();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyetujui: $e'),
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
    final isNewStore = claim.claimType == 'new_store';
    final reasonResult = await showDialog<String?>(
      context: context,
      builder: (ctx) => _RejectClaimDialog(claim: claim),
    );

    if (reasonResult == null || !mounted) return;

    final claimKey = claim.submissionId ?? claim.storeId;
    setState(() => _processingClaimId = claimKey);
    try {
      if (isNewStore) {
        await AdsService.rejectNewStore(
          submissionId: claim.submissionId ?? claim.storeId,
          reason: reasonResult.isNotEmpty ? reasonResult : null,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      } else {
        await AdsService.rejectStoreClaim(
          userId: claim.userId,
          storeId: claim.storeId,
          reason: reasonResult.isNotEmpty ? reasonResult : null,
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNewStore
                  ? 'Pengajuan toko baru "${claim.storeNama}" telah ditolak.'
                  : 'Klaim toko "${claim.storeNama}" telah ditolak.',
            ),
            backgroundColor: const Color(0xFFB45309),
          ),
        );
        _loadClaims();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak: $e'),
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
        final claimKey = claim.submissionId ?? claim.storeId;
        final isProcessing = _processingClaimId == claimKey;
        final isNewStore = claim.claimType == 'new_store';

        return Card(
          key: Key(claim.claimType == 'claim' && claim.storeId.isNotEmpty ? 'claim_card_${claim.storeId}' : 'claim_card_$claimKey'),
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
                // Top row: Type Badge & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isNewStore ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isNewStore ? const Color(0xFFC7D2FE) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isNewStore ? Icons.add_business_rounded : Icons.verified_user_outlined,
                            size: 13,
                            color: isNewStore ? const Color(0xFF4338CA) : const Color(0xFF047857),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isNewStore ? 'Pengajuan Toko Baru' : 'Klaim Toko Terdaftar',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isNewStore ? const Color(0xFF4338CA) : const Color(0xFF047857),
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
                const SizedBox(height: 12),

                // Store info row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isNewStore ? Icons.store_mall_directory_rounded : Icons.storefront_rounded,
                        color: isNewStore ? const Color(0xFF4F46E5) : const Color(0xFF059669),
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
                          if (claim.storeCategory != null && claim.storeCategory!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                'Kategori: ${claim.storeCategory}${claim.businessEntityName != null ? " • ${claim.businessEntityName}" : ""}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: const Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 12),

                // Pemohon & Dokumen Details Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${claim.applicantName ?? claim.userNama ?? "Pemohon"}${claim.applicantRole != null ? " (${claim.applicantRole})" : ""}',
                              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937)),
                            ),
                          ),
                        ],
                      ),
                      if (claim.applicantPhone != null && claim.applicantPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kontak: ${claim.applicantPhone}',
                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4B5563)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (claim.userEmail != null && claim.userEmail!.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                      const SizedBox(height: 4),
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
                      if (claim.documentUrl != null || claim.storePhotoUrl != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (claim.documentUrl != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.description_outlined, size: 13, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Dokumen Legalitas (NIB)',
                                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            if (claim.storePhotoUrl != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDF2F8),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFBCFE8)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_camera_outlined, size: 13, color: Color(0xFFBE185D)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Foto Depan Toko',
                                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFBE185D), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (claim.hasVerifiedOwner) ...[
                  Container(
                    key: Key('conflict_badge_${claim.storeId}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Toko ini sudah memiliki pemilik terverifikasi.',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: Key(claim.claimType == 'claim' && claim.storeId.isNotEmpty ? 'reject_claim_${claim.storeId}' : 'reject_claim_$claimKey'),
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
                      key: Key(claim.claimType == 'claim' && claim.storeId.isNotEmpty ? 'approve_claim_${claim.storeId}' : 'approve_claim_$claimKey'),
                      onPressed: (isProcessing || claim.hasVerifiedOwner) ? null : () => _handleApprove(claim),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        isProcessing
                            ? 'Memproses...'
                            : (claim.hasVerifiedOwner ? 'Sudah Dimiliki' : 'Setujui'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: claim.hasVerifiedOwner ? const Color(0xFF9CA3AF) : const Color(0xFF166534),
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

class _RejectClaimDialog extends StatefulWidget {
  final PendingStoreClaimData claim;

  const _RejectClaimDialog({required this.claim});

  @override
  State<_RejectClaimDialog> createState() => _RejectClaimDialogState();
}

class _RejectClaimDialogState extends State<_RejectClaimDialog> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNewStore = widget.claim.claimType == 'new_store';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
          const SizedBox(width: 8),
          Text(
            isNewStore ? 'Tolak Pengajuan Toko Baru?' : 'Tolak Klaim Toko?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isNewStore
                ? 'Apakah Anda yakin ingin menolak pengajuan toko baru "${widget.claim.storeNama}" dari pemohon "${widget.claim.applicantName ?? widget.claim.userNama ?? widget.claim.userEmail ?? widget.claim.userId}"?'
                : 'Apakah Anda yakin ingin menolak klaim toko "${widget.claim.storeNama}" dari merchant "${widget.claim.applicantName ?? widget.claim.userNama ?? widget.claim.userEmail ?? widget.claim.userId}"?',
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151)),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reject_reason_input'),
            controller: _reasonController,
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
          onPressed: () => Navigator.pop(context, null),
          child: Text('Batal', style: GoogleFonts.outfit(color: const Color(0xFF6B7280))),
        ),
        ElevatedButton(
          key: const Key('confirm_reject_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(context, _reasonController.text.trim()),
          child: Text('Tolak Klaim', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
