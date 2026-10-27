# Spesifikasi UI Flutter Kasirin

Dokumen ini adalah spesifikasi pengalaman pengguna untuk proyek Flutter di `android/kasirin_mobile/`. Gunakan bersama `ANDROID_PORT_PROMPT.md` dan source desktop pada folder induk. Spesifikasi ini mengatur UI/UX; aturan bisnis dan status transaksi tetap berasal dari service serta test desktop.

## 1. Tujuan Desain

- POS untuk toko yang digunakan berulang sepanjang hari: cepat dipindai, mudah disentuh, informatif, dan tidak mengganggu transaksi.
- Satu codebase untuk Android dan iOS; alur dan hierarki konsisten, tetapi navigasi, permission, safe area, keyboard, back gesture, file picker, dan hardware mengikuti platform.
- Responsif untuk ponsel dan tablet. Jangan mengecilkan dashboard desktop menjadi tampilan ponsel.
- Kasir harus dapat menyelesaikan transaksi rutin dengan sesedikit mungkin perpindahan layar.
- UI menampilkan state nyata dari domain: loading, kosong, validasi, error, sukses, offline, shift, lisensi/trial, dan read-only.
- Tampilan profesional dan tenang. Hindari dekorasi marketing, gradient berlebihan, shadow berat, kartu bertumpuk, dan animasi yang memperlambat transaksi.

## 2. Bahasa Visual

### Warna

Pertahankan identitas desktop Kasirin, tetapi sediakan tema terang untuk lingkungan toko dan tema gelap opsional.

| Token | Light | Dark | Kegunaan |
|---|---|---|---|
| `canvas` | `#F4F6F8` | `#121214` | Latar halaman |
| `surface` | `#FFFFFF` | `#1A1A1E` | Panel kerja dan dialog |
| `surfaceRaised` | `#EEF1F4` | `#222226` | Input, hover, area sekunder |
| `textPrimary` | `#17212B` | `#FFFFFF` | Teks utama |
| `textSecondary` | `#586575` | `#A1A1AA` | Deskripsi dan label sekunder |
| `outline` | `#D7DEE5` | `#2D2D34` | Border dan pemisah |
| `primary` | `#006EAE` | `#0098FF` | Aksi utama/fokus |
| `primaryPressed` | `#005995` | `#007ACC` | Tombol ditekan |
| `success` | `#18794E` | `#4ADE80` | Berhasil/lunas/aktif |
| `warning` | `#9A6700` | `#FACC15` | Pending/perlu perhatian |
| `danger` | `#B42318` | `#F87171` | Gagal/hapus/void |

Jangan memakai warna saja untuk mengkomunikasikan status; selalu sertakan label atau ikon dengan semantic label. Uji kontras teks dan kontrol, terutama tombol utama dan badge.

### Tipografi

- Gunakan Inter sebagai font UI yang dibundel, dengan lisensi font disertakan; fallback ke font sistem platform.
- Teks isi 14-16sp; label dan metadata minimal 12sp; body penting minimal 14sp.
- Angka nominal/total menggunakan angka tabular jika tersedia, rata kanan, dan format Rupiah konsisten.
- Total pembayaran boleh menonjol, tetapi jangan memakai ukuran hero yang membuat layout transaksi bergeser.
- Hindari uppercase panjang, huruf dekoratif, dan letter spacing negatif.

### Spacing, Bentuk, dan Kontrol

- Skala spacing: 4, 8, 12, 16, 24, 32.
- Tinggi target sentuh minimal 48dp; tombol aksi kasir utama 52-56dp.
- Radius kontrol 8dp; panel/dialog 10-12dp; badge/pill hanya untuk status ringkas.
- Border tipis dan pemisah lebih diutamakan daripada shadow. Jangan meletakkan card di dalam card.
- Gunakan ikon konsisten dari satu library Flutter yang dipilih; selalu beri tooltip/semantics pada icon-only action.
- Input numerik membuka keypad yang sesuai; field barcode dapat mempertahankan fokus untuk scanner keyboard wedge.

## 3. Navigasi dan Layout Adaptif

Gunakan `LayoutBuilder` atau mekanisme responsive Flutter, bukan deteksi model perangkat yang rapuh.

### Ponsel: lebar compact

