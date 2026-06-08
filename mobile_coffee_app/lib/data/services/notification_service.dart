import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/api_config.dart';

class NotificationService {
  // Fungsi untuk mengirim data notifikasi ke database via Backend
  // bookingId bersifat opsional — hanya diisi jika notifikasi terkait booking
  static Future<void> createNotification(
    String judul,
    String pesan, {
    int? bookingId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final body = <String, dynamic>{
        "judul": judul,
        "pesan": pesan,
      };

      // Sertakan booking_id hanya jika ada
      if (bookingId != null) {
        body["booking_id"] = bookingId;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/bookings/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
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