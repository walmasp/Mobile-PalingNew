import 'package:flutter/material.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../data/services/cafe_service.dart';
import '../../features/menu/screens/menu_screen.dart';
import '../../features/activity/screens/activity_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../features/mini_games/screens/games_menu_screen.dart';
// 🔥 TAMBAHAN IMPORT UNTUK LOKASI (GEOLOCATOR)
import 'package:geolocator/geolocator.dart';

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
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.coffee), label: 'Cafe'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports),
            label: 'Games',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ================= CAFE HOME =================

class CafeHomeScreen extends StatefulWidget {
  const CafeHomeScreen({super.key});

  @override
  State<CafeHomeScreen> createState() => _CafeHomeScreenState();
}

class _CafeHomeScreenState extends State<CafeHomeScreen> {
  List cafes = [];
  bool isLoading = true;

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
        isLoading = false;
      });
    } catch (e) {
      print("Error cafe: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Cafe"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActivityScreen()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cafes.isEmpty
          ? const Center(child: Text("Tidak ada cafe"))
          : ListView.builder(
              itemCount: cafes.length,
              itemBuilder: (context, index) {
                final cafe = cafes[index];
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    leading: const Icon(Icons.local_cafe, color: Colors.brown),
                    title: Text(
                      cafe['nama_cafe'] ?? 'Tanpa Nama',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(cafe['alamat'] ?? ''),
                    onTap: () {
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
                  ),
                );
              },
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

  // 🔥 MENDAPATKAN LOKASI GPS USER
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

  // 🔥 FUNGSI HITUNG JARAK
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

  // 🔥 UI BOTTOM SHEET KETIKA MARKER DITEKAN
  void _showCafeDetails(Map cafe, double lat, double lng) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.brown[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_cafe, color: Colors.brown, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cafe['nama_cafe'] ?? 'Cafe',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _calculateDistance(lat, lng),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                cafe['alamat'] ?? 'Alamat tidak tersedia',
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Tutup bottom sheet
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
                    "Lihat Menu",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan lokasi user sebagai pusat jika ada, jika tidak pakai default
    LatLng mapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Eksplorasi Cafe"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : FlutterMap(
              options: MapOptions(initialCenter: mapCenter, initialZoom: 14.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cafe.agregator',
                ),
                MarkerLayer(
                  markers: [
                    // Marker Lokasi User (Biru)
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),

                    // Marker Daftar Cafe (Cokelat)
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
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }
}
