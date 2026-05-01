import 'package:flutter/material.dart';

// Halaman Daftar Cafe (Agregator)
class CafeHomeScreen extends StatelessWidget {
  const CafeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Halaman Daftar Cafe (Agregator)")),
    );
  }
}

// Halaman Maps (LBS)
class CafeMapsScreen extends StatelessWidget {
  const CafeMapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Halaman Maps (LBS)")));
  }
}
