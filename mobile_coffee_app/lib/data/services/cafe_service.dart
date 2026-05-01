import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';

class CafeService {
  static Future<List<dynamic>> getCafes() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/cafes'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Gagal ambil data cafe');
    }
  }
}