/// Sons du jeu, joués par Android (voir SoundPlayer.kt).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum GameSound {
  /// Le dé qui roule.
  dice('dice'),

  /// Le cri quand un pion est avalé.
  capture('capture');

  const GameSound(this.id);
  final String id;
}

class SoundFx extends ChangeNotifier {
  SoundFx._();

  static final SoundFx instance = SoundFx._();
  static const MethodChannel _channel = MethodChannel('ludo_dogon/sound');

  bool _enabled = true;
  bool get enabled => _enabled;

  /// Lit le réglage enregistré sur le téléphone (son activé ou coupé).
  Future<void> load() async {
    try {
      _enabled = await _channel.invokeMethod<bool>('isEnabled') ?? true;
      notifyListeners();
    } on Object {
      // Pas de lecteur de sons (tests, autre plateforme) : on reste silencieux.
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': value});
    } on Object catch (e) {
      debugPrint('Réglage du son impossible : $e');
    }
  }

  void play(GameSound sound) {
    if (!_enabled) return;
    _channel.invokeMethod<void>('play', {'name': sound.id}).catchError((Object e) {
      debugPrint('Son impossible : $e');
    });
  }
}
