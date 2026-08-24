import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppSound {
  tap('sounds/tap.mp3'),
  screenOpen('sounds/screen_open.mp3'),
  screenClose('sounds/screen_close.mp3'),
  success('sounds/success.mp3'),
  error('sounds/error.mp3'),
  eggCollected('sounds/egg_collected.mp3'),
  objectPlaced('sounds/object_placed.mp3'),
  pointEarned('sounds/point_earned.mp3');

  const AppSound(this.asset);

  final String asset;
}

/// Short interface feedback. Sounds and haptics are opt-out from Settings and
/// nothing in the app depends on them being enabled.
class FeedbackService {
  FeedbackService();

  static const _poolSize = 3;
  final List<AudioPlayer> _players = [];
  var _cursor = 0;
  var _ready = false;

  bool soundEnabled = true;
  bool hapticsEnabled = true;

  Future<void> warmUp() async {
    if (_ready) return;
    try {
      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop)
          ..setPlayerMode(PlayerMode.lowLatency);
        await player.setVolume(0.55);
        _players.add(player);
      }
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          // ambient already mixes with other audio by default on iOS;
          // explicitly passing mixWithOthers is only allowed for playback /
          // playAndRecord / multiRoute and causes an assertion crash otherwise.
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      _ready = true;
    } on Object catch (error) {
      // Audio is a nicety: a device that refuses to open an output must not
      // stop the app from starting.
      assert(() { debugPrint('Audio warm-up skipped: $error'); return true; }());
      _ready = false;
    }
  }

  Future<void> play(AppSound sound) async {
    if (!soundEnabled || !_ready || _players.isEmpty) return;
    final player = _players[_cursor % _players.length];
    _cursor++;
    try {
      await player.stop();
      await player.play(AssetSource(sound.asset));
    } on Object catch (error) {
      assert(() { debugPrint('Sound failed: $error'); return true; }());
    }
  }

  void tapFeedback() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
    play(AppSound.tap);
  }

  void lightImpact() {
    if (hapticsEnabled) HapticFeedback.lightImpact();
  }

  void mediumImpact() {
    if (hapticsEnabled) HapticFeedback.mediumImpact();
  }

  void success() {
    if (hapticsEnabled) HapticFeedback.mediumImpact();
    play(AppSound.success);
  }

  void error() {
    if (hapticsEnabled) HapticFeedback.heavyImpact();
    play(AppSound.error);
  }

  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
    _ready = false;
  }
}
