import 'package:flutter/material.dart';

class PointProvider with ChangeNotifier {
  int _poin = 0;

  int get poin => _poin;

  void updatePoin(int poinBaru) {
    _poin = poinBaru;
    notifyListeners(); 
  }
}
