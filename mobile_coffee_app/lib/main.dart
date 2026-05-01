import 'package:flutter/material.dart';
// Import halaman Login sebagai pintu masuk utama
import 'features/auth/screens/login_screen.dart';



// 🔥 PERBAIKAN: Ubah main() menjadi async
void main() async {
  // 🔥 WAJIB DITAMBAHKAN KARENA KITA MENGGUNAKAN FUNGSI ASYNC SEBELUM RUNAPP
  WidgetsFlutterBinding.ensureInitialized();

  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Caffio App',
      theme: ThemeData(
        // Kita set tema utama ke warna Cokelat (Brown) agar sesuai tema Cafe
        primarySwatch: Colors.brown,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      // Halaman pertama yang muncul adalah LoginScreen
      home: const LoginScreen(),
    );
  }
}
