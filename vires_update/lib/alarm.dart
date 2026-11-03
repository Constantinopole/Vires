import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

const _customSound = 'assets/sounds/timer.mp3';

AudioPlayer? _audio;
AudioPlayer get _player => _audio ??= AudioPlayer();

/// True when a custom sound (timer.mp3) was added to the app.
Future<bool> hasCustomSound() async {
  try {
    await rootBundle.load(_customSound);
    return true;
  } catch (_) {
    return false;
  }
}

/// Rings the phone and vibrates. Uses your own sound if the app has one,
/// otherwise the phone's alarm sound. On a computer these do nothing, and that is fine.
Future<void> ringAndVibrate() async {
  try {
    await Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 600]);
  } catch (_) {
    HapticFeedback.vibrate();
  }
  if (await hasCustomSound()) {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('sounds/timer.mp3'));
      Future.delayed(const Duration(seconds: 12), stopRing); // never ring for too long
      return;
    } catch (_) {}
  }
  try {
    await FlutterRingtonePlayer().play(
      android: AndroidSounds.alarm,
      ios: IosSounds.alarm,
      looping: false,
      volume: 1.0,
      asAlarm: true,
    );
    Future.delayed(const Duration(seconds: 4), stopRing);
  } catch (_) {}
}

Future<void> stopRing() async {
  try {
    await _audio?.stop();
  } catch (_) {}
  try {
    await FlutterRingtonePlayer().stop();
  } catch (_) {}
}
