import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaristaBalanceScreen extends StatefulWidget {
  const BaristaBalanceScreen({super.key});

  @override
  State<BaristaBalanceScreen> createState() => _BaristaBalanceScreenState();
}

class _BaristaBalanceScreenState extends State<BaristaBalanceScreen> {
  int _timeLeft = 30;
  Timer? _timer;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _x = 0.0;
  double _y = 0.0;
  final double _threshold = 4.5;

  Light? _light;
  StreamSubscription<int>? _lightSubscription;
  int _luxValue = 0;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initLightSensor();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    _lightSubscription?.cancel();
    super.dispose();
  }

  // --- LOGIKA UTAMA (TIDAK DIUBAH) ---
  Future<void> _addPoints() async {
    final prefs = await SharedPreferences.getInstance();
    int currentPoints = prefs.getInt('total_points') ?? 0;
    await prefs.setInt('total_points', currentPoints + 2);
  }

  void _initLightSensor() {
    _light = Light();
    try {
      _lightSubscription = _light?.lightSensorStream.listen(
        (int luxValue) {
          if (!mounted) return;
          setState(() {
            _luxValue = luxValue;
            _isDarkMode = luxValue < 15;
          });
        },
        onError: (error) {
          print("Sensor Cahaya tidak didukung di HP ini: $error");
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("Gagal inisiasi sensor cahaya: $e");
    }
  }

  void _startGame() {
    setState(() {
      _timeLeft = 30;
      _isPlaying = true;
      _isGameOver = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _winGame();
      }
    });

    try {
      _sensorSubscription = accelerometerEventStream().listen(
        (event) {
          if (_isPlaying) {
            setState(() {
              _x = event.x;
              _y = event.z;
            });

            if (_x > _threshold ||
                _x < -_threshold ||
                _y > _threshold ||
                _y < -_threshold) {
              _loseGame();
            }
          }
        },
        onError: (error) {
          print("Accelerometer tidak didukung: $error");
          _loseGame();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("Gagal inisiasi Accelerometer: $e");
    }
  }

  void _loseGame() {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });
  }

  void _winGame() async {
    _timer?.cancel();
    _sensorSubscription?.cancel();
    await _addPoints();

    setState(() {
      _isPlaying = false;
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
            "✨ SELAMAT! ✨",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Kamu jago menyeimbangkan kopi!\n\nKamu mendapatkan +2 Poin Reward. Cek progres diskonmu di profil!",
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

  // --- UI BARU ---
  @override
  Widget build(BuildContext context) {
    Color bgColor = _isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey[50]!;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;
    Color appBarColor = _isDarkMode
        ? const Color(0xFF1A1A1A)
        : Colors.grey[50]!;
    Color iconBgColor = _isDarkMode ? Colors.grey[800]! : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Barista Balance",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: appBarColor,
        foregroundColor: _isDarkMode ? Colors.white : Colors.brown[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Sensor Cahaya
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isDarkMode
                        ? Icons.nightlight_round
                        : Icons.wb_sunny_rounded,
                    color: _isDarkMode ? Colors.blue[200] : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Light: $_luxValue Lux",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Teks Instruksi
            Text(
              _isPlaying
                  ? "Keep it balanced!"
                  : _isGameOver
                  ? "Oops, spilled! 😭"
                  : "Ready to be a Barista?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 15),

            // Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              decoration: BoxDecoration(
                color: _timeLeft <= 10 ? Colors.red[50] : Colors.brown[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$_timeLeft s",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _timeLeft <= 10 ? Colors.redAccent : Colors.brown[700],
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Area Gelas Kopi
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Transform.translate(
                offset: Offset(_x * -18, _y * 18),
                child: Icon(
                  _isGameOver
                      ? Icons.water_drop_rounded
                      : Icons.local_cafe_rounded,
                  size: 80,
                  color: _isGameOver ? Colors.blueAccent : Colors.brown[700],
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Tombol Mulai
            if (!_isPlaying)
              SizedBox(
                width: 200,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDarkMode
                        ? Colors.brown[500]
                        : Colors.brown[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _startGame,
                  child: Text(
                    _isGameOver ? "Try Again" : "Start Game",
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
    );
  }
}