- Gunakan `NavigationBar` bawah untuk tujuan utama, dengan maksimal 4 tujuan yang terlihat.
- OWNER: `Ringkasan`, `Kasir`, `Produk`, `Lainnya`.
- ADMIN/SUPERVISOR: `Kasir`, `Penjualan`, `Produk`, `Lainnya`, sesuai izin aktual.
- CASHIER: buka langsung ke `Kasir`; tampilkan akses ringkas ke `Shift`, `Riwayat`, dan profil dari navigasi yang sesuai.
- Menu `Lainnya` berisi fitur yang lebih jarang dipakai seperti Pembelian, Persediaan, Laporan, Keuangan, Manajemen Pengguna, Pengaturan, Lisensi.
- Gunakan bottom sheet untuk pemilih singkat; gunakan halaman penuh untuk form panjang, report kompleks, wizard, dan transaksi detail.

### Tablet: lebar medium/expanded

- Gunakan `NavigationRail` atau sidebar ringkas dengan label; pertahankan konten utama pada area kerja yang lega.
- POS dapat memakai split view: katalog/pencarian di satu sisi dan keranjang/ringkasan di sisi lain.
- Pada lebar ekstra, laporan atau master data boleh menggunakan tabel dengan kolom responsif.
- Tidak boleh ada overflow horizontal untuk alur normal.

### Navigasi Umum

- Tampilkan nama toko, pengguna, role, status shift, dan indikator koneksi secara ringkas pada header/shell.
- Tombol Back/gesture tidak boleh diam-diam membuang pembayaran, pembelian, atau perubahan form yang belum tersimpan. Minta konfirmasi bila ada data yang akan hilang.
- Deep link bukan prasyarat awal. Jangan menambahkan menu ke halaman yang tidak memiliki use case.

## 4. Struktur Layar dan Spesifikasi Perilaku

### 4.1 Splash, Setup OWNER, dan Login

- Splash hanya untuk memulihkan database/session dan memeriksa lisensi/trial; jangan menahan lama dengan animasi.
- Database kosong: tampilkan setup OWNER, bukan login demo. Form berisi nama lengkap, username, password, konfirmasi password; validasi dekat field.
- Database sudah memiliki user: tampilkan login sederhana dengan fokus awal pada username/email sesuai kontrak autentikasi lokal.
- Beri feedback untuk password salah, akun terkunci, user tidak aktif, dan kewajiban mengganti password.
- Login billing_server untuk aktivasi lisensi harus dibedakan secara jelas dari login lokal karyawan.

### 4.2 Ringkasan OWNER

- Ringkasan operasional: total penjualan/periode, status shift, stok rendah, ringkasan transaksi, serta shortcut ke Kasir, Produk, Pembelian, Laporan.
- Jangan menampilkan data dummy di produksi. Empty state menawarkan tindakan relevan: tambah produk, buka shift, atau atur toko.
- Kartu subscription/lisensi tampilkan trial/aktif/kedaluwarsa, sisa masa berlaku, status online bila tersedia, dan tindakan aktivasi yang jelas.
- Gunakan grid adaptif; pada ponsel ringkas menjadi daftar prioritas, bukan grid mini.

### 4.3 POS Kasir dan Checkout

Ini layar paling penting dan harus diuji dengan transaksi nyata pada emulator/perangkat.

- Header ringkas berisi status shift, nama kasir, pencarian/scan produk, dan pintasan customer.
- Area produk: pencarian SKU, barcode, nama, kategori; hasil menampilkan nama, harga, stok, dan indikator harga grosir bila berlaku.
- Keranjang menampilkan item, qty yang mudah diedit, harga unit, diskon, subtotal, dan hapus item. Jangan mengubah harga di UI tanpa validasi service.
- Total akhir, diskon, pajak bila konfigurasi mengaktifkan, dan kembalian selalu mudah dibaca.
- Aksi utama `Bayar` memiliki kontras tinggi dan tidak tertutup keyboard/navigation bar.
- Checkout: pilih metode pembayaran yang aktif saja; tampilkan nominal diterima, sisa/kembalian, referensi bila diperlukan, dan ringkasan sebelum simpan.
- Setelah sukses tampilkan nomor invoice dan status; pilihan cetak/bagikan struk tidak boleh mengubah hasil transaksi.
- State wajib: keranjang kosong, produk tak ditemukan, stok tidak cukup, metode nonaktif, shift belum buka, service menolak karena lisensi/read-only, pembayaran gagal, database gagal/rollback, sukses.
- Cegah double tap atau retry yang membuat sale/payment/stock movement duplikat. Kunci tombol selama commit dan tampilkan hasil idempotent yang benar.

