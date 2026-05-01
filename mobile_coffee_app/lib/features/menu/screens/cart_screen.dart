import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../booking/screens/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final int cafeId;
  final String cafeName;
  final String currency;
  final double rate;

  const CartScreen({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.currency = 'IDR',
    this.rate = 1.0,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, dynamic> cart = {};

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  // --- LOGIKA DATA (TIDAK DIUBAH) ---
  String formatPrice(dynamic originalPrice) {
    double price = double.parse(originalPrice.toString());
    if (widget.currency == 'IDR') {
      return "Rp ${price.toInt()}";
    } else {
      double converted = price * widget.rate;
      int decimalPlaces = (widget.currency == 'JPY' || widget.currency == 'KRW')
          ? 0
          : 2;
      return "${widget.currency} ${converted.toStringAsFixed(decimalPlaces)}";
    }
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedCart = prefs.getString('cart_cafe_${widget.cafeId}');
    if (savedCart != null) {
      setState(() {
        cart = jsonDecode(savedCart);
      });
    }
  }

  Future<void> saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart_cafe_${widget.cafeId}', jsonEncode(cart));
  }

  void updateQuantity(String menuIdStr, int change) {
    setState(() {
      cart[menuIdStr]['jumlah'] += change;
      if (cart[menuIdStr]['jumlah'] <= 0) {
        cart.remove(menuIdStr);
      }
    });
    saveCart();
  }

  void deleteItem(String menuIdStr) {
    setState(() {
      cart.remove(menuIdStr);
    });
    saveCart();
  }

  void updateNote(String menuIdStr, String note) {
    cart[menuIdStr]['catatan'] = note;
    saveCart();
  }

  int getTotalPrice() {
    int total = 0;
    cart.forEach((key, item) {
      total += (item['harga'] as int) * (item['jumlah'] as int);
    });
    return total;
  }

  void goToCheckout() {
    List<Map<String, dynamic>> items = cart.values.map((item) {
      return {
        "menu_id": item['menu_id'],
        "jumlah": item['jumlah'],
        "catatan": item['catatan'],
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cafeId: widget.cafeId,
          items: items,
          currency: widget.currency,
          rate: widget.rate,
        ),
      ),
    );
  }

  // --- UI BARU (CAFFIO APP STYLE) ---
  @override
  Widget build(BuildContext context) {
    List<String> cartKeys = cart.keys.toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Keranjang kamu masih kosong",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: cartKeys.length,
              itemBuilder: (context, index) {
                String key = cartKeys[index];
                var item = cart[key];

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Placeholder Gambar Kecil
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.brown[50],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.coffee,
                              color: Colors.brown,
                            ),
                          ),
                          const SizedBox(width: 15),

                          // Info Produk
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nama_menu'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  formatPrice(item['harga']),
                                  style: TextStyle(
                                    color: Colors.brown[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Tombol Delete
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => deleteItem(key),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Row Input Catatan & Quantity Control
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                                  TextEditingController(text: item['catatan'])
                                    ..selection = TextSelection.collapsed(
                                      offset: (item['catatan'] ?? "").length,
                                    ),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Notes (e.g. less ice)',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (value) => updateNote(key, value),
                            ),
                          ),
                          const SizedBox(width: 15),

                          // Custom Quantity Box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () => updateQuantity(key, -1),
                                  constraints: const BoxConstraints(
                                    minWidth: 35,
                                    minHeight: 35,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                Text(
                                  '${item['jumlah']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => updateQuantity(key, 1),
                                  constraints: const BoxConstraints(
                                    minWidth: 35,
                                    minHeight: 35,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

      // --- BOTTOM BAR ---
      bottomNavigationBar: cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Price",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatPrice(getTotalPrice()),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        onPressed: goToCheckout,
                        child: const Text(
                          'Checkout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
