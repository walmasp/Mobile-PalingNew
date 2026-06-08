import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import 'package:flutter/material.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../data/services/cafe_service.dart';
import '../../features/menu/screens/menu_screen.dart';
import '../../features/activity/screens/activity_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../features/mini_games/screens/games_menu_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../features/ai/screens/ai_barista_screen.dart';
import 'package:provider/provider.dart';
import '../../core/utils/point_provider.dart';

// ─── Design Tokens (shared) ──────────────────────────────
const _brown900 = Color(0xFF3E2723);
const _brown700 = Color(0xFF5D4037);
const _brown400 = Color(0xFF8D6E63);
const _cream = Color(0xFFFAF7F4);
const _cardBg = Color(0xFFFFFFFF);
const _inputBorder = Color(0xFFEEE8E4);
// ────────────────────────────────────────────────────────

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

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 3) {
      Provider.of<PointProvider>(context, listen: false).fetchPoinFromDB();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),

      floatingActionButton: FloatingActionButton(
        heroTag: 'ai_chatbot_btn',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AiBaristaScreen()),
          );
        },
        backgroundColor: _brown900,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.smart_toy_rounded, size: 26),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: _cardBg,
        elevation: 16,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0),
              _buildNavItem(
                  icon: Icons.map_rounded,
                  label: 'Maps',
                  index: 1),
              const SizedBox(width: 48),
              _buildNavItem(
                  icon: Icons.sports_esports_rounded,
                  label: 'Games',
                  index: 2),
              _buildNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon,
      required String label,
      required int index}) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? _brown900 : _brown400,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _brown900 : _brown400,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CAFE HOME SCREEN
