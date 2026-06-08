import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // untuk compute()
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io'; // untuk File
import 'dart:typed_data'; // untuk Uint8List
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../core/config/api_config.dart';
import 'package:provider/provider.dart';
import '../../booking/screens/booking_history_screen.dart';
import '../../../core/utils/point_provider.dart';
import '../../auth/screens/login_screen.dart';

// ============================================================
// TOP-LEVEL FUNCTION untuk membaca file di isolate terpisah
// WAJIB top-level agar bisa dipakai oleh compute()
// Tanpa ini, I/O berjalan di UI thread dan menyebabkan freeze
// ============================================================
Future<Uint8List> _readImageBytesInIsolate(String filePath) async {
  return await File(filePath).readAsBytes();
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- Variabel Data User ---
  String _nama = "Memuat...";
  String _email = "Memuat...";
  String _kesanPesan = "";

  // URL foto dari server. null = belum ada foto
  String? _fotoProfilUrl;

  // Preview lokal (bytes) saat foto baru dipilih tapi belum selesai upload
  // Ini membuat preview INSTAN tanpa menunggu upload selesai
  Uint8List? _localPreviewBytes;

  // Flag loading
  bool _isUploadingPhoto = false;
  bool _isSavingBio = false;

  // Upload progress (0.0 - 1.0)
  double _uploadProgress = 0.0;

  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // KEY untuk memaksa NetworkImage reload setelah upload berhasil
  Key _avatarKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD DATA PROFIL
  // Optimasi: jalankan API call dan fetch poin secara paralel
  // ============================================================
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Tampilkan data cache dulu agar UI tidak kosong
    if (mounted) {
      setState(() {
        _nama = prefs.getString('user_name') ?? "Guest User";
        _email = prefs.getString('user_email') ?? 'guest@caffio.com';
      });
    }

    if (token == null || token.isEmpty) return;

    try {
      final email = prefs.getString('user_email') ?? _email;

      // Jalankan API profile dan fetch poin secara PARALEL
      // Ini memangkas waktu loading hampir 50% dibanding sequential await
      final profileFuture = http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final poinFuture = (email != 'guest@caffio.com' && mounted)
          ? Provider.of<PointProvider>(context, listen: false).fetchPoinFromDB()
          : Future.value();

      final results = await Future.wait([profileFuture, poinFuture]);
      final response = results[0] as http.Response;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        if (mounted) {
          setState(() {
            _nama = user['nama'] ?? _nama;
            _email = user['email'] ?? _email;
            _kesanPesan = user['kesan_pesan'] ?? "";
            _fotoProfilUrl = user['foto_profil'];
          });

          await prefs.setString('user_name', _nama);
          await prefs.setString('user_email', _email);
        }
      }
    } catch (e) {
      debugPrint("Gagal load profil dari server: $e");
    }
  }

  // ============================================================
  // KLAIM REWARD (tidak diubah — business logic tetap sama)
  // ============================================================
  Future<void> _claimReward() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/claim-reward');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _email}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Provider.of<PointProvider>(context, listen: false).resetPoin();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Voucher Diskon 50% berhasil diklaim! Poin telah digunakan."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gagal mengklaim reward. Coba lagi."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error claim reward: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Koneksi bermasalah. Periksa jaringanmu."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // PICK & UPLOAD FOTO PROFIL — VERSI DIOPTIMASI
  //
  // Perubahan utama vs versi lama:
  // 1. maxWidth/maxHeight di pickImage → file lebih kecil sebelum upload
  // 2. Preview lokal (MemoryImage) tampil INSTAN setelah pick
  // 3. Baca bytes via compute() → non-blocking UI thread
  // 4. NetworkImage cache di-evict paksa setelah upload
  // 5. UniqueKey force-rebuild avatar widget
  // ============================================================
  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 800,   // batasi resolusi — kamera modern bisa 4000px+
        maxHeight: 800,  // ini yang paling penting: kurangi ukuran file drastis
      );

      if (pickedFile == null) return;

      // --- LANGKAH 1: Baca bytes di isolate terpisah (non-blocking UI) ---
      // compute() menjalankan fungsi di Dart isolate lain, UI tetap smooth
      final imageBytes = await compute(_readImageBytesInIsolate, pickedFile.path);

      // --- LANGKAH 2: Tampilkan preview INSTAN dari bytes lokal ---
      // User langsung melihat foto baru tanpa tunggu upload selesai
      if (mounted) {
        setState(() {
          _localPreviewBytes = imageBytes;
          _isUploadingPhoto = true;
          _uploadProgress = 0.1;
        });
      }

      // --- LANGKAH 3: Ambil token ---
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        if (mounted) {
          setState(() {
            _localPreviewBytes = null;
            _isUploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sesi habis. Silakan login kembali."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // --- LANGKAH 4: Upload ---
      final fileExtension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(fileExtension);

      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/update-profile');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // fromBytes lebih efisien dari fromPath saat bytes sudah di memory
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto_profil',
          imageBytes,
          filename: 'profile.$fileExtension',
          contentType: MediaType.parse(mimeType),
        ),
      );
      request.fields['kesan_pesan'] = _kesanPesan;

      if (mounted) setState(() => _uploadProgress = 0.4);

      final streamedResponse = await request.send();

      if (mounted) setState(() => _uploadProgress = 0.8);

      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) setState(() => _uploadProgress = 1.0);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newFotoUrl = data['foto_url'];

        if (mounted) {
          // Evict cache NetworkImage lama agar foto lama tidak ditampilkan
          // Ini fix utama untuk "foto lama masih muncul setelah ganti foto"
          if (_fotoProfilUrl != null) {
            try {
              NetworkImage(_fotoProfilUrl!).evict();
            } catch (_) {}
          }

          setState(() {
            _fotoProfilUrl = newFotoUrl;
            _localPreviewBytes = null; // Hapus preview lokal
            _avatarKey = UniqueKey(); // Force rebuild widget avatar
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Foto profil berhasil diperbarui!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint("Gagal upload foto: ${response.body}");
        if (mounted) {
          setState(() => _localPreviewBytes = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Gagal upload foto: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error upload foto: $e");
      if (mounted) {
        setState(() => _localPreviewBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal mengambil atau mengupload foto."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // ============================================================
  // SIMPAN KESAN & PESAN (business logic tidak diubah)
  // ============================================================
  Future<void> _saveKesanPesan(String newBio) async {
    setState(() => _isSavingBio = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sesi habis. Silakan login kembali."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/update-profile');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['kesan_pesan'] = newBio;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _kesanPesan = newBio);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Kesan & Pesan berhasil disimpan!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint("Gagal simpan kesan pesan: ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Gagal menyimpan: ${errorData['message'] ?? errorData['error'] ?? 'Unknown error'}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error save kesan pesan: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Koneksi bermasalah. Periksa jaringanmu."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBio = false);
    }
  }

  // ============================================================
  // HELPER: MIME Type
  // ============================================================
  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ============================================================
  // DIALOG EDIT KESAN & PESAN (tidak diubah)
  // ============================================================
  void _showEditBioDialog() {
    _bioController.text = _kesanPesan;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          "Edit Kesan & Pesan",
          style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _bioController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Tulis kesan & pesanmu di sini...",
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _isSavingBio
                ? null
                : () async {
                    Navigator.pop(context);
                    await _saveKesanPesan(_bioController.text);
                  },
            child: _isSavingBio
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text("Simpan",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT (tidak diubah)
  // ============================================================
  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Konfirmasi Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Apakah kamu yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user_name');
              await prefs.remove('user_email');
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Ya, Keluar",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGET AVATAR — DIOPTIMASI
  //
  // Perubahan utama:
  // 1. RepaintBoundary → isolasi repaint, cegah frame drop
  // 2. _localPreviewBytes (MemoryImage) → preview instan setelah pick
  // 3. _avatarKey (UniqueKey) → force rebuild setelah upload
  // 4. Image.network dengan loadingBuilder (skeleton) dan errorBuilder
  // 5. Progress indicator saat upload
  // ============================================================
  Widget _buildProfileAvatar() {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _pickProfileImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.brown[100],
                shape: BoxShape.circle,
              ),
              child: _buildAvatarImage(),
            ),
          ),
          if (_isUploadingPhoto)
            Positioned.fill(child: _buildUploadOverlay())
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.brown[700],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    // Priority 1: preview lokal (instan setelah pick)
    if (_localPreviewBytes != null) {
      return CircleAvatar(
        key: _avatarKey,
        radius: 50,
        backgroundColor: Colors.brown[50],
        backgroundImage: MemoryImage(_localPreviewBytes!),
      );
    }

    // Priority 2: foto dari server
    if (_fotoProfilUrl != null && _fotoProfilUrl!.isNotEmpty) {
      return CircleAvatar(
        key: _avatarKey,
        radius: 50,
        backgroundColor: Colors.brown[50],
        child: ClipOval(
          child: Image.network(
            _fotoProfilUrl!,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            // Skeleton loading saat gambar belum selesai dimuat dari network
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildSkeletonAvatar(
                loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 100,
                height: 100,
                color: Colors.brown[50],
                child: const Icon(Icons.person, size: 50, color: Colors.brown),
              );
            },
          ),
        ),
      );
    }

    // Priority 3: fallback icon
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.brown[50],
      child: const Icon(Icons.person, size: 50, color: Colors.brown),
    );
  }

  Widget _buildSkeletonAvatar(double? progress) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.brown[100],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CircularProgressIndicator(
          value: progress,
          color: Colors.brown[300],
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black45,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: _uploadProgress > 0 && _uploadProgress < 1.0
                  ? _uploadProgress
                  : null,
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          if (_uploadProgress > 0 && _uploadProgress < 1.0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "${(_uploadProgress * 100).toInt()}%",
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD (struktur UI tidak diubah)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Profil Saya",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookingHistoryScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
            color: Colors.brown[700],
            tooltip: "Riwayat Booking",
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            color: Colors.redAccent,
            tooltip: "Keluar",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        child: Column(
          children: [
            // HEADER PROFIL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  _buildProfileAvatar(),
                  const SizedBox(height: 15),
                  Text(_nama,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 5),
                  Text(_email,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // KARTU POIN REWARD
            Consumer<PointProvider>(
              builder: (context, pointProvider, child) {
                final int poinSaatIni = pointProvider.poin;
                final double progress = (poinSaatIni / 200).clamp(0.0, 1.0);
                final bool bisaKlaim = poinSaatIni >= 200;

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.brown[700]!, Colors.brown[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.brown.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Caffio Rewards",
                                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  SizedBox(height: 5),
                                  Text("Poin Saya",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  "$poinSaatIni Poin",
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            bisaKlaim
                                ? "🎉 Yeay! Kamu bisa klaim voucher sekarang."
                                : "Kumpulkan ${(200 - poinSaatIni).clamp(0, 200)} poin lagi untuk Diskon 50%",
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    if (bisaKlaim)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.orange[100], shape: BoxShape.circle),
                            child: const Icon(Icons.card_giftcard, color: Colors.orange),
                          ),
                          title: const Text("Voucher Diskon 50%",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          trailing: ElevatedButton(
                            onPressed: _claimReward,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            child: const Text("Klaim",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // KARTU KESAN & PESAN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Kesan & Pesan",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      GestureDetector(
                        onTap: _showEditBioDialog,
                        child: const Icon(Icons.edit_square, color: Colors.brown, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15)),
                    child: Text(
                      _kesanPesan.isEmpty
                          ? "Belum ada kesan & pesan. Ketuk ikon edit untuk menambahkan."
                          : _kesanPesan,
                      style: TextStyle(
                          fontSize: 14,
                          fontStyle: _kesanPesan.isEmpty ? FontStyle.normal : FontStyle.italic,
                          color: _kesanPesan.isEmpty ? Colors.grey[400] : Colors.grey[700],
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}