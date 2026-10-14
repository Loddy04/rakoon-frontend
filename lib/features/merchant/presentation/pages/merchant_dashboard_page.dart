import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_store_claims_page.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_product_photo_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/create_ad_campaign_page.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';

class PickedFileData {
  final String name;
  final int sizeInBytes;
  final Uint8List bytes;

  const PickedFileData({
    required this.name,
    required this.sizeInBytes,
    required this.bytes,
  });

  String get sizeFormatted {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

typedef FilePickerFn = Future<PickedFileData?> Function({required List<String> allowedExtensions});

class MerchantDashboardPage extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;
  final FilePickerFn? documentPicker;
  final FilePickerFn? photoPicker;

  const MerchantDashboardPage({
    super.key,
    this.baseUrl,
    this.httpClient,
    this.documentPicker,
    this.photoPicker,
  });

  @override
  State<MerchantDashboardPage> createState() => _MerchantDashboardPageState();
}

class _MerchantDashboardPageState extends State<MerchantDashboardPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  MyStoreData? _myStoreData;
  List<StoreNearby> _availableStores = [];
  String? _selectedStoreId;
  bool _isClaiming = false;
  bool _isOpeningCheckout = false;
  List<UserSubmissionData> _userSubmissions = [];

  final _claimApplicantNameCtrl = TextEditingController();
  final _claimApplicantPhoneCtrl = TextEditingController();
  final String _claimApplicantRole = 'Pemilik';
  final _claimDocUrlCtrl = TextEditingController();
  final _claimPhotoUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _claimApplicantNameCtrl.dispose();
    _claimApplicantPhoneCtrl.dispose();
    _claimDocUrlCtrl.dispose();
    _claimPhotoUrlCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(silent: true);
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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

