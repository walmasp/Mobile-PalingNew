import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/api_config.dart';

class NotificationService {
  // Fungsi untuk mengirim data notifikasi ke database via Backend
  static Future<void> createNotification(String judul, String pesan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/bookings/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"judul": judul, "pesan": pesan}),
      );

      if (response.statusCode == 201) {
        print("Notifikasi berhasil dibuat di database");
      } else {
        print("Gagal buat notifikasi: ${response.body}");
      }
    } catch (e) {
      print("Error NotificationService: $e");
    }
  }
}
