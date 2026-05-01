import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/utils/auth_helper.dart';
import '../../core/config/api_config.dart';

class AuthService {
  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await getAuthHeaders();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data['user'];
    } else {
      throw Exception(data['message'] ?? 'Gagal ambil profile');
    }
  }
}