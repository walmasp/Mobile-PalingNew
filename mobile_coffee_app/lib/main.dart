import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🔥 Import Provider
import 'features/auth/screens/welcome_screen.dart';
import 'core/utils/point_provider.dart'; // 🔥 Sesuaikan path ke file PointProvider kamu

void main() async {
  // Wajib ditambahkan karena menggunakan fungsi async sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // 🔥 Bungkus MainApp dengan MultiProvider agar state poin bisa diakses di semua screen
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PointProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Caffio App',
      theme: ThemeData(
        // Tema utama Cokelat (Brown) khas Caffio
        primarySwatch: Colors.brown,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          primary: Colors.brown[700],
        ),
        useMaterial3: true,
      ),
      // Halaman pertama yang muncul adalah WelcomeScreen
      home: const WelcomeScreen(),
    );
  }
}