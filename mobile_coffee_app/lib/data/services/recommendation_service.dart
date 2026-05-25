import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart'; // Menyesuaikan dengan letak api_config kamu

class RecommendationService {
  // Asumsi di ApiConfig ada variabel baseUrl (contoh: "http://10.0.2.2:3000/api")
  
  static Future<Map<String, dynamic>> fetchRecommendations(String userId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/recommendations/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Gagal memuat rekomendasi');
      }
    } catch (e) {
      throw Exception('Error RecommendationService: $e');
    }
  }
}