### 4.4 Shift dan Penjualan Harian

- Buka shift dengan nominal kas awal dan konfirmasi kasir.
- Tampilkan shift aktif, waktu buka, saldo kas pembuka, total penjualan, dan transaksi terkait.
- Tutup shift dengan hitungan kas akhir, selisih, catatan, serta konfirmasi.
- Laporan harian kasir menampilkan penjualan dan catatan; edit/update mengikuti aturan service desktop.

### 4.5 Master Data Produk

- List produk dengan pencarian cepat dan filter kategori/status/stok rendah; dukung scan barcode.
- Detail/form produk memuat SKU/barcode, nama, kategori, unit, supplier pilihan, harga beli/jual, stok/minimum, status aktif, dan aturan harga grosir.
- Tampilkan riwayat stok dan sumber perubahan; tambah stok harus meminta jumlah dan catatan sesuai perilaku desktop.
- Import spreadsheet harus melalui preview, validasi per baris, ringkasan error, dan konfirmasi sebelum transaksi batch.
- Soft delete menampilkan konfirmasi dan menjelaskan dampak pada histori; jangan menghapus histori penjualan.

### 4.6 Supplier dan Pembelian

- Supplier: cari, tambah, edit, detail kontak, dan daftar pembelian terkait.
- Purchase order: supplier, tanggal, item/qty/harga, subtotal, status penerimaan, termin PAID/TEMPO/DP, jumlah dibayar, jatuh tempo, dan catatan.
- Buat ringkasan utang/jatuh tempo dan aksi pembayaran/pelunasan sesuai status yang valid.
- Validasi DP dan tempo dekat field; stok hanya bertambah saat aturan penerimaan pembelian menetapkannya.
- Pembuatan produk cepat dari alur belanja harus memperlihatkan default yang akan disimpan dan dapat dikoreksi sebelum commit.

### 4.7 Persediaan dan Stock Opname

- Dashboard stok: stok rendah, nilai persediaan, pencarian, serta navigasi ke movement/opname.
- Stock movement dapat difilter waktu, produk, jenis, dan referensi; tampilkan stok sebelum, perubahan, stok sesudah, dan catatan.
- Opname: buat draft, hitung qty aktual, bandingkan dengan qty sistem, catat selisih dan notes, lalu commit dengan konfirmasi.
- Inventaris toko non-jual dibedakan jelas dari produk yang dijual.

### 4.8 Laporan dan Keuangan

- Laporan memiliki filter periode yang konsisten, total/ringkasan yang mudah dibandingkan, pencarian bila relevan, dan ekspor via document picker.
- Keuangan menampilkan tanggal mulai pembukuan, saldo awal, akun, jurnal, dan laporan Laba Rugi/Neraca/Arus Kas/Neraca Saldo/Jurnal Umum.
- Form saldo awal dan jurnal harus memperlihatkan debit/kredit dan status seimbang sebelum simpan.
- Expenses mendukung CASH/HUTANG/DP, penerima, kategori akun, tanggal, jumlah dibayar, jatuh tempo, dan pembayaran bertahap sesuai service.
- Jangan menyajikan angka seolah real-time bila data belum dimuat atau kalkulasi gagal; tunjukkan error/last updated.

### 4.9 Pengguna, Pengaturan, Pembayaran, dan Lisensi

- Manajemen user hanya untuk role berizin. Tampilkan role, aktif/nonaktif, status ganti password, dan histori relevan. Aksi hapus/nonaktif harus memiliki konfirmasi dan perlindungan akun sendiri.
- Pengaturan toko: profil, logo, slogan, alamat, WhatsApp, format struk, metode pembayaran, dan wizard konfigurasi. Gunakan crop/preview logo yang sesuai mobile.
- Wizard pembayaran memperlihatkan langkah, progress, validasi, test connection, serta status tersimpan; secret tidak ditampilkan ulang.
- Lisensi: status trial/aktif/expired, pilihan aktivasi offline import license, aktivasi online via billing_server, progress registrasi device, retry, dan error yang dapat ditindaklanjuti. Tidak boleh ada secret private dalam app.
- Read-only mode harus mudah dikenali dan menjelaskan aksi apa yang terkunci; jangan hanya menghilangkan tombol tanpa konteks.

