import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart'; // Sesuaikan path ini dengan letak file api_config.dart kamu
import 'package:provider/provider.dart';
import '../../../core/utils/point_provider.dart';


// 🔥 IMPORT LOGIN SCREEN (Pastikan path ini sesuai dengan folder kamu)
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
  String _kesanPesan = "Memuat...";
  String? _imagePath; 
  int _totalPoints = 0; 

  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker(); 

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // --- LOGIKA UTAMA (DIUBAH AGAR SPESIFIK PER AKUN) ---
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nama = prefs.getString('user_name') ?? "Guest User"; 
      _email = prefs.getString('user_email') ?? "guest@caffio.com"; 
      _kesanPesan = prefs.getString('user_bio_$_email') ?? "Halo! Saya sangat suka kopi dan tempat estetik."; 
      _imagePath = prefs.getString('user_image_$_email'); 
      _totalPoints = prefs.getInt('total_points_$_email') ?? 0; 
    });

    Provider.of<PointProvider>(context, listen: false).updatePoin(_totalPoints);
    // Panggil fungsi API database SETELAH state email didapatkan
    if (_email != "guest@caffio.com") {
      _fetchRealPointsFromDB();
    }
  }


  // Fungsi baru untuk menarik poin asli dari database
  Future<void> _fetchRealPointsFromDB() async {
    try {
      var url = Uri.parse('${ApiConfig.baseUrl}/auth/get-poin');
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _email}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        int realPoints = data['poin'] ?? 0;
        if (mounted) {
          Provider.of<PointProvider>(context, listen: false).updatePoin(realPoints);
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch poin: $e");
    }
  }

  Future<void> _usePoints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_points_$_email', 0); // Reset poin khusus akun ini
    
    // Opsional: Hapus kunci global lama jika ada biar bersih
    await prefs.remove('total_points'); 

    setState(() {
      _totalPoints = 0;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Voucher Diskon berhasil diklaim! Poin telah digunakan."),
        backgroundColor: Colors.brown,
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        // 🔥 PERBAIKAN: Simpan foto berdasarkan email
        await prefs.setString('user_image_$_email', pickedFile.path); 
        setState(() {
          _imagePath = pickedFile.path; 
        });
      }
    } catch (e) {
      print("Gagal mengambil foto: $e");
    }
  }

  Future<void> _saveKesanPesan(String newBio) async {
    final prefs = await SharedPreferences.getInstance();
    // 🔥 PERBAIKAN: Simpan bio berdasarkan email
    await prefs.setString('user_bio_$_email', newBio); 
    setState(() {
      _kesanPesan = newBio; 
    });
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              _saveKesanPesan(_bioController.text);
              Navigator.pop(context);
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
            child: const Text("Batal", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              
              // Hapus token sesi login (Tapi JANGAN hapus bio/foto pakai clear() agar terekam)
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
            child: const Text("Ya, Keluar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- UI BARU (CAFFIO APP STYLE) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold)), 
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(4), 
                          decoration: BoxDecoration(
                            color: Colors.brown[100],
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.brown[50],
                            backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
                            child: _imagePath == null ? const Icon(Icons.person, size: 50, color: Colors.brown) : null,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 15),
                  Text(_nama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)), 
                  const SizedBox(height: 5),
                  Text(_email, style: TextStyle(fontSize: 14, color: Colors.grey[500])), 
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- KARTU POIN REWARD ---
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
                boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
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
                          Text("Caffio Rewards", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          SizedBox(height: 5),
                          Text("Poin Saya", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: 
                        Consumer<PointProvider>(
                        builder: (context, pointProvider, child) {
                          return Text(
                            "${pointProvider.poin} Poin",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          );
                        },
                      ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_totalPoints / 200).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _totalPoints >= 200
                        ? "🎉 Yeay! Kamu bisa klaim voucher sekarang."
                        : "Kumpulkan ${(200 - _totalPoints).clamp(0, 200)} poin lagi untuk Diskon 50%",
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // --- TOMBOL KLAIM HADIAH ---
            if (_totalPoints >= 200)
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
                    decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard, color: Colors.orange),
                  ),
                  title: const Text("Voucher Diskon 50%", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  trailing: ElevatedButton(
                    onPressed: _usePoints,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: const Text("Klaim", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

            // --- KARTU KESAN & PESAN (Bio) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 🔥 SUDAH DIUBAH MENJADI KESAN & PESAN
                      const Text("Kesan & Pesan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
                    child: Text(
                      _kesanPesan,
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[700], height: 1.5),
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
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Keluar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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