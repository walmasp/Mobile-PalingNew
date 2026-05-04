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

class _MenuScreenState extends State<MenuScreen> {
  List menus = [];
  List filteredMenus = [];
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool isLoading = true;

  Map<String, dynamic> cart = {};

  // VARIABEL MATA UANG UNIVERSAL 
  String selectedCurrency = 'IDR';
  Map<String, double> exchangeRates = {
    'IDR': 1.0,
    'USD': 0.000062,
    'SGD': 0.000084,
    'JPY': 0.0094,
    'KRW': 0.085,
    'EUR': 0.000058,
  };

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

  // LOGIKA DATA 
  Future<void> fetchExchangeRates() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://latest.currency-api.pages.dev/v1/currencies/idr.json',
        ),
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

    // Tampilkan notifikasi kecil saat ditambah ke keranjang
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menu['nama_menu']} ditambahkan ke keranjang'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.brown,
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
      backgroundColor: Colors.grey[50], 
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.brown),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER 
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.cafeName,
                              style: const TextStyle(
                                color: Colors.brown,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Text(
                              "What coffee would you like?",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Tombol Keranjang (Cart)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.black87,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CartScreen(
                                            cafeId: widget.cafeId,
                                            cafeName: widget.cafeName,
                                            currency: selectedCurrency,
                                            rate:
                                                exchangeRates[selectedCurrency]!,
                                          ),
                                        ),
                                      ).then((_) => loadCart());
                                    },
                                  ),
                                ),
                                if (getTotalItem() > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
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
                              ],
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // SEARCH & CURRENCY ROW 
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (value) => filterMenus(value),
                            decoration: InputDecoration(
                              hintText: "Search menu...",
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.brown,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Colors.brown,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Dropdown Currency 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCurrency,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.brown,
                              ),
                              items: exchangeRates.keys.map((String currency) {
                                return DropdownMenuItem<String>(
                                  value: currency,
                                  child: Text(
                                    currency,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) =>
                                  setState(() => selectedCurrency = newValue!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        bool isSelected = _selectedCategoryIndex == index;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCategoryIndex = index);
                            filterMenus(
                              _categories[index] == "All"
                                  ? ""
                                  : _categories[index],
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.brown[600]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? null
                                  : Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _categories[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LIST MENU 
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Text(
                      "Popular Drinks",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: filteredMenus.isEmpty
                        ? const Center(
                            child: Text(
                              "Menu tidak ditemukan 😕",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredMenus.length,
                            itemBuilder: (context, index) {
                              final menu = filteredMenus[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.brown[50],
                                      child: menu['foto_url'] != null && menu['foto_url'].toString().isNotEmpty
                                          ? Image.network(
                                              menu['foto_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Icon(Icons.broken_image, color: Colors.brown, size: 40);
                                              },
                                            )
                                          : const Icon(
                                              Icons.coffee,
                                              color: Colors.brown,
                                              size: 40,
                                            ),
                                    ),
                                  ),
                                    const SizedBox(width: 15),
                                    // Detail Menu
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            menu['nama_menu'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            "Caffio special blend",
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                formatPrice(menu['harga']),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.brown,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => addToCart(menu),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.brown[600],
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.add,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
