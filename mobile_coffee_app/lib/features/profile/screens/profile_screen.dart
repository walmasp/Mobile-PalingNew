import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // untuk MediaType
import '../../../core/config/api_config.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/point_provider.dart';

import '../../auth/screens/login_screen.dart';

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

  // URL foto dari server (NetworkImage), null berarti belum ada foto
  String? _fotoProfilUrl;

  // Flag loading saat sedang upload foto atau simpan kesan pesan
  bool _isUploadingPhoto = false;
  bool _isSavingBio = false;

  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

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
  // LOAD DATA PROFIL DARI BACKEND (sumber utama: database)
  // SharedPreferences hanya dipakai untuk cache nama & email
  // ============================================================
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Ambil nama & email dari SharedPreferences sebagai cache awal
    // supaya UI tidak kosong saat menunggu API
    if (mounted) {
      setState(() {
        _nama = prefs.getString('user_name') ?? "Guest User";
        _email = prefs.getString('user_email') ?? 'guest@caffio.com';
      });
    }

    // Jika tidak ada token, hentikan (user belum login)
    if (token == null || token.isEmpty) return;

    try {
      // Ambil data profil terbaru dari database via API
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        if (mounted) {
          setState(() {
            _nama = user['nama'] ?? _nama;
            _email = user['email'] ?? _email;
            _kesanPesan = user['kesan_pesan'] ?? "";
            _fotoProfilUrl = user['foto_profil']; // URL dari server
          });

          // Update cache nama & email di SharedPreferences
          await prefs.setString('user_name', _nama);
          await prefs.setString('user_email', _email);
        }
      }
    } catch (e) {
      debugPrint("Gagal load profil dari server: $e");
      // Jika gagal fetch, biarkan tampil data cache dari SharedPreferences
    }

    // Fetch poin terbaru dari database
    final email = prefs.getString('user_email') ?? _email;
    if (email != 'guest@caffio.com' && mounted) {
      await Provider.of<PointProvider>(context, listen: false).fetchPoinFromDB();
    }
  }

  // ============================================================
  // KLAIM REWARD
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
              content:
                  Text("🎉 Voucher Diskon 50% berhasil diklaim! Poin telah digunakan."),
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
  // PICK & UPLOAD FOTO PROFIL KE BACKEND
  // ============================================================
  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

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
        setState(() => _isUploadingPhoto = false);
        return;
      }

      // Kirim foto ke backend menggunakan multipart/form-data
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/update-profile');
      final request = http.MultipartRequest('POST', uri);

      // Tambahkan header Authorization
      request.headers['Authorization'] = 'Bearer $token';

      // Tentukan MIME type secara eksplisit berdasarkan ekstensi file.
      // Ini penting karena Flutter/Android kadang mengirim 'application/octet-stream'
      // yang akan ditolak oleh filter multer di backend.
      final fileExtension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(fileExtension);

      // Tambahkan file foto dengan contentType yang eksplisit
      request.files.add(await http.MultipartFile.fromPath(
        'foto_profil',
        pickedFile.path,
        contentType: MediaType.parse(mimeType),
      ));

      // Tambahkan kesan_pesan yang sudah ada (wajib karena backend butuh field ini)
      request.fields['kesan_pesan'] = _kesanPesan;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newFotoUrl = data['foto_url'];

        if (mounted) {
          setState(() {
            _fotoProfilUrl = newFotoUrl; // Update URL foto dari server
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal mengambil atau mengupload foto."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  // ============================================================
  // SIMPAN KESAN & PESAN KE BACKEND (DATABASE)
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

      // Kirim kesan pesan ke backend
      // Menggunakan multipart supaya konsisten dengan endpoint update-profile
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/update-profile');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['kesan_pesan'] = newBio;
      // Tidak ada file foto — hanya update kesan_pesan saja

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _kesanPesan = newBio;
          });
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
      if (mounted) {
        setState(() => _isSavingBio = false);
      }
    }
  }

  // ============================================================
  // DIALOG EDIT KESAN & PESAN
  // ============================================================
  // Helper: dapatkan MIME type yang benar berdasarkan ekstensi file
  // Ini memastikan backend menerima MIME type yang valid, tidak peduli
  // MIME type apa yang dikirim oleh Android/iOS secara default.
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
        return 'image/jpeg'; // fallback aman untuk semua gambar dari gallery
    }
  }

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
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
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
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text("Simpan",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT
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
            Text("Konfirmasi Logout",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Apakah kamu yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user_name');
              await prefs.remove('user_email');

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Ya, Keluar",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPER: Widget untuk menampilkan foto profil
  // Menggunakan NetworkImage jika ada URL dari server,
  // fallback ke icon jika belum ada foto
  // ============================================================
  Widget _buildProfileAvatar() {
    return Stack(
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
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.brown[50],
              // Tampilkan foto dari URL server jika ada
              backgroundImage: _fotoProfilUrl != null && _fotoProfilUrl!.isNotEmpty
                  ? NetworkImage(_fotoProfilUrl!)
                  : null,
              child: _fotoProfilUrl == null || _fotoProfilUrl!.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.brown)
                  : null,
            ),
          ),
        ),
        // Loading indicator saat upload
        if (_isUploadingPhoto)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black26,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.brown[700],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.camera_alt,
                color: Colors.white, size: 16),
          ),
      ],
    );
  }

  // ============================================================
  // UI
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        child: Column(
          children: [
            // --- BAGIAN HEADER PROFIL ---
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

            // --- KARTU POIN REWARD ---
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
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                  SizedBox(height: 5),
                                  Text("Poin Saya",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  "$poinSaatIni Poin",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            bisaKlaim
                                ? "🎉 Yeay! Kamu bisa klaim voucher sekarang."
                                : "Kumpulkan ${(200 - poinSaatIni).clamp(0, 200)} poin lagi untuk Diskon 50%",
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 5),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.orange[100],
                                shape: BoxShape.circle),
                            child: const Icon(Icons.card_giftcard,
                                color: Colors.orange),
                          ),
                          title: const Text("Voucher Diskon 50%",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          trailing: ElevatedButton(
                            onPressed: _claimReward,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            child: const Text("Klaim",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // --- KARTU KESAN & PESAN ---
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
                        child: const Icon(Icons.edit_square,
                            color: Colors.brown, size: 20),
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
                          fontStyle: _kesanPesan.isEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                          color: _kesanPesan.isEmpty
                              ? Colors.grey[400]
                              : Colors.grey[700],
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // --- TOMBOL LOGOUT ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  side:
                      BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Keluar",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _logout,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}