// ─────────────────────────────────────────────────────────

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

  String _userName = "Coffee Lover";

  @override
  void initState() {
    super.initState();
    fetchCafes();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await _getPrefs();
      final name = prefs['user_name'] ?? "Coffee Lover";
      if (mounted) setState(() => _userName = name);
    } catch (_) {}
  }

  // Simple helper to avoid direct SharedPreferences import here
  Future<Map<String, String?>> _getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return {'user_name': prefs.getString('user_name')};
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
      setState(() => isLoading = false);
    }
  }

  void filterSearch(String query) {
    setState(() {
      _isSeeAll = true;
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return "Good Morning";
    if (hour < 15) return "Good Afternoon";
    if (hour < 19) return "Good Evening";
    return "Good Night";
  }

  @override
  Widget build(BuildContext context) {
    List displayedCafes =
        _isSeeAll ? filteredCafes : filteredCafes.take(3).toList();

    const String currentUserId = "9";

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _brown400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _brown900,
                          ),
                        ),
                      ],
                    ),
                    // Notification + Profile
                    Row(
                      children: [
                        _iconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ActivityScreen()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _brown900,
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Search Bar ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _inputBorder, width: 1.5),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: filterSearch,
                    style: const TextStyle(
                        fontSize: 14, color: _brown900),
                    decoration: const InputDecoration(
                      hintText: "Search cafe or location...",
                      hintStyle: TextStyle(
                          color: _brown400, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: _brown400, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 15),
                    ),
                  ),
                ),
              ),
            ),

            // ── AI Recommendation Section ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: RecommendationSection(
                    userId: currentUserId),
              ),
            ),

            // ── Section Header ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Cafes Near You",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _brown900,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _isSeeAll = !_isSeeAll),
                      child: Text(
                        _isSeeAll ? "Show Less" : "See All",
                        style: const TextStyle(
                          color: _brown700,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Cafe List ─────────────────────────────────
            isLoading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: _brown700),
                      ),
                    ),
                  )
                : displayedCafes.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              "Kafe tidak ditemukan.",
                              style: TextStyle(color: _brown400),
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildCafeCard(
                                    context,
                                    displayedCafes[index]),
                            childCount: displayedCafes.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _inputBorder, width: 1.5),
        ),
        child: Icon(icon, color: _brown900, size: 20),
      ),
    );
  }

  Widget _buildCafeCard(BuildContext context, Map cafe) {
    String rating =
        cafe['rating'] != null ? cafe['rating'].toString() : "4.5";
    String? fotoUrl = cafe['foto_url'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuScreen(
            cafeId: cafe['id'],
            cafeName: cafe['nama_cafe'] ?? 'Cafe',
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
              // ── Cafe Image ──────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 88,
                  height: 88,
                  color: const Color(0xFFF3EDE8),
                  child: fotoUrl != null && fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(
                            Icons.storefront_rounded,
                            size: 36,
                            color: _brown400,
                          ),
                        )
                      : const Icon(
                          Icons.storefront_rounded,
                          size: 36,
                          color: _brown400,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // ── Cafe Details ────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            cafe['nama_cafe'] ?? 'Tanpa Nama',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _brown900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFA726),
                                size: 15),
                            const SizedBox(width: 3),
                            Text(
                              rating,
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
                    const SizedBox(height: 6),
                    Text(
                      cafe['alamat'] ?? 'Alamat tidak tersedia',
                      style: const TextStyle(
                          color: _brown400, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "Open",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_rounded,
                            color: _brown400, size: 13),
                        const SizedBox(width: 3),
                        const Text(
                          "Nearby",
                          style: TextStyle(
                            color: _brown400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: _brown400),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// CAFE MAPS SCREEN (UI TIDAK DIUBAH, HANYA WARNA SYNC)
// ─────────────────────────────────────────────────────────

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
    setState(() => _currentPosition = position);
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
      setState(() => isLoading = false);
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
      return "${meter.toInt()} Meter";
    } else {
      return "${(meter / 1000).toStringAsFixed(1)} KM";
    }
  }

  void _showCafeDetails(Map cafe, double lat, double lng) {
    String rating =
        cafe['rating'] != null ? cafe['rating'].toString() : "4.5";
    String? fotoUrl = cafe['foto_url'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _cardBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _inputBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFFF3EDE8),
                      child: fotoUrl != null && fotoUrl.isNotEmpty
                          ? Image.network(fotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(
                                    Icons.storefront_rounded,
                                    color: _brown400,
                                  ))
                          : const Icon(Icons.storefront_rounded,
                              color: _brown400),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cafe['nama_cafe'] ?? 'Cafe',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _brown900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFA726), size: 15),
                            const SizedBox(width: 4),
                            Text(rating,
                                style: const TextStyle(
                                    color: _brown400,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _inputBorder, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cafe['alamat'] ??
                                'Alamat tidak tersedia',
                            style: const TextStyle(
                                color: _brown900,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                          height: 1,
                          color: _inputBorder,
                          thickness: 1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded,
                            color: _brown700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _calculateDistance(lat, lng),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _brown700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    LatLng mapCenter = _currentPosition != null
        ? LatLng(
            _currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultCenter;

    return Scaffold(
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _brown700))
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
                                color:
                                    Colors.blue.withOpacity(0.2),
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
                              ? double.parse(
                                  cafe['latitude'].toString())
                              : _defaultCenter.latitude;
                          double lng = cafe['longitude'] != null
                              ? double.parse(
                                  cafe['longitude'].toString())
                              : _defaultCenter.longitude;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () =>
                                  _showCafeDetails(cafe, lat, lng),
                              child: const Icon(
                                Icons.location_pin,
                                color: _brown700,
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
                    backgroundColor: _cardBg,
                    foregroundColor: _brown700,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    onPressed: _getCurrentLocation,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// RECOMMENDATION SECTION (REDESIGNED)
// ─────────────────────────────────────────────────────────

class RecommendationSection extends StatefulWidget {
  final String userId;
  const RecommendationSection({super.key, required this.userId});

  @override
  State<RecommendationSection> createState() =>
      _RecommendationSectionState();
}

class _RecommendationSectionState
    extends State<RecommendationSection> {
  String sectionTitle = "Memuat rekomendasi...";
  List recommendedMenus = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      String baseUrl = "http://10.0.2.2:3000/api";
      try {
        baseUrl = ApiConfig.baseUrl;
      } catch (e) {}

      final url =
          Uri.parse('$baseUrl/recommendations/${widget.userId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            sectionTitle = data['title'];
            recommendedMenus = data['data'];
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error Recommendation UI: $e");
      setState(() {
        sectionTitle = "Rekomendasi untuk kamu";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: CircularProgressIndicator(color: _brown700),
        ),
      );
    }

    if (recommendedMenus.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sectionTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _brown900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: _brown400),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 188,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendedMenus.length,
            itemBuilder: (context, index) {
              final menu = recommendedMenus[index];
              return GestureDetector(
                onTap: () {
                  if (menu['cafe_id'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuScreen(
                          cafeId: menu['cafe_id'],
                          cafeName:
                              menu['nama_cafe'] ?? 'Cafe',
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _inputBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _brown900.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            height: 90,
                            color:
                                const Color(0xFFF3EDE8),
                            child: menu['foto_url'] != null &&
                                    menu['foto_url']
                                        .toString()
                                        .isNotEmpty
                                ? Image.network(
                                    menu['foto_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            const Icon(
                                      Icons.coffee_rounded,
                                      color: _brown400,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.coffee_rounded,
                                    color: _brown400,
                                    size: 32,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          menu['nama_menu'] ?? 'Menu',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _brown900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          menu['nama_cafe'] ?? '',
                          style: const TextStyle(
                            color: _brown400,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          "Rp ${menu['harga'].toString().replaceAll('.00', '')}",
                          style: const TextStyle(
                            color: _brown700,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}