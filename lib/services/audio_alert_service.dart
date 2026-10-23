import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioAlertService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playPttStartChirp() async {
    // Haptic feedback + radio beep
    HapticFeedback.heavyImpact();
    // In production, load custom radio sound asset
  }

  Future<void> playPttRogerBeep() async {
    HapticFeedback.mediumImpact();
  }

  Future<void> playSosAlarm() async {
    // Repeated urgent haptic vibration
    for (int i = 0; i < 3; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> playSeparationAlert() async {
    HapticFeedback.selectionClick();
  }

  void dispose() {
    _player.dispose();
  }
}
