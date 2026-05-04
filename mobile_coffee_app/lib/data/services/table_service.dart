import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';

class TableService {
  static Future<List<dynamic>> getTables(int cafeId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/tables?cafe_id=$cafeId'),
      );

      if (response.statusCode == 200) {
        // Decode JSON dan ambil array dari dalam key 'data'
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['data'];
      } else {
        throw Exception(
          'Gagal ambil data meja. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error di TableService: $e');
      throw Exception('Terjadi kesalahan jaringan: $e');
    }
  }
}
