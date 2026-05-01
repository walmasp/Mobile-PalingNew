import 'package:flutter/material.dart';

class PointProvider with ChangeNotifier {
  int _poin = 0;

  int get poin => _poin;

  // Fungsi untuk update poin di seluruh aplikasi secara instan
  void updatePoin(int poinBaru) {
    _poin = poinBaru;
    notifyListeners(); // Ini yang membuat semua widget yang dengerin bakal refresh otomatis
  }
}