import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class PointProvider with ChangeNotifier {
  int _poin = 0;

  int get poin => _poin;

  // Update poin secara lokal (in-memory) dan notify semua listener
  void updatePoin(int poinBaru) {
    _poin = poinBaru;
    notifyListeners();
  }

  // Fetch poin terbaru langsung dari database via API
  // Dipanggil saat: profile dibuka, setelah game menang, saat tab profile aktif
  Future<void> fetchPoinFromDB() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      if (email == null || email.isEmpty) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/auth/get-poin');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int realPoin = data['poin'] ?? 0;
        _poin = realPoin;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PointProvider: Gagal fetch poin dari DB: $e');
    }
  }

  // Reset poin di provider (dipanggil setelah claim reward)
  void resetPoin() {
    _poin = 0;
    notifyListeners();
  }
}