## 5. Komponen Bersama

Buat design-system widgets reusable secukupnya:

- `AppScaffold`/responsive navigation shell.
- `AppButton` untuk primary, secondary, destructive, dan loading/disabled.
- `MoneyText` dan formatter Rupiah tunggal.
- `SearchField` dengan clear, scan action, dan accessibility label.
- `StatusChip` dengan teks + ikon untuk PAID, TEMPO, DP, pending, error, trial, active.
- `EmptyState`, `ErrorState` dengan retry yang sesuai, dan loading skeleton/progress.
- `ConfirmActionSheet` untuk aksi destruktif/commit penting.
- `DateRangeFilter`, `QuantityStepper`, `NumericAmountField`, `ProductRow`, `CartLine`, dan `SummaryTotal`.
- Semua komponen menampilkan state enabled/disabled/focused/loading/error secara konsisten dan mempunyai semantics untuk screen reader.

Jangan membangun abstraksi widget yang terlalu generik. Setiap widget bersama harus mengurangi duplikasi perilaku nyata.

## 6. Motion dan Feedback

- Gunakan animasi singkat untuk perpindahan state bermakna (misalnya item masuk keranjang, sukses checkout, expand detail), bukan dekorasi terus-menerus.
- Hormati pengaturan reduce motion/platform accessibility.
- Haptic feedback hanya untuk aksi penting dan bila didukung; jangan menggantikan label visual/audio.
- Jangan menunda input kasir atau commit transaksi demi animasi.

## 7. Accessibility dan Responsivitas

- Minimum target 48dp; area keypad dan tombol bayar harus nyaman pada layar ponsel ukuran kecil.
- Semua input memiliki label, hint, error message yang terbaca screen reader, urutan fokus logis, dan keyboard action yang sesuai.
- Kontras teks/status memenuhi aksesibilitas; dukung font scale sistem tanpa clipping atau menutupi total/aksi utama.
- Uji compact phone, phone lebar, tablet portrait/landscape, iOS safe areas/notch, Android edge-to-edge, keyboard terbuka, dan mode landscape POS.
- Tidak ada horizontal overflow pada form normal; tabel kompleks berubah menjadi row/card responsif pada layar kecil.

## 8. Aturan Implementasi UI

- Widget hanya merender state dan meneruskan intent; business rules, kalkulasi total, permission check, serta transaksi DB berada di domain/use case/repository.
- Sumber kebenaran harga/discount/stok adalah domain service, bukan state lokal widget.
- Setiap mutasi penting memiliki loading, sukses, dan error yang jelas; jangan menelan exception.
- Saat navigasi melewati form dirty atau checkout draft, konfirmasi simpan/buang/lanjutkan sesuai konteks.
- Tampilkan status offline secara halus namun terlihat. Aksi lokal tetap tersedia; hanya aksi billing yang memerlukan server dinonaktifkan/diantrekan sesuai aturan.

## 9. Kriteria Uji UI

- Golden/screenshot tests untuk theme light/dark, compact phone, expanded/tablet, dan text scale besar.
- Widget tests untuk navigasi role, form validation, state empty/loading/error, harga grosir di keranjang, read-only state, serta konfirmasi checkout.
- Integration tests untuk setup OWNER → login → buka shift → cari/scan produk → checkout → receipt result, plus pembelian dan pembayaran sesuai aturan.
- Accessibility tests untuk semantics, label, target sentuh, kontras utama, dan text overflow.
- Uji hardware printer/barcode pada perangkat nyata Android dan iOS secara terpisah; test widget bukan bukti dukungan hardware.

---

## Hasil yang Diharapkan

Gunakan dokumen ini sebagai dasar implementasi UI dan lampirkan mapping setiap layar ke parity matrix. Bila perilaku desktop ambigu, rujuk service/test desktop, dokumentasikan keputusan, dan jangan menciptakan aturan bisnis baru hanya untuk menyelesaikan desain layar.
