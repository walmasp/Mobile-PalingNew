import 'package:shared_preferences/shared_preferences.dart';

// Tetap biarkan fungsi ini di luar class agar booking_service dll tidak error
Future<Map<String, String>> getAuthHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null) {
    throw Exception('Token tidak ditemukan, user belum login');
  }

  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

// Tambahkan class ini untuk keperluan Login, Logout, dan CheckAuth
class AuthHelper {
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<bool> isTokenValid() async {
    final token = await getToken();
    // Jika token ada dan tidak kosong, berarti valid
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}