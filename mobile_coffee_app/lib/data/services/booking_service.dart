import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';
import '../../core/utils/auth_helper.dart';

class BookingService {
  static Future<Map<String, dynamic>> createBooking({
    required int cafeId,
    required int tableId,
    required int jumlahOrang, // Parameter baru yang sebelumnya kurang
    required List<Map<String, dynamic>> items,
    required String tanggal,
    required String jamMulai,
    required String jamSelesai,
    required String jenisPembayaran,
  }) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/bookings'),
        headers: headers,
        body: jsonEncode({
          "cafe_id": cafeId,
          "table_id": tableId,
          "jumlah_orang": jumlahOrang, // Dikirim ke Node.js
          "tanggal_booking": tanggal,
          "jam_mulai": jamMulai,
          "jam_selesai": jamSelesai,
          "jenis_pembayaran": jenisPembayaran,
          "items": items,
        }),
      );

      if (response.body.startsWith('<!DOCTYPE html>')) {
        throw Exception('Terjadi kesalahan pada server.');
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Booking gagal');
      }
    } catch (e) {
      throw Exception('Gagal menghubungi server: $e');
    }
  }

  static Future<String> checkStatus(int bookingId) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/bookings/status/$bookingId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['status'];
      }
      return 'menunggu_pembayaran';
    } catch (e) {
      return 'menunggu_pembayaran';
    }
  }
}