import 'package:rakoon_frontend/core/constants/legal_urls.dart';

class DocumentLinkItem {
  final String label;
  final String url;

  const DocumentLinkItem({
    required this.label,
    required this.url,
  });
}

class DocumentSection {
  final String title;
  final List<String> paragraphs;
  final List<String> bulletPoints;

  const DocumentSection({
    required this.title,
    this.paragraphs = const [],
    this.bulletPoints = const [],
  });
}

class DocumentContent {
  final String title;
  final String? lastUpdated;
  final List<DocumentSection> sections;
  final List<DocumentLinkItem> links;

  const DocumentContent({
    required this.title,
    this.lastUpdated,
    required this.sections,
    this.links = const [],
  });
}

const DocumentContent helpContent = DocumentContent(
  title: 'Bantuan',
  sections: [
    DocumentSection(
      title: '1. Tentang Rakoon',
      paragraphs: [
        'Rakoon adalah asisten belanja cerdas bertenaga AI Vision untuk memindai label rak ritel, menghitung nilai riil per unit standar, dan membandingkan harga minimarket sekitar Anda.',
      ],
    ),
    DocumentSection(
      title: '2. Panduan Penggunaan Fitur',
      paragraphs: [
        'Berikut cara memaksimalkan fitur-fitur di aplikasi Rakoon:',
      ],
      bulletPoints: [
        'Smart Shelf Scanning: Pindai label harga rak supermarket secara otomatis dengan kamera gawai. Pengambilan foto rak memerlukan pengguna telah masuk (login) agar sesi pemindaian tersimpan ke riwayat akun.',
        'Normalisasi Nilai (Best Value): Sistem menghitung nilai riil harga per unit standar (Rp/g, Rp/ml) untuk membantu Anda memilih produk yang benar-benar ekonomis dan menghindari shrinkflation.',
        'Komparasi Multi-Ritel Terdekat: Menemukan dan membandingkan harga produk di minimarket atau gerai terdekat (seperti Indomaret, Alfamart, Super Indo). Fitur ini memerlukan izin akses lokasi GPS yang aktif. Jarak dihitung garis lurus dari lokasimu. Jarak tempuh sebenarnya bisa lebih jauh; gunakan tombol Rute untuk melihatnya di Maps.',
        'Informasi Kebaruan Harga: Menampilkan riwayat fluktuasi harga. Data harga produk yang berumur lebih dari 90 hari akan diberi tanda label informasi kebaruan harga.',
        'Asisten Anggaran (Smart Budget Shopping): Membantu mengoptimalkan pilihan produk kebutuhan belanja sesuai batas anggaran harian Anda.',
      ],
    ),
    DocumentSection(
      title: '3. Kontak Pengembang',
      paragraphs: [
        'Jika mengalami kendala, pertanyaan teknis, atau memiliki saran perbaikan aplikasi, Anda dapat menghubungi tim pengembang melalui:',
      ],
      bulletPoints: [
        'Email Pengembang: ayyasheufrat2@gmail.com',
        'Tim Pengembang RAKOON (Rak Pintar & Komparasi Harga Belanja Cerdas)',
      ],
    ),
  ],
  links: [
    DocumentLinkItem(
      label: 'Kebijakan Privasi',
      url: privacyPolicyUrl,
    ),
    DocumentLinkItem(
      label: 'Syarat & Ketentuan',
      url: termsOfServiceUrl,
    ),
  ],
);