      List<UserSubmissionData> subs = [];
      try {
        subs = await AdsService.getMySubmissions(
          baseUrl: widget.baseUrl,
          client: widget.httpClient,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _myStoreData = storeData;
          _availableStores = stores;
          _userSubmissions = subs;
          if (stores.isNotEmpty && _selectedStoreId == null) {
            _selectedStoreId = stores.first.storeId;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) {
            _errorMessage = 'Gagal memuat data toko: ${e.toString().replaceFirst("Exception: ", "")}';
          }
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
        applicantName: _claimApplicantNameCtrl.text.trim().isNotEmpty
            ? _claimApplicantNameCtrl.text.trim()
            : null,
        applicantPhone: _claimApplicantPhoneCtrl.text.trim().isNotEmpty
            ? _claimApplicantPhoneCtrl.text.trim()
            : null,
        applicantRole: _claimApplicantRole,
        documentUrl: _claimDocUrlCtrl.text.trim().isNotEmpty
            ? _claimDocUrlCtrl.text.trim()
            : null,
        storePhotoUrl: _claimPhotoUrlCtrl.text.trim().isNotEmpty
            ? _claimPhotoUrlCtrl.text.trim()
            : null,
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
        _loadData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClaiming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengklaim toko: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<PickedFileData?> _pickDocumentFile() async {
    if (widget.documentPicker != null) {
      return await widget.documentPicker!(allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        return PickedFileData(
          name: picked.name,
          sizeInBytes: bytes.lengthInBytes,
          bytes: bytes,
        );
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
    return null;
  }

  Future<PickedFileData?> _pickPhotoFile({ImageSource source = ImageSource.gallery}) async {
    if (widget.photoPicker != null) {
      return await widget.photoPicker!(allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        return PickedFileData(
          name: picked.name,
          sizeInBytes: bytes.lengthInBytes,
          bytes: bytes,
        );
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
    return null;
  }

  Future<void> _showNewStoreFormDialog() async {
    final nameCtrl = TextEditingController();
    final entityCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final appNameCtrl = TextEditingController();
    final appPhoneCtrl = TextEditingController();
    String appRole = 'Pemilik';

    PickedFileData? selectedDoc;
    String? uploadedDocUrl;
    PickedFileData? selectedPhoto;
    String? uploadedPhotoUrl;
    bool isSubmitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                      'Ajukan Toko Baru',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D2818),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Daftarkan toko fisik Anda yang belum tersedia di katalog Rakoon. Admin akan memverifikasi sebelum toko aktif di katalog publik.',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formError!,
                            style: GoogleFonts.outfit(color: const Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 1. Nama toko (wajib)
                TextField(
                  key: const Key('new_store_name_input'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Toko *',
                    hintText: 'Contoh: Toko Berkah Mandiri',
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Nama badan usaha (opsional)
                TextField(
                  key: const Key('new_store_entity_input'),
                  controller: entityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Badan Usaha (Opsional)',
                    hintText: 'Contoh: PT Berkah Sejahtera / CV Berkah',
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Alamat lengkap toko (wajib)
                TextField(
                  key: const Key('new_store_address_input'),
                  controller: addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Lengkap Toko *',
                    hintText: 'Jl. Malioboro No. 45, Yogyakarta',
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Data Pemohon & Bukti Legalitas',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // 4. Data pemohon: nama lengkap dan nomor kontak (wajib)
                TextField(
                  key: const Key('new_store_applicant_name_input'),
                  controller: appNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Pemohon *',
                    hintText: 'Nama sesuai KTP',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_store_applicant_phone_input'),
                  controller: appPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Kontak Pemohon *',
                    hintText: '0812xxxxxxxx',
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Peran pemohon (wajib)
                DropdownButtonFormField<String>(
                  key: const Key('new_store_applicant_role_dropdown'),
                  initialValue: appRole,
                  decoration: const InputDecoration(labelText: 'Peran Pemohon *'),
                  items: const [
                    DropdownMenuItem(value: 'Pemilik', child: Text('Pemilik')),
                    DropdownMenuItem(value: 'Pengurus Perusahaan', child: Text('Pengurus Perusahaan')),
                    DropdownMenuItem(value: 'Manajer Cabang', child: Text('Manajer Cabang')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => appRole = val);
                  },
                ),
                const SizedBox(height: 16),

                // 6. Unggah dokumen legalitas (wajib)
                Text(
                  'Dokumen Legalitas Usaha (NIB) *',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                if (selectedDoc == null && uploadedDocUrl == null)
                  OutlinedButton.icon(
                    key: const Key('btn_pick_claim_document'),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final file = await _pickDocumentFile();
                            if (file != null) {
                              if (file.sizeInBytes > 5 * 1024 * 1024) {
                                setModalState(() => formError = 'Ukuran dokumen legalitas melebihi batas 5 MB.');
                                return;
                              }
                              setModalState(() {
                                selectedDoc = file;
                                uploadedDocUrl = null;
                                formError = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.upload_file_rounded, color: Color(0xFF0D2818)),
                    label: Text(
                      'Unggah Dokumen Legalitas (PDF/JPG/PNG)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D2818),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  Container(
                    key: const Key('selected_document_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedDoc?.isPdf == true ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                          color: const Color(0xFF166534),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedDoc?.name ?? 'Dokumen Legalitas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                key: const Key('selected_doc_name'),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                selectedDoc?.sizeFormatted ?? 'Siap diunggah',
                                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          key: const Key('btn_change_claim_document'),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final file = await _pickDocumentFile();
                                  if (file != null) {
                                    if (file.sizeInBytes > 5 * 1024 * 1024) {
                                      setModalState(() => formError = 'Ukuran dokumen legalitas melebihi batas 5 MB.');
                                      return;
                                    }
                                    setModalState(() {
                                      selectedDoc = file;
                                      uploadedDocUrl = null;
                                      formError = null;
                                    });
                                  }
                                },
                          child: const Text('Ganti'),
                        ),
                        IconButton(
                          key: const Key('btn_remove_claim_document'),
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setModalState(() {
                                    selectedDoc = null;
                                    uploadedDocUrl = null;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 7. Unggah foto depan toko (wajib)
                Text(
                  'Foto Bagian Depan Toko *',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                if (selectedPhoto == null && uploadedPhotoUrl == null)
                  OutlinedButton.icon(
                    key: const Key('btn_pick_store_photo'),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final photo = await _pickPhotoFile();
                            if (photo != null) {
                              if (photo.sizeInBytes > 5 * 1024 * 1024) {
                                setModalState(() => formError = 'Ukuran foto toko melebihi batas 5 MB.');
                                return;
                              }
                              setModalState(() {
                                selectedPhoto = photo;
                                uploadedPhotoUrl = null;
                                formError = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF0D2818)),
                    label: Text(
                      'Unggah Foto Tampak Depan Toko',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D2818),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  Container(
                    key: const Key('selected_photo_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        if (selectedPhoto != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              selectedPhoto!.bytes,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(Icons.image_rounded, color: Color(0xFF059669), size: 24),
                              ),
                            ),
                          )
                        else
                          const Icon(Icons.image_rounded, color: Color(0xFF059669), size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedPhoto?.name ?? 'Foto Depan Toko',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                key: const Key('selected_photo_name'),
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                selectedPhoto?.sizeFormatted ?? 'Siap diunggah',
                                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          key: const Key('btn_change_store_photo'),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final photo = await _pickPhotoFile();
                                  if (photo != null) {
                                    if (photo.sizeInBytes > 5 * 1024 * 1024) {
                                      setModalState(() => formError = 'Ukuran foto toko melebihi batas 5 MB.');
                                      return;
                                    }
                                    setModalState(() {
                                      selectedPhoto = photo;
                                      uploadedPhotoUrl = null;
                                      formError = null;
                                    });
                                  }
                                },
                          child: const Text('Ganti'),
                        ),
                        IconButton(
                          key: const Key('btn_remove_store_photo'),
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setModalState(() {
                                    selectedPhoto = null;
                                    uploadedPhotoUrl = null;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                ElevatedButton(
                  key: const Key('btn_confirm_submit_new_store'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final address = addressCtrl.text.trim();
                          final appName = appNameCtrl.text.trim();
                          final phone = appPhoneCtrl.text.trim();
                          if (name.isEmpty ||
                              address.isEmpty ||
                              appName.isEmpty ||
                              phone.isEmpty ||
                              (selectedDoc == null && uploadedDocUrl == null) ||
                              (selectedPhoto == null && uploadedPhotoUrl == null)) {
                            setModalState(() {
                              formError = 'Harap lengkapi seluruh field wajib dan unggah dokumen serta foto toko.';
                            });
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            formError = null;
                          });

                          try {
                            // 1. Upload dokumen legalitas jika belum diunggah
                            if (uploadedDocUrl == null && selectedDoc != null) {
                              uploadedDocUrl = await AdsService.uploadClaimDocument(
                                bytes: selectedDoc!.bytes,
                                filename: selectedDoc!.name,
                                baseUrl: widget.baseUrl,
                                client: widget.httpClient,
                              );
                            }

                            // 2. Upload foto toko jika belum diunggah
                            if (uploadedPhotoUrl == null && selectedPhoto != null) {
                              uploadedPhotoUrl = await AdsService.uploadClaimPhoto(
                                bytes: selectedPhoto!.bytes,
                                filename: selectedPhoto!.name,
                                baseUrl: widget.baseUrl,
                                client: widget.httpClient,
                              );
                            }

                            // 3. Submit pengajuan toko baru ke backend
                            await AdsService.submitNewStore(
                              storeName: name,
                              businessEntityName: entityCtrl.text.trim().isNotEmpty ? entityCtrl.text.trim() : null,
                              storeAddress: address,
                              applicantName: appName,
                              applicantPhone: phone,
                              applicantRole: appRole,
                              documentUrl: uploadedDocUrl,
                              storePhotoUrl: uploadedPhotoUrl,
                              baseUrl: widget.baseUrl,
                              client: widget.httpClient,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pengajuan toko baru berhasil dikirim. Menunggu verifikasi admin.'),
                                  backgroundColor: Color(0xFF166534),
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              formError = e.toString().replaceFirst("Exception: ", "");
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal mengajukan toko: ${e.toString().replaceFirst("Exception: ", "")}'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2818),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Mengunggah & Mengirim...'),
                          ],
                        )
                      : Text(
                          'Kirim Pengajuan Toko Baru',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleOpenCheckout(BuildContext dialogCtx, String? url) async {
    if (_isOpeningCheckout) return;
    setState(() => _isOpeningCheckout = true);
    try {
      final success = await AdsService.launchCheckoutUrl(url);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak dapat membuka browser otomatis. Silakan gunakan tombol "Salin Link".',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFFB45309),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal membuka browser. Silakan gunakan tombol "Salin Link".',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningCheckout = false);
      }
    }
  }

  Future<void> _handlePayCampaign(HomePromoBanner c) async {
    try {
      final checkout = await AdsService.initiatePayment(
        campaignId: c.id,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF166534)),
                const SizedBox(width: 8),
                Text('Checkout Xendit Sandbox', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kampanye: ${c.title}', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Tagihan: Rp ${checkout.amount}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF166534))),
                const SizedBox(height: 10),
                Text(
                  'Silakan buka link berikut di browser untuk simulasi pembayaran Xendit:',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4B5563)),
                ),
                const SizedBox(height: 8),
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
                  key: const Key('open_checkout_url_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF166534),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isOpeningCheckout ? null : () => _handleOpenCheckout(ctx, checkout.invoiceUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    _isOpeningCheckout ? 'Membuka...' : 'Buka Checkout',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                ),
              if (checkout.invoiceUrl != null && checkout.invoiceUrl!.trim().isNotEmpty)
                TextButton.icon(
                  key: const Key('copy_checkout_url_button'),
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
                key: const Key('close_checkout_dialog_button'),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
        if (mounted) {
          _handleCheckPaymentStatus(c, showToastOnPending: false);
        }
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
  }

  Future<void> _handleCheckPaymentStatus(HomePromoBanner c, {bool showToastOnPending = true}) async {
    try {
      final statusData = await AdsService.getPaymentStatus(
        campaignId: c.id,
        baseUrl: widget.baseUrl,
        client: widget.httpClient,
      );
      if (mounted) {
        final isPaid = statusData.paymentStatus == 'paid' || statusData.transactionStatus == 'PAID';
        if (isPaid || showToastOnPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPaid
                    ? 'Pembayaran berhasil diverifikasi! Iklan telah aktif.'
                    : 'Status: Menunggu Pembayaran (${statusData.transactionStatus ?? "PENDING"})',
              ),
              backgroundColor: isPaid ? const Color(0xFF166534) : const Color(0xFFB45309),
            ),
          );
        }
        if (isPaid) {
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa status: ${e.toString().replaceFirst("Exception: ", "")}'),
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
          if (AuthService.isAdmin)
            IconButton(
              key: const Key('merchant_admin_claims_button'),
              icon: const Icon(Icons.verified_user_rounded, color: Color(0xFF166534)),
              tooltip: 'Verifikasi Klaim Toko',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminStoreClaimsPage(
                      baseUrl: widget.baseUrl,
                      httpClient: widget.httpClient,
                    ),
                  ),
                );
              },
            ),
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
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
          if (_userSubmissions.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSubmissionsHistorySection(),
          ],
        ],
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
          if (AuthService.isAdmin)
            Container(
              key: const Key('admin_unclaimed_claims_banner'),
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF166534), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panel Admin Rakoon',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13.5, color: const Color(0xFF166534)),
                        ),
                        Text(
                          'Tinjau permohonan klaim toko yang masuk dari para mitra merchant.',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF374151)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('admin_unclaimed_claims_button'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminStoreClaimsPage(
                            baseUrl: widget.baseUrl,
                            httpClient: widget.httpClient,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Tinjau Klaim'),
                  ),
                ],
              ),
            ),
          if (_myStoreData?.claimStatus == 'rejected')
            Container(
              key: const Key('rejected_claim_banner'),
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _myStoreData?.rejectionReason != null && _myStoreData!.rejectionReason!.trim().isNotEmpty
                              ? 'Klaim Ditolak: ${_myStoreData!.rejectionReason!.trim()}'
                              : 'Permohonan klaim toko Anda sebelumnya ditolak oleh admin.',
                          key: const Key('rejected_claim_reason_text'),
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: const Color(0xFF991B1B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Anda dapat mengajukan klaim toko kembali di bawah ini jika terdapat data yang diperbaiki.',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
          const SizedBox(height: 12),

          OutlinedButton.icon(
            key: const Key('btn_submit_new_store'),
            onPressed: _showNewStoreFormDialog,
            icon: const Icon(Icons.add_business_rounded, size: 18),
            label: Text(
              'Toko belum terdaftar? Ajukan toko baru',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D2818),
              side: const BorderSide(color: Color(0xFF0D2818)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          if (_userSubmissions.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSubmissionsHistorySection(),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmissionsHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Riwayat Pengajuan Anda',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_userSubmissions.length} pengajuan',
                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._userSubmissions.map((sub) {
          final isNew = sub.submissionType == 'new_store';
          final isVerified = sub.status == 'verified';
          final isRejected = sub.status == 'rejected';

          Color statusBg = const Color(0xFFFEF3C7);
          Color statusText = const Color(0xFFB45309);
          String statusLabel = 'Menunggu Pemeriksaan';
          if (isVerified) {
            statusBg = const Color(0xFFECFDF5);
            statusText = const Color(0xFF047857);
            statusLabel = 'Disetujui';
          } else if (isRejected) {
            statusBg = const Color(0xFFFEF2F2);
            statusText = const Color(0xFFDC2626);
            statusLabel = 'Ditolak';
          }

          return Container(
            key: Key('submission_item_${sub.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNew ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isNew ? 'Pengajuan Toko Baru' : 'Klaim Toko',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isNew ? const Color(0xFF4338CA) : const Color(0xFF047857),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  sub.storeName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                if (sub.storeAddress != null && sub.storeAddress!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub.storeAddress!,
                    style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF6B7280)),
                  ),
                ],
                if (isRejected && sub.rejectionReason != null && sub.rejectionReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: Key('submission_rejection_reason_${sub.id}'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alasan: ${sub.rejectionReason!.trim()}',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: const Color(0xFF991B1B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Tanggal: ${sub.createdAt}',
                  style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          );
        }),
      ],
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _handlePayCampaign(c),
                                    icon: const Icon(Icons.payment_rounded, size: 14),
                                    label: const Text('Bayar Xendit'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF166534),
                                      side: const BorderSide(color: Color(0xFF166534)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _handleCheckPaymentStatus(c),
                                    icon: const Icon(Icons.refresh_rounded, size: 14),
                                    label: const Text('Cek Status'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0D2818),
                                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Aktif • ',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF059669),
            ),
          ),
          Text(
            'Sisa ${c.daysLeft} Hari',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF059669),
            ),
          ),
        ],
      ),
   );
 }

}
