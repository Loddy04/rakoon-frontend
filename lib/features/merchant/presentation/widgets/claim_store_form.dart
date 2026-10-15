import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart' show PickedFileData;

const List<String> claimDocumentExtensions = ['pdf', 'jpg', 'jpeg'];
const List<String> claimPhotoExtensions = ['jpg', 'jpeg', 'png'];
const int claimMaxFileBytes = 5 * 1024 * 1024;

String? _validateClaimFile(PickedFileData file, List<String> allowed, String wrongFormatMessage) {
  final name = file.name.toLowerCase();
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1) : '';
  if (!allowed.contains(ext)) return wrongFormatMessage;
  if (file.sizeInBytes > claimMaxFileBytes) return 'Ukuran berkas terlalu besar (maksimum 5 MB).';
  return null;
}

/// Pesan kesalahan untuk foto toko (JPEG/PNG, maks 5 MB), atau null bila boleh diunggah.
String? validateClaimPhotoFile(PickedFileData file) =>
    _validateClaimFile(file, claimPhotoExtensions, 'Foto harus berformat JPEG atau PNG.');

/// Pesan kesalahan untuk dokumen legalitas (PDF/JPEG, maks 5 MB), atau null bila boleh diunggah.
String? validateClaimDocumentFile(PickedFileData file) =>
    _validateClaimFile(file, claimDocumentExtensions, 'Dokumen harus berformat PDF atau JPEG.');

class ClaimFormValues {
  final String applicantName;
  final String applicantPhone;
  final String documentPath;
  final String photoPath;

  const ClaimFormValues({
    required this.applicantName,
    required this.applicantPhone,
    required this.documentPath,
    required this.photoPath,
  });
}

/// Form klaim toko: nama, telepon, dokumen (PDF/JPEG), foto toko (JPEG/PNG).
/// Berkas diunggah segera setelah dipilih; tombol kirim aktif hanya bila semuanya lengkap.
class ClaimStoreForm extends StatefulWidget {
  final String storeName;
  final Future<PickedFileData?> Function() pickDocument;
  final Future<PickedFileData?> Function() pickPhoto;
  final Future<String> Function(PickedFileData file) uploadDocument;
  final Future<String> Function(PickedFileData file) uploadPhoto;

  /// Melempar Exception berpesan ramah bila gagal; form tetap terbuka dan menampilkan pesannya.
  final Future<void> Function(ClaimFormValues values) onSubmit;

  const ClaimStoreForm({
    super.key,
    required this.storeName,
    required this.pickDocument,
    required this.pickPhoto,
    required this.uploadDocument,
    required this.uploadPhoto,
    required this.onSubmit,
  });

  @override
  State<ClaimStoreForm> createState() => _ClaimStoreFormState();
}

class _ClaimStoreFormState extends State<ClaimStoreForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _documentPath;
  String? _documentName;
  String? _documentError;
  bool _uploadingDocument = false;

  String? _photoPath;
  String? _photoName;
  String? _photoError;
  bool _uploadingPhoto = false;

  String? _submitError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      !_uploadingDocument &&
      !_uploadingPhoto &&
      _nameCtrl.text.trim().length >= 2 &&
      _phoneCtrl.text.trim().length >= 8 &&
      _documentPath != null &&
      _photoPath != null;

  static String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _pickDocument() async {
    final file = await widget.pickDocument();
    if (file == null || !mounted) return;
    final error = validateClaimDocumentFile(file);
    if (error != null) {
      setState(() {
        _documentError = error;
        _documentPath = null;
        _documentName = null;
      });
      return;
    }
    setState(() {
      _uploadingDocument = true;
      _documentError = null;
      _documentPath = null;
    });
    try {
      final path = await widget.uploadDocument(file);
      if (!mounted) return;
      setState(() {
        _documentPath = path;
        _documentName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _documentError = _cleanError(e));
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await widget.pickPhoto();
    if (file == null || !mounted) return;
    final error = validateClaimPhotoFile(file);
    if (error != null) {
      setState(() {
        _photoError = error;
        _photoPath = null;
        _photoName = null;
      });
      return;
    }
    setState(() {
      _uploadingPhoto = true;
      _photoError = null;
      _photoPath = null;
    });
    try {
      final path = await widget.uploadPhoto(file);
      if (!mounted) return;
      setState(() {
        _photoPath = path;
        _photoName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _photoError = _cleanError(e));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.onSubmit(ClaimFormValues(
        applicantName: _nameCtrl.text.trim(),
        applicantPhone: _phoneCtrl.text.trim(),
        documentPath: _documentPath!,
        photoPath: _photoPath!,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = _cleanError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _statusLine({required bool uploading, required String? ok, required String? error}) {
    if (uploading) {
      return Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Mengunggah...', style: GoogleFonts.outfit(fontSize: 12)),
      ]);
    }
    if (error != null) {
      return Text(error, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFDC2626)));
    }
    if (ok != null) {
      return Text(ok, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF166534)));
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Klaim ${widget.storeName}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Lengkapi data dan bukti kepemilikan. Admin akan memeriksanya sebelum klaim disetujui.',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('claim_form_name'),
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nama lengkap pemohon', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('claim_form_phone'),
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nomor telepon', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('claim_form_pick_document'),
              onPressed: _uploadingDocument || _submitting ? null : _pickDocument,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Pilih dokumen legalitas (PDF/JPEG)'),
            ),
            const SizedBox(height: 4),
            _statusLine(
              uploading: _uploadingDocument,
              ok: _documentPath == null ? null : 'Dokumen terunggah: $_documentName',
              error: _documentError,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('claim_form_pick_photo'),
              onPressed: _uploadingPhoto || _submitting ? null : _pickPhoto,
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Pilih foto tampak depan toko (JPEG/PNG)'),
            ),
            const SizedBox(height: 4),
            _statusLine(
              uploading: _uploadingPhoto,
              ok: _photoPath == null ? null : 'Foto terunggah: $_photoName',
              error: _photoError,
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(_submitError!, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFDC2626))),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('claim_form_submit'),
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2818),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kirim Klaim'),
            ),
          ],
        ),
      ),
    );
  }
}
