/// Journal des étapes Bluetooth, affiché dans le diagnostic pour comprendre
/// ce qui se passe sur un vrai téléphone.
library;

import 'package:flutter/foundation.dart';

class NetLog extends ChangeNotifier {
  NetLog._();

  static final NetLog instance = NetLog._();
  static const int _max = 300;

  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  void add(String message) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _lines.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $message');
    if (_lines.length > _max) _lines.removeRange(0, _lines.length - _max);
    debugPrint('[Bluetooth] $message');
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// Texte complet, pour le copier et l'envoyer.
  String get text => _lines.join('\n');
}

void netLog(String message) => NetLog.instance.add(message);
