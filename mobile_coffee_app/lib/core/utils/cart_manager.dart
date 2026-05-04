import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CartManager {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  // List untuk menyimpan menu di keranjang
  List<Map<String, dynamic>> cartItems = [];

  // 1. Fungsi memuat keranjang dari memori HP (dipanggil saat aplikasi baru dibuka)
  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    String? cartData = prefs.getString('saved_cart');
    if (cartData != null) {
      List<dynamic> decoded = jsonDecode(cartData);
      cartItems = decoded.cast<Map<String, dynamic>>();
    }
  }

  // 2. Fungsi menyimpan keranjang ke memori HP
  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_cart', jsonEncode(cartItems));
  }

  // 3. Fungsi Tambah ke Keranjang
  void addToCart(Map<String, dynamic> menu) {
    int index = cartItems.indexWhere((item) => item['menu_id'] == menu['id']);

    if (index != -1) {
      cartItems[index]['jumlah'] += 1;
    } else {
      cartItems.add({
        'menu_id': menu['id'],
        'nama_menu': menu['nama_menu'],
        'harga': double.parse(menu['harga'].toString()).toInt(),
        'jumlah': 1,
      });
    }
    _saveCart(); // Simpan otomatis setiap ada penambahan
  }

  // 4. Fungsi Hitung Total Harga Keranjang
  int getTotalPrice() {
    return cartItems.fold(
      0,
      (sum, item) => sum + (item['harga'] as int) * (item['jumlah'] as int),
    );
  }

  // 5. Fungsi Kosongkan Keranjang (dipanggil setelah berhasil checkout)
  Future<void> clearCart() async {
    cartItems.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_cart');
  }
}
