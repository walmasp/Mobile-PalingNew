import 'dart:async';
import 'package:flutter/material.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/api_config.dart'; 

class EspressoExtractorScreen extends StatefulWidget {
  const EspressoExtractorScreen({super.key});

  @override
  State<EspressoExtractorScreen> createState() =>
      _EspressoExtractorScreenState();
}

class _EspressoExtractorScreenState extends State<EspressoExtractorScreen> {
  bool _isPlaying = false;
  bool _isGameOver = false;
  String _status = "Siap mengekstrak!";
  double _coffeeExtracted = 0.0;
  double _heatLevel = 0.0;
  bool _isNear = false;
  StreamSubscription<int>? _proximitySubscription;
  Timer? _gameLoopTimer;

  @override
  void initState() {
    super.initState();
    _initProximitySensor();
  }

  @override
  void dispose() {
    _proximitySubscription?.cancel();
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  Future<void> _savePointsToDatabase(int poinDidapat, String namaGame) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedEmail = prefs.getString('user_email');
      if (savedEmail == null) return;

      var url = Uri.parse('${ApiConfig.baseUrl}/auth/add-points');

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": savedEmail,
          "poin_tambahan": poinDidapat,
          "nama_game": namaGame,
        }),
      );

      if (response.statusCode == 200) {
        print("Poin berhasil disimpan ke database!");
      } else {
        print("Gagal API Poin: ${response.body}");
      }
    } catch (e) {
      print("Error API Poin: $e");
    }
  }

  Future<void> _addPoints() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('user_email');
    
    if (savedEmail != null) {
      // Simpan ke key spesifik akun yang sedang login
      String key = 'total_points_$savedEmail';
      int currentPoints = prefs.getInt(key) ?? prefs.getInt('total_points') ?? 0;
      await prefs.setInt(key, currentPoints + 2);
    } else {
      // Fallback jika email tidak ditemukan
      int currentPoints = prefs.getInt('total_points') ?? 0;
      await prefs.setInt('total_points', currentPoints + 2);
    }

    await _savePointsToDatabase(2, "Espresso Extractor"); 
  }

  void _initProximitySensor() {
    try {
      _proximitySubscription = ProximitySensor.events.listen(
        (int event) {
          if (!mounted) return;
          setState(() {
            _isNear = (event > 0);
          });
        },
        onError: (error) {
          print("Proximity Sensor Error: $error");
          if (mounted) {
            setState(() {
              _status = "Sensor jarak tidak ada di HP ini 😭";
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("Gagal inisiasi sensor proximity: $e");
    }
  }

  void _startGame() {
    setState(() {
      _coffeeExtracted = 0.0;
      _heatLevel = 0.0;
      _isPlaying = true;
      _isGameOver = false;
      _status = "Tutup layar atas dengan jari!";
    });

    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isPlaying) return;

      setState(() {
        if (_isNear) {
          _coffeeExtracted += 0.6;
          _heatLevel += 1.8;
          _status = "Mengekstrak... Tahan!";
          if (_heatLevel >= 80) _status = "AWAS PANAS! Lepas jarimu!";
        } else {
          _heatLevel -= 3.0;
          if (_heatLevel < 0) _heatLevel = 0;
          if (_coffeeExtracted > 0) _status = "Suhu aman. Tutup lagi!";
        }

        if (_heatLevel >= 100) {
          _loseGame("Mesin Overheat! Kopi hangus 🔥");
        } else if (_coffeeExtracted >= 100) {
          _coffeeExtracted = 100;
          _winGame();
        }
      });
    });
  }

  void _loseGame(String reason) {
    _gameLoopTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _status = reason;
    });
  }

  void _winGame() async {
    _gameLoopTimer?.cancel();
    await _addPoints();

    setState(() {
      _isPlaying = false;
      _status = "Espresso Sempurna! +2 Poin ☕";
    });

    _showPrizeDialog();
  }

  void _showPrizeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.all(30),
          title: const Text(
            "✨ LUAR BIASA! ✨",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.brown[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.coffee_rounded,
                  size: 60,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Kamu berhasil mengekstrak Espresso!\n\nKamu mendapatkan +2 Poin Reward. Cek di profilmu!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Klaim Poin",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color heatColor = Colors.green;
    if (_heatLevel > 60) heatColor = Colors.orange;
    if (_heatLevel > 85) heatColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Espresso Extractor",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isGameOver ? Colors.redAccent : Colors.brown[800],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Coffee Extracted",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "${_coffeeExtracted.toInt()}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _coffeeExtracted / 100,
                        minHeight: 12,
                        backgroundColor: Colors.brown[50],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.brown[700]!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Machine Heat",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "${_heatLevel.toInt()}°C",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: heatColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _heatLevel / 100,
                        minHeight: 12,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(heatColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              Transform.translate(
                offset: Offset(
                  (_heatLevel > 80 && _isNear) ? (_heatLevel % 3 - 1.5) * 3 : 0,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _heatLevel > 80 ? Colors.red[50] : Colors.brown[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.coffee_maker_rounded,
                    size: 80,
                    color: _heatLevel > 80
                        ? Colors.redAccent
                        : Colors.brown[700],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              if (!_isPlaying)
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
                    onPressed: _startGame,
                    child: Text(
                      _isGameOver || _coffeeExtracted >= 100
                          ? "Try Again"
                          : "Start Extraction",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
