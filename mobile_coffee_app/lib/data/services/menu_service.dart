import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';

class MenuService {
  static Future<List<dynamic>> getMenus(int cafeId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/menus?cafe_id=$cafeId'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Gagal ambil menu');
    }
  }
}