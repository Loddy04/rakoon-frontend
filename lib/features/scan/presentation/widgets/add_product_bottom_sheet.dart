import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakoon_frontend/services/scan_service.dart';

class AddProductBottomSheet extends StatefulWidget {
  final ValueChanged<ScanResultItem>? onAdded;

  const AddProductBottomSheet({
    super.key,
    this.onAdded,
  });

  @override
  State<AddProductBottomSheet> createState() => _AddProductBottomSheetState();
}

class _AddProductBottomSheetState extends State<AddProductBottomSheet> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final sizeController = TextEditingController();
  String selectedCategory = 'Makanan Pokok';
  String selectedUnit = 'gr';
  String? _nameError;
  String? _priceError;
  String? _sizeError;
  static const List<String> standardUnits = ['gr', 'kg', 'ml', 'L', 'pcs'];

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    sizeController.dispose();
    super.dispose();
  }

  void _saveItem() {
    final name = nameController.text.trim();
    final priceText = priceController.text.trim();
    final sizeText = sizeController.text.trim();

    String? nameErr;
    String? priceErr;
    String? sizeErr;

    if (name.isEmpty) {
      nameErr = 'Nama produk wajib diisi';
    }

    final cleanPriceText = priceText.replaceAll('.', '').replaceAll(',', '').replaceAll(' ', '');
    final parsedPrice = double.tryParse(cleanPriceText);
    if (cleanPriceText.isEmpty || parsedPrice == null || parsedPrice <= 0 || parsedPrice.isNaN || parsedPrice.isInfinite) {
      priceErr = 'Harga wajib diisi (lebih dari Rp 0)';
    }

    final cleanSizeText = sizeText.replaceAll(',', '.').trim();
    final parsedSize = double.tryParse(cleanSizeText);
    if (cleanSizeText.isEmpty || parsedSize == null || parsedSize <= 0 || parsedSize.isNaN || parsedSize.isInfinite) {
      sizeErr = 'Ukuran wajib diisi';
    }

    if (nameErr != null || priceErr != null || sizeErr != null) {
      setState(() {
        _nameError = nameErr;
        _priceError = priceErr;
        _sizeError = sizeErr;
      });
      return;
    }

    final newItem = ScanResultItem(
      namaProduk: name,
      harga: parsedPrice,
      ukuran: parsedSize,
      satuan: selectedUnit,
      kategori: selectedCategory,
      confidence: 'tinggi',
      needsVerification: false,
    );

    Navigator.pop(context, newItem);
    widget.onAdded?.call(newItem);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Drag handle pill
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header Row: Judul & tombol tutup bundar lembut di kanan
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tambah Produk Manual',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D2818),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Nama Produk
                Text(
                  'Nama Produk',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('add_name_field'),
                  controller: nameController,
                  onChanged: (val) {
                    if (_nameError != null) {
                      setState(() {
                        _nameError = null;
                      });
                    }
                  },
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2818)),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Indomie Goreng',
                    hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
                    errorText: _nameError,
                    errorStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _nameError != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _nameError != null ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Kategori Dropdown
                Text(
                  'Kategori',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: const Key('add_category_dropdown'),
                  initialValue: selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                    ),
                  ),
                  items: productCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(
                        cat,
                        style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0D2818)),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                // 5. Harga
                Text(
                  'Harga',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('add_price_field'),
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    if (_priceError != null) {
                      setState(() {
                        _priceError = null;
                      });
                    }
                  },
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2818)),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D2818),
                    ),
                    errorText: _priceError,
                    errorStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _priceError != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _priceError != null ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Baris Ukuran & Satuan (Berdampingan)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom Kiri: Ukuran (flex 3)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ukuran',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            key: const Key('add_size_field'),
                            controller: sizeController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              if (_sizeError != null) {
                                setState(() {
                                  _sizeError = null;
                                });
                              }
                            },
                            style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0D2818)),
                            decoration: InputDecoration(
                              hintText: 'Contoh: 200',
                              hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF9CA3AF)),
                              errorText: _sizeError,
                              errorStyle: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _sizeError != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _sizeError != null ? const Color(0xFFEF4444) : const Color(0xFF00875A),
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Kolom Kanan: Satuan (flex 2)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satuan',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const Key('add_unit_dropdown'),
                            initialValue: selectedUnit,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF00875A), width: 1.5),
                              ),
                            ),
                            items: standardUnits.map((u) {
                              return DropdownMenuItem<String>(
                                value: u,
                                child: Text(
                                  u,
                                  style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0D2818)),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedUnit = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Warning Box jika ada error validasi
                if (_nameError != null || _priceError != null || _sizeError != null) ...[
                  Container(
                    key: const Key('add_validation_warning_box'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mohon periksa kembali kolom yang belum terisi dengan benar.',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tombol Tambah Produk
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('save_add_button'),
                    onPressed: _saveItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tambah Produk',
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
