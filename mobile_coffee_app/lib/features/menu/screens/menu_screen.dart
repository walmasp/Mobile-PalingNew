import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/menu_service.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final int cafeId;
  final String cafeName;

  const MenuScreen({super.key, required this.cafeId, required this.cafeName});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  List menus = [];
  List filteredMenus = [];
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool isLoading = true;

  Map<String, dynamic> cart = {};

  String selectedCurrency = 'IDR';
  Map<String, double> exchangeRates = {
    'IDR': 1.0,
    'USD': 0.000062,
    'SGD': 0.000084,
    'JPY': 0.0094,
    'KRW': 0.085,
    'EUR': 0.000058,
  };

  int _selectedCategoryIndex = 0;
  final List<String> _categories = ["All", "Kopi", "Teh", "Susu"];

  // ─── Design Tokens ──────────────────────────────────────
  static const _brown900 = Color(0xFF3E2723);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown400 = Color(0xFF8D6E63);
  static const _cream = Color(0xFFFAF7F4);
  static const _inputBorder = Color(0xFFEEE8E4);
  static const _cardBg = Color(0xFFFFFFFF);
  // ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    fetchMenus();
    loadCart();
    fetchExchangeRates();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // --- LOGIKA DATA (TIDAK DIUBAH) ---
  Future<void> fetchExchangeRates() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://latest.currency-api.pages.dev/v1/currencies/idr.json'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idrRates = data['idr'];
        setState(() {
          exchangeRates['USD'] = (idrRates['usd'] as num).toDouble();
          exchangeRates['SGD'] = (idrRates['sgd'] as num).toDouble();
          exchangeRates['JPY'] = (idrRates['jpy'] as num).toDouble();
          exchangeRates['KRW'] = (idrRates['krw'] as num).toDouble();
          exchangeRates['EUR'] = (idrRates['eur'] as num).toDouble();
        });
      }
    } catch (e) {
      print("Gagal ambil kurs real-time: $e");
    }
  }

  String formatPrice(dynamic originalPrice) {
    double price = double.parse(originalPrice.toString());
    if (selectedCurrency == 'IDR') {
      return "Rp ${price.toInt()}";
    } else {
      double converted = price * exchangeRates[selectedCurrency]!;
      int decimalPlaces =
          (selectedCurrency == 'JPY' || selectedCurrency == 'KRW') ? 0 : 2;
      return "$selectedCurrency ${converted.toStringAsFixed(decimalPlaces)}";
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

  Future<void> fetchMenus() async {
    try {
      final data = await MenuService.getMenus(widget.cafeId);
      setState(() {
        menus = data;
        filteredMenus = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void filterMenus(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty || query == "All") {
        filteredMenus = menus;
      } else {
        filteredMenus = menus.where((menu) {
          final namaMenu = menu['nama_menu'].toString().toLowerCase();
          return namaMenu.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void addToCart(Map<String, dynamic> menu) {
    String menuIdStr = menu['id'].toString();
    setState(() {
      if (cart.containsKey(menuIdStr)) {
        cart[menuIdStr]['jumlah'] += 1;
      } else {
        cart[menuIdStr] = {
          'menu_id': menu['id'],
          'nama_menu': menu['nama_menu'],
          'harga': double.parse(menu['harga'].toString()).toInt(),
          'jumlah': 1,
          'catatan': '',
          'foto_url': menu['foto_url'],
        };
      }
    });
    saveCart();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menu['nama_menu']} ditambahkan'),
        duration: const Duration(seconds: 1),
        backgroundColor: _brown700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  int getTotalItem() {
    int total = 0;
    cart.forEach((key, value) {
      total += (value['jumlah'] as int);
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _brown700),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AppBar ─────────────────────────────────
                  _buildAppBar(),

                  // ── Search + Currency ──────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Expanded(child: _buildSearchBar()),
                        const SizedBox(width: 10),
                        _buildCurrencyPicker(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Category Chips ─────────────────────────
                  _buildCategoryChips(),
                  const SizedBox(height: 20),

                  // ── Section Title ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "All Drinks",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _brown900,
                          ),
                        ),
                        Text(
                          "${filteredMenus.length} items",
                          style: const TextStyle(
                            fontSize: 13,
                            color: _brown400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Menu List ──────────────────────────────
                  Expanded(child: _buildMenuList()),
                ],
              ),
      ),

      // ── Floating Cart Button ─────────────────────────────
      floatingActionButton: getTotalItem() > 0
          ? FloatingActionButton.extended(
              backgroundColor: _brown900,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CartScreen(
                      cafeId: widget.cafeId,
                      cafeName: widget.cafeName,
                      currency: selectedCurrency,
                      rate: exchangeRates[selectedCurrency]!,
                    ),
                  ),
                ).then((_) => loadCart());
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              label: Text(
                "${getTotalItem()} item",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _inputBorder, width: 1.5),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: _brown900),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.cafeName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _brown900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  "What would you like today?",
                  style: TextStyle(fontSize: 12, color: _brown400),
                ),
              ],
            ),
          ),
          // Cart icon (top right, secondary)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _inputBorder, width: 1.5),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.shopping_bag_outlined,
                      color: _brown900, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartScreen(
                          cafeId: widget.cafeId,
                          cafeName: widget.cafeName,
                          currency: selectedCurrency,
                          rate: exchangeRates[selectedCurrency]!,
                        ),
                      ),
                    ).then((_) => loadCart());
                  },
                ),
              ),
              if (getTotalItem() > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${getTotalItem()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: searchController,
        onChanged: filterMenus,
        style: const TextStyle(fontSize: 14, color: _brown900),
        decoration: const InputDecoration(
          hintText: "Search menu...",
          hintStyle: TextStyle(color: _brown400, fontSize: 14),
          prefixIcon:
              Icon(Icons.search_rounded, color: _brown400, size: 20),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildCurrencyPicker() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _inputBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCurrency,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _brown700, size: 18),
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: _brown700, fontSize: 13),
          dropdownColor: _cardBg,
          items: exchangeRates.keys.map((String currency) {
            return DropdownMenuItem<String>(
              value: currency,
              child: Text(currency),
            );
          }).toList(),
          onChanged: (String? newValue) =>
              setState(() => selectedCurrency = newValue!),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryIndex = index);
              filterMenus(
                  _categories[index] == "All" ? "" : _categories[index]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _brown900 : _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _brown900 : _inputBorder,
                  width: 1.5,
                ),
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : _brown400,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuList() {
    if (filteredMenus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: _brown400),
            const SizedBox(height: 12),
            const Text(
              "Menu tidak ditemukan",
              style: TextStyle(color: _brown400, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: filteredMenus.length,
      itemBuilder: (context, index) {
        final menu = filteredMenus[index];
        final menuId = menu['id'].toString();
        final cartQty = cart.containsKey(menuId) ? cart[menuId]['jumlah'] : 0;

        return Container(
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
            child: Row(
              children: [
                // ── Menu Image ─────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 82,
                    height: 82,
                    color: const Color(0xFFF3EDE8),
                    child: menu['foto_url'] != null &&
                            menu['foto_url'].toString().isNotEmpty
                        ? Image.network(
                            menu['foto_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.coffee_rounded,
                              color: _brown400,
                              size: 36,
                            ),
                          )
                        : const Icon(
                            Icons.coffee_rounded,
                            color: _brown400,
                            size: 36,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Menu Detail ────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu['nama_menu'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _brown900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Caffio special blend",
                        style: TextStyle(
                            color: _brown400, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatPrice(menu['harga']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _brown700,
                              fontSize: 15,
                            ),
                          ),
                          // ── Add / Qty Controls ─────
                          cartQty == 0
                              ? GestureDetector(
                                  onTap: () => addToCart(menu),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _brown900,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 20),
                                  ),
                                )
                              : Row(
                                  children: [
                                    _qtyButton(
                                      icon: Icons.remove_rounded,
                                      onTap: () {
                                        String id = menu['id'].toString();
                                        setState(() {
                                          if (cart[id]['jumlah'] > 1) {
                                            cart[id]['jumlah'] -= 1;
                                          } else {
                                            cart.remove(id);
                                          }
                                        });
                                        saveCart();
                                      },
                                      filled: false,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Text(
                                        '$cartQty',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _brown900,
                                        ),
                                      ),
                                    ),
                                    _qtyButton(
                                      icon: Icons.add_rounded,
                                      onTap: () => addToCart(menu),
                                      filled: true,
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled ? _brown900 : _cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: filled ? _brown900 : _inputBorder,
            width: 1.5,
          ),
        ),
        child: Icon(icon,
            size: 16,
            color: filled ? Colors.white : _brown900),
      ),
    );
  }
}