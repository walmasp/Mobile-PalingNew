import 'package:flutter/material.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../data/services/cafe_service.dart';
import '../../features/menu/screens/menu_screen.dart';
import '../../features/activity/screens/activity_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../features/mini_games/screens/games_menu_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../features/ai/screens/ai_barista_screen.dart'; // Sesuaikan folder kamu

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const CafeHomeScreen(),
    const CafeMapsScreen(),
    const GamesMenuScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Agar body (seperti Maps) tidak terpotong background putih navbar
      body: IndexedStack(index: _currentIndex, children: _pages),
      
      // 🔥 1. TOMBOL AI CHATBOT (MENONJOL DI TENGAH)
      floatingActionButton: FloatingActionButton(

       heroTag: 'ai_chatbot_btn', // Tambahkan heroTag untuk menghindari error jika ada FAB lain
        onPressed: () {
          // Membuka KopiBot AI 🤖☕
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AiBaristaScreen(),
            ),
          );
        },
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.smart_toy_rounded, size: 28),
      ),
      
      // 🔥 2. POSISI TOMBOL DI TENGAH NAVBAR
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 🔥 3. NAVBAR DENGAN LENGKUNGAN (NOTCH)
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 20,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              // SISI KIRI
              _buildNavItem(icon: Icons.home_filled, label: 'Home', index: 0),
              _buildNavItem(icon: Icons.map_rounded, label: 'Maps', index: 1),
              
              // SPASI KOSONG DI TENGAH (Untuk tempat tombol mengambang)
              const SizedBox(width: 48),

              // SISI KANAN
              _buildNavItem(icon: Icons.sports_esports_rounded, label: 'Games', index: 2),
              _buildNavItem(icon: Icons.person, label: 'Profile', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 WIDGET CUSTOM UNTUK ITEM NAVBAR
  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.brown[700] : Colors.grey[400],
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.brown[700] : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= CAFE HOME (AGREGATOR) =================

class CafeHomeScreen extends StatefulWidget {
  const CafeHomeScreen({super.key});

  @override
  State<CafeHomeScreen> createState() => _CafeHomeScreenState();
}

class _CafeHomeScreenState extends State<CafeHomeScreen> {
  List cafes = [];
  List filteredCafes = [];
  bool isLoading = true;

  TextEditingController searchController = TextEditingController();
  bool _isSeeAll = false;

  @override
  void initState() {
    super.initState();
    fetchCafes();
  }

  Future<void> fetchCafes() async {
    try {
      final data = await CafeService.getCafes();
      setState(() {
        cafes = data;
        filteredCafes = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error cafe: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // 🔥 FUNGSI PENCARIAN YANG SUDAH DIPERBAIKI
  void filterSearch(String query) {
    setState(() {
      _isSeeAll = true; // Langsung tampilkan semua jika sedang mencari
      if (query.isEmpty) {
        filteredCafes = cafes;
      } else {
        filteredCafes = cafes.where((cafe) {
          final nama = cafe['nama_cafe']?.toString().toLowerCase() ?? '';
          final alamat = cafe['alamat']?.toString().toLowerCase() ?? '';
          return nama.contains(query.toLowerCase()) ||
              alamat.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Menentukan jumlah cafe yang tampil
    List displayedCafes = _isSeeAll
        ? filteredCafes
        : filteredCafes.take(3).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Explore Cafes",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.brown,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActivityScreen()),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Good Morning,",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            const Text(
              "Find your favorite coffee\nshop near you ☕",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 25),

            // 🔥 SEARCH BAR AKTIF
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                onChanged: filterSearch, // Tersambung ke fungsi search
                decoration: const InputDecoration(
                  hintText: "Search cafe or location...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.brown),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 🔥 HEADER KATEGORI & SEE ALL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recommended For You",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _isSeeAll = !_isSeeAll),
                  child: Text(
                    _isSeeAll ? "Show Less" : "See All",
                    style: const TextStyle(
                      color: Colors.brown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),


            // 🔥 LIST CAFE SESUAI DATABASE
            isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Colors.brown),
                    ),
                  )
                : displayedCafes.isEmpty
                ? const Center(
                    child: Text(
                      "Kafe tidak ditemukan.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedCafes.length,
                    itemBuilder: (context, index) {
                      final cafe = displayedCafes[index];
                      return _buildCafeCard(context, cafe);
                    },
                  ),
          ],
        ),
      ),
    );
  }


  Widget _buildCafeCard(BuildContext context, Map cafe) {
    // 🔥 MENGAMBIL RATING DAN FOTO DARI DATABASE
    String rating = cafe['rating'] != null ? cafe['rating'].toString() : "4.5";
    String? fotoUrl = cafe['foto_url'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MenuScreen(
              cafeId: cafe['id'],
              cafeName: cafe['nama_cafe'] ?? 'Cafe',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 90,
                height: 90,
                color: Colors.brown[50],
                // 🔥 MENAMPILKAN FOTO JIKA ADA, IKA TIDAK TAMPILKAN ICON
                child: fotoUrl != null && fotoUrl.isNotEmpty
                    ? Image.network(
                        fotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.storefront_rounded,
                              size: 40,
                              color: Colors.brown,
                            ),
                      )
                    : const Icon(
                        Icons.storefront_rounded,
                        size: 40,
                        color: Colors.brown,
                      ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cafe['nama_cafe'] ?? 'Tanpa Nama',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          // 🔥 MENAMPILKAN RATING DINAMIS
                          Text(
                            rating,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cafe['alamat'] ?? 'Alamat tidak tersedia',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.brown,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Nearby",
                        style: TextStyle(
                          color: Colors.brown,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Open",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

// ================= MAPS (LBS) =================

class CafeMapsScreen extends StatefulWidget {
  const CafeMapsScreen({super.key});

  @override
  State<CafeMapsScreen> createState() => _CafeMapsScreenState();
}

class _CafeMapsScreenState extends State<CafeMapsScreen> {
  List cafes = [];
  bool isLoading = true;
  Position? _currentPosition;
  final LatLng _defaultCenter = const LatLng(-7.795580, 110.369490);

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  Future<void> _initMapData() async {
    await _getCurrentLocation();
    await fetchCafes();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> fetchCafes() async {
    try {
      final data = await CafeService.getCafes();
      setState(() {
        cafes = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error maps: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _calculateDistance(double cafeLat, double cafeLng) {
    if (_currentPosition == null) return "Jarak tidak diketahui";

    final Distance distance = const Distance();
    final double meter = distance(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(cafeLat, cafeLng),
    );

    if (meter < 1000) {
      return "${meter.toInt()} Meter dari lokasimu";
    } else {
      return "${(meter / 1000).toStringAsFixed(1)} KM dari lokasimu";
    }
  }

  void _showCafeDetails(Map cafe, double lat, double lng) {
    String rating = cafe['rating'] != null ? cafe['rating'].toString() : "4.5";
    String? fotoUrl = cafe['foto_url'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.brown[50],
                      child: fotoUrl != null && fotoUrl.isNotEmpty
                          ? Image.network(
                              fotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.storefront_rounded,
                                    size: 30,
                                    color: Colors.brown,
                                  ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              size: 30,
                              color: Colors.brown,
                            ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cafe['nama_cafe'] ?? 'Cafe',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cafe['alamat'] ?? 'Alamat tidak tersedia',
                            style: TextStyle(
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_walk_rounded,
                          color: Colors.brown,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _calculateDistance(lat, lng),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuScreen(
                          cafeId: cafe['id'],
                          cafeName: cafe['nama_cafe'],
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Lihat Menu & Booking",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    LatLng mapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cafe.agregator',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blueAccent,
                                size: 25,
                              ),
                            ),
                          ),
                        ...cafes.map((cafe) {
                          double lat = cafe['latitude'] != null
                              ? double.parse(cafe['latitude'].toString())
                              : _defaultCenter.latitude;
                          double lng = cafe['longitude'] != null
                              ? double.parse(cafe['longitude'].toString())
                              : _defaultCenter.longitude;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () => _showCafeDetails(cafe, lat, lng),
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.brown,
                                size: 45,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
                
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.brown[700],
                    elevation: 4,
                    onPressed: _getCurrentLocation,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
    );
  }
}