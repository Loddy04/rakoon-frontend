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

  const DocumentContent({
    required this.title,
    this.lastUpdated,
    required this.sections,
  });
}

const DocumentContent privacyPolicyContent = DocumentContent(
  title: 'Kebijakan Privasi',
  lastUpdated: '30 September 2026',
  sections: [
    DocumentSection(
      title: '1. Pendahuluan',
      paragraphs: [
        'Selamat datang di RAKOON ("kami", "aplikasi"). Kami sangat menghargai privasi dan berkomitmen untuk melindungi data pribadi pengguna ("pengguna", "Anda"). Kebijakan Privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, menyimpan, dan menjaga informasi saat Anda menggunakan aplikasi mobile Rakoon.',
      ],
    ),
    DocumentSection(
      title: '2. Data yang Kami Kumpulkan',
      paragraphs: [
        'Kami hanya mengumpulkan data yang benar-benar dibutuhkan untuk menyediakan dan meningkatkan fungsionalitas layanan Rakoon:',
      ],
      bulletPoints: [
        'Informasi Akun Google (Google OAuth): Saat Anda masuk menggunakan Google Sign-In, kami hanya mengakses informasi dasar profil publik yang Anda izinkan, yaitu: nama lengkap, alamat email, dan foto profil.',
        'Data Gambar / Citra Kamera: Gambar label harga rak toko fisik yang Anda ambil melalui kamera gawai Anda untuk diproses oleh sistem Vision AI ekstraksi harga dan produk.',
        'Data Lokasi Geografis (GPS): Data koordinat perkiraan lokasi Anda (hanya jika Anda memberikan izin akses lokasi) yang digunakan untuk menemukan dan membandingkan harga minimarket/ritel terdekat di sekitar Anda.',
        'Data Keranjang & Preferensi Belanja: Daftar belanjaan, riwayat pencarian harga, dan batas anggaran yang Anda simpan di dalam aplikasi.',
      ],
    ),
    DocumentSection(
      title: '3. Tujuan Penggunaan Data',
      paragraphs: [
        'Informasi yang kami kumpulkan digunakan semata-mata untuk:',
      ],
      bulletPoints: [
        'Memverifikasi identitas Anda dan mengelola sesi autentikasi akun secara aman.',
        'Menyimpan dan menyinkronkan keranjang belanja, histori pindaian, dan preferensi anggaran Anda di seluruh perangkat.',
        'Melakukan komparasi harga dan merekomendasikan rute ritel terdekat yang paling hemat.',
        'Meningkatkan kualitas performa dan akurasi model pembacaan label rak.',
      ],
    ),
    DocumentSection(
      title: '4. Kepatuhan Kebijakan Data Pengguna Google (Google API Services User Data Policy)',
      paragraphs: [
        'Aplikasi Rakoon mematuhi secara penuh Google API Services User Data Policy, termasuk persyaratan Limited Use:',
      ],
      bulletPoints: [
        'Penggunaan data yang diperoleh melalui Google OAuth terbatas hanya untuk menyediakan fitur autentikasi dan pengalaman pengguna di dalam aplikasi Rakoon.',
        'KAMI TIDAK MENJUAL DATA PRIBADI ANDA: Data pribadi Anda, termasuk data yang diperoleh dari akun Google, tidak akan pernah dijual, disewakan, atau diperdagangkan kepada pihak ketiga atau jaringan periklanan.',
        'Kami tidak menggunakan data akun Google untuk keperluan periklanan bertarget (targeted ads) atau pembuatan profil komersial pihak ketiga.',
      ],
    ),
    DocumentSection(
      title: '5. Penyimpanan dan Keamanan Data',
      paragraphs: [
        'Keamanan data Anda adalah prioritas kami. Semua transmisi data antara aplikasi gawai Anda dan peladen (server) dilindungi dengan enkripsi standar industri (HTTPS / TLS 1.3). Data akun dan basis data disimpan secara aman menggunakan infrastruktur terenkripsi dengan kontrol akses yang ketat.',
      ],
    ),
    DocumentSection(
      title: '6. Hak Pengguna & Penghapusan Akun / Data (Data Deletion)',
      paragraphs: [
        'Anda memiliki hak penuh untuk mengakses, memperbarui, atau meminta penghapusan seluruh data pribadi Anda dari sistem kami:',
      ],
      bulletPoints: [
        'Anda dapat mencabut izin akses Google Sign-In kapan saja melalui pengaturan Akun Google Anda (Google Account Security Settings).',
        'Untuk meminta penghapusan permanen akun Rakoon beserta seluruh riwayat belanja dan data terkait dari server kami, silakan hubungi kami melalui email pengembang di bawah ini. Kami akan memproses permintaan Anda dalam waktu maksimal 7 hari kerja.',
      ],
    ),
    DocumentSection(
      title: '7. Hubungi Kami',
      paragraphs: [
        'Jika Anda memiliki pertanyaan, saran, atau permohonan terkait privasi data Anda, silakan hubungi tim pengembang kami melalui:',
      ],
      bulletPoints: [
        'Tim Pengembang Rakoon',
        'Kontak Pengembang: ayyasheufrat2@gmail.com',
        'Proyek Riset & Aplikasi: RAKOON (Rak Pintar & Komparasi Harga Belanja Cerdas)',
      ],
    ),
  ],
);

const DocumentContent termsOfServiceContent = DocumentContent(
  title: 'Syarat & Ketentuan',
  lastUpdated: '30 September 2026',
  sections: [
    DocumentSection(
      title: '1. Penerimaan Ketentuan',
      paragraphs: [
        'Dengan mengunduh, mengakses, atau menggunakan aplikasi RAKOON, Anda setuju untuk terikat oleh Ketentuan Layanan ini. Jika Anda tidak menyetujui salah satu ketentuan ini, Anda disarankan untuk tidak menggunakan aplikasi.',
      ],
    ),
    DocumentSection(
      title: '2. Deskripsi Layanan',
      paragraphs: [
        'RAKOON adalah aplikasi pendukung keputusan belanja konsumen yang menyediakan fitur pemindaian label harga rak berbasis Vision-Language Model (VLM), normalisasi nilai harga per unit (Rp/g, Rp/ml), komparasi harga multi-ritel terdekat, dan rekomendasi alokasi anggaran belanja harian.',
      ],
    ),
    DocumentSection(
      title: '3. Batasan Tanggung Jawab & Data Harga',
      paragraphs: [
        'Data harga produk, promosi, dan ketersediaan barang di gerai fisik (seperti Alfamart, Indomaret, Super Indo, dan gerai lainnya) disajikan untuk tujuan referensi dan estimasi. Harga riil dapat berubah sewaktu-waktu oleh masing-masing peritel di kasir. Tim pengembang RAKOON berusaha semaksimal mungkin menjaga akurasi pembacaan AI, namun tidak bertanggung jawab atas selisih harga fisik di kasir toko.',
      ],
    ),
    DocumentSection(
      title: '4. Akun Pengguna & Kewajiban',
      paragraphs: [
        'Anda bertanggung jawab untuk menjaga kerahasiaan akun Anda dan tidak menyalahgunakan layanan aplikasi untuk tindakan yang melanggar hukum, merusak sistem, atau memanipulasi data komparasi harga.',
      ],
    ),
    DocumentSection(
      title: '5. Hak Kekayaan Intelektual',
      paragraphs: [
        'Perangkat lunak RAKOON dirilis di bawah lisensi sumber terbuka (open-source MIT License). Seluruh merek dagang ritel dan logo pihak ketiga yang ditampilkan di dalam aplikasi adalah hak milik dari pemiliknya masing-masing dan hanya digunakan untuk keperluan identifikasi komparasi harga.',
      ],
    ),
    DocumentSection(
      title: '6. Kontak',
      paragraphs: [
        'Pertanyaan mengenai Ketentuan Layanan ini dapat dikirimkan melalui email ke: ayyasheufrat2@gmail.com.',
      ],
    ),
  ],
);

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
        'Asisten Anggaran (Smart Budget Shopping): Membantu menyusun keranjang belanja sesuai batas anggaran harian Anda.',
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
);
