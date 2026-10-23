/// Profil du joueur de ce téléphone (nom et masque préféré), gardé en
/// mémoire pendant que l'application est ouverte.
library;

import 'package:flutter/foundation.dart';

class PlayerProfile extends ChangeNotifier {
  PlayerProfile._();

  static final PlayerProfile instance = PlayerProfile._();

  String _name = 'Joueur';
  int _seat = 0;

  String get name => _name;

  /// Siège préféré = masque choisi (0 Kanaga, 1 Sirige, 2 Walu, 3 Satimbe).
  int get seat => _seat;

  set name(String value) {
    final t = value.trim();
    final clean = t.isEmpty ? 'Joueur' : (t.length > 16 ? t.substring(0, 16) : t);
    if (clean == _name) return;
    _name = clean;
    notifyListeners();
  }

  set seat(int value) {
    if (value == _seat || value < 0 || value > 3) return;
    _seat = value;
    notifyListeners();
  }
}
