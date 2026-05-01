import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Timer? _pollingTimer;

  // 1. INISIALISASI NOTIFIKASI
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
    
    // Minta izin untuk Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // 2. FUNGSI UNTUK MENAMPILKAN NOTIFIKASI UI
  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0, // ID Notifikasi
      title,
      body,
      platformDetails,
    );
  }

  // 3. FUNGSI UNTUK CEK DATABASE TERUS MENERUS (POLLING)
  static void startCheckingBookingStatus(String bookingId) {
    // Stop timer yang lama kalau ada
    _pollingTimer?.cancel();

    // Cek ke database setiap 10 detik
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Panggil API Node.js kamu untuk cek status booking
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/bookings/status/$bookingId'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Asumsi database kamu mengembalikan status "Confirmed" jika sudah di ACC Admin
          if (data['status'] == 'Confirmed') {
            // Munculkan Notifikasi!
            showNotification(
              "Pembayaran Diterima! ☕", 
              "Hore! Booking kamu sudah di-ACC admin. Ditunggu di Caffio ya!"
            );
            
            // Hentikan pengecekan agar tidak notif terus-terusan
            timer.cancel(); 
          }
        }
      } catch (e) {
        print("Gagal cek status booking: $e");
      }
    });
  }

  // 4. FUNGSI UNTUK MEMATIKAN PENGECEKAN (Misal saat user log out)
  static void stopChecking() {
    _pollingTimer?.cancel();
  }
}