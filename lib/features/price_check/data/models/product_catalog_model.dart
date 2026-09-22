class CatalogProduct {
  final String id;
  final String nama;
  final String kategori;
  final double? ukuran;
  final String? satuan;
  final double? hargaTerendah;
  final String? namaTokoTerendah;
  final int jumlahToko;
  final String? fotoUrl;
  final String? updatedAt;

  CatalogProduct({
    required this.id,
    required this.nama,
    required this.kategori,
    this.ukuran,
    this.satuan,
    this.hargaTerendah,
    this.namaTokoTerendah,
    this.jumlahToko = 0,
    this.fotoUrl,
    this.updatedAt,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      id: json['id'] as String? ?? '',
      nama: json['nama'] as String? ?? '',
      kategori: json['kategori'] as String? ?? 'General',
      ukuran: (json['ukuran'] as num?)?.toDouble(),
      satuan: json['satuan'] as String?,
      hargaTerendah: (json['harga_terendah'] as num?)?.toDouble(),
      namaTokoTerendah: json['nama_toko_terendah'] as String?,
      jumlahToko: json['jumlah_toko'] as int? ?? 0,
      fotoUrl: json['foto_url'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'ukuran': ukuran,
      'satuan': satuan,
      'harga_terendah': hargaTerendah,
      'nama_toko_terendah': namaTokoTerendah,
      'jumlah_toko': jumlahToko,
      'foto_url': fotoUrl,
      'updated_at': updatedAt,
    };
  }
}
