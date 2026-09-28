import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// Its own player, so a refresh chime mid-order cannot cut the ring off.
  final AudioPlayer _ringPlayer = AudioPlayer();

  Future<void> playRefreshSound() async {
    try {
      await _player.play(AssetSource('sound/refersh.mp4'));
    } catch (e) {
      // Ignore errors for sound playback
    }
  }

  /// The incoming-order ringtone. Loops until [stopNewOrderRing] — accepting
  /// or rejecting is the only thing that stops it, which is the whole point:
  /// an alert that goes quiet by itself is one nobody notices.
  ///
  /// Plays on the alarm stream, not media, so it is still audible with the
  /// media volume down — the normal state for a phone sitting on a counter.
  /// Same file the native overlay uses (`res/raw/tujh_bin1.mp3`); this copy
  /// covers the foreground case, where the in-app dialog shows instead.
  Future<void> playNewOrderRing() async {
    try {
      await _ringPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            stayAwake: true,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.setVolume(1.0);
      await _ringPlayer.play(AssetSource('sound/tujh_bin1.mp3'));
    } catch (e) {
      // Never let a bad asset take the order dialog down with it — but say so,
      // because a silently dead ringtone is exactly the bug being fixed here.
      debugPrint('[AudioService] new-order ring failed to start: $e');
    }
  }

  Future<void> stopNewOrderRing() async {
    try {
      await _ringPlayer.stop();
    } catch (e) {
      debugPrint('[AudioService] new-order ring failed to stop: $e');
    }
  }
}
