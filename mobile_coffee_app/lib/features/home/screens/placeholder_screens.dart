import 'package:flutter/material.dart';

// --- HALAMAN 1: DAFTAR CAFE (AGREGATOR) ---
class CafeHomeScreen extends StatelessWidget {
  const CafeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Background terang elegan
      appBar: AppBar(
        title: const Text("Explore Cafes", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER GREETING ---
            const Text("Good Morning,", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 5),
            const Text(
              "Find your favorite coffee\nshop near you ☕",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 25),

            // --- SEARCH BAR ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search cafe or location...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.brown),
                  suffixIcon: Icon(Icons.tune, color: Colors.brown),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- BAGIAN KATEGORI (Horizontal) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Popular Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: (){}, child: const Text("See All", style: TextStyle(color: Colors.brown))),
              ],
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip("Nearby", true),
                  _buildCategoryChip("Top Rated", false),
                  _buildCategoryChip("Aesthetic", false),
                  _buildCategoryChip("Work Space", false),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- DAFTAR CAFE (Vertical List) ---
            const Text("Recommended For You", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            // Dummy List Cafe
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3, // Tampilkan 3 contoh cafe
              itemBuilder: (context, index) {
                return _buildCafeCard();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget Bantuan untuk Chip Kategori
  Widget _buildCategoryChip(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.brown[700] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? null : Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget Bantuan untuk Card Cafe
  Widget _buildCafeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          // Placeholder Gambar Cafe
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 90,
              height: 90,
              color: Colors.brown[50],
              child: const Icon(Icons.storefront_rounded, size: 40, color: Colors.brown),
            ),
          ),
          const SizedBox(width: 15),
          
          // Informasi Cafe
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text("Caffio Signature", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text("4.8", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Jl. Sudirman No. 45, Sleman", style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.brown, size: 14),
                    const SizedBox(width: 4),
                    const Text("1.2 km", style: TextStyle(color: Colors.brown, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                      child: const Text("Open", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- HALAMAN 2: MAPS (LBS) ---
class CafeMapsScreen extends StatelessWidget {
  const CafeMapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Warna dasar pura-pura jadi peta
      body: Stack(
        children: [
          // 1. PLACEHOLDER MAPS (Nanti diganti widget GoogleMap)
          Positioned.fill(
            child: Container(
              color: Colors.brown[50], // Tema peta bernuansa warm
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 100, color: Colors.brown[200]),
                    const SizedBox(height: 10),
                    Text("Google Maps Widget Akan Tampil Di Sini", style: TextStyle(color: Colors.brown[400], fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          // 2. TOMBOL BACK & SEARCH BAR MELAYANG DI ATAS PETA
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Tombol Back/Menu
                  Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                    child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 15),
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: "Cari kafe di sekitar...",
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.brown),
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. CARD CAFE TERDEKAT MELAYANG DI BAWAH PETA
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Tombol "Lokasi Saya"
                Padding(
                  padding: const EdgeInsets.only(right: 20, bottom: 20),
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.brown,
                    mini: true,
                    onPressed: () {},
                    child: const Icon(Icons.my_location),
                  ),
                ),
                
                // Horizontal List Card Cafe
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]),
                        child: Row(
                          children: [
                            // Gambar Cafe Pura-pura
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Container(width: 80, height: double.infinity, color: Colors.brown[100], child: const Icon(Icons.coffee, color: Colors.brown)),
                            ),
                            const SizedBox(width: 15),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Caffio Central", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Text("Buka hingga 23:00", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.brown),
                                          SizedBox(width: 4),
                                          Text("800m", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(color: Colors.brown[700], borderRadius: BorderRadius.circular(10)),
                                        child: const Text("Detail", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}