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

  // ─── Design Tokens ──────────────────────────────────────
  static const _brown900 = Color(0xFF3E2723);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown400 = Color(0xFF8D6E63);
  static const _cream = Color(0xFFFAF7F4);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _inputBorder = Color(0xFFEEE8E4);
  static const _textHint = Color(0xFFBCAAA4);
  // ────────────────────────────────────────────────────────

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
      int decimalPlaces =
          (widget.currency == 'JPY' || widget.currency == 'KRW') ? 0 : 2;
      return "${widget.currency} ${converted.toStringAsFixed(decimalPlaces)}";
    }
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedCart = prefs.getString('cart_cafe_${widget.cafeId}');
    if (savedCart != null) {
      setState(() => cart = jsonDecode(savedCart));
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
    setState(() => cart.remove(menuIdStr));
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

  int get itemCount {
    int count = 0;
    cart.forEach((_, item) => count += (item['jumlah'] as int));
    return count;
  }

  void goToCheckout() {
    List<Map<String, dynamic>> items = cart.values.map((item) {
      return {
        "menu_id": item['menu_id'],
        "nama_menu": item['nama_menu'],
        "harga": item['harga'],
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

  @override
  Widget build(BuildContext context) {
    List<String> cartKeys = cart.keys.toList();

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'My Cart',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _brown900,
                fontSize: 18,
              ),
            ),
            if (cart.isNotEmpty)
              Text(
                '$itemCount item${itemCount > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: _brown400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: _cream,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _inputBorder, width: 1.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: _brown900),
          ),
        ),
        actions: [
          if (cart.isNotEmpty)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: _cardBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text(
                      "Kosongkan keranjang?",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _brown900),
                    ),
                    content: const Text(
                      "Semua item akan dihapus dari keranjang.",
                      style: TextStyle(color: _brown400, fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal",
                            style: TextStyle(color: _brown400)),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => cart.clear());
                          saveCart();
                          Navigator.pop(context);
                        },
                        child: const Text("Hapus",
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Clear",
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),

      // ── Body ───────────────────────────────────────────────
      body: cart.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: cartKeys.length,
              itemBuilder: (context, index) {
                String key = cartKeys[index];
                var item = cart[key];
                return _buildCartItem(key, item);
              },
            ),

      // ── Bottom Bar ─────────────────────────────────────────
      bottomNavigationBar:
          cart.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDE8),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: _brown400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Keranjang kosong",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _brown900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tambahkan menu favoritmu\nke keranjang",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _brown400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: _brown900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "Lihat Menu",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(String key, dynamic item) {
    return Dismissible(
      key: Key(key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => deleteItem(key),
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade400, size: 26),
            const SizedBox(height: 4),
            Text("Hapus",
                style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _inputBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: _brown900.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Item Row ─────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: const Color(0xFFF3EDE8),
                      child: item['foto_url'] != null &&
                              item['foto_url'].toString().isNotEmpty
                          ? Image.network(
                              item['foto_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.coffee_rounded,
                                color: _brown400,
                                size: 28,
                              ),
                            )
                          : const Icon(
                              Icons.coffee_rounded,
                              color: _brown400,
                              size: 28,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['nama_menu'],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _brown900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPrice(item['harga']),
                          style: const TextStyle(
                            color: _brown700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Delete button
                  GestureDetector(
                    onTap: () => deleteItem(key),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade400,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Note + Qty Row ────────────────────────────
              Row(
                children: [
                  // Note input
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _inputBorder, width: 1.5),
                      ),
                      child: TextField(
                        controller: TextEditingController(
                            text: item['catatan'])
                          ..selection = TextSelection.collapsed(
                              offset:
                                  (item['catatan'] ?? "").length),
                        style: const TextStyle(
                            fontSize: 12, color: _brown900),
                        decoration: const InputDecoration(
                          hintText: 'Catatan (contoh: less ice)',
                          hintStyle:
                              TextStyle(color: _textHint, fontSize: 12),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                              Icons.edit_note_rounded,
                              color: _textHint,
                              size: 16),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (value) => updateNote(key, value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Qty controls
                  _buildQtyControls(key, item['jumlah']),
                ],
              ),

              // ── Subtotal ──────────────────────────────────
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Subtotal",
                    style: TextStyle(color: _brown400, fontSize: 12),
                  ),
                  Text(
                    formatPrice(
                        (item['harga'] as int) * (item['jumlah'] as int)),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _brown900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyControls(String key, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _inputBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyBtn(
            icon: Icons.remove_rounded,
            onTap: () => updateQuantity(key, -1),
            isDark: false,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _brown900,
              ),
            ),
          ),
          _qtyBtn(
            icon: Icons.add_rounded,
            onTap: () => updateQuantity(key, 1),
            isDark: true,
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? _brown900 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 16,
            color: isDark ? Colors.white : _brown400),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: _brown900.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Price breakdown ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$itemCount item${itemCount > 1 ? 's' : ''}",
                    style: const TextStyle(
                        color: _brown400, fontSize: 13)),
                Text(
                  formatPrice(getTotalPrice()),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _brown900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Pesanan",
                    style: TextStyle(
                        color: _brown900,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(
                  "(belum termasuk pajak)",
                  style: TextStyle(color: _brown400, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Checkout Button ─────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brown900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: goToCheckout,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Lanjut ke Checkout",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}