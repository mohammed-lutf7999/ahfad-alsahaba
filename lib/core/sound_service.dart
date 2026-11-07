import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../data/local/shared_prefs_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // Sound file paths
  // Correct Answer (Randomized)
  static const List<String> _correctSounds = [
    'audio/correct_1.mp3',
    'audio/correct_2.mp3',
    'audio/correct_3.mp3',
  ];

  // Core Gameplay
  static const String wrongSound = 'audio/wrong.mp3';
  static const String levelCompleteSound = 'audio/level_complete.mp3';
  static const String timerTickSound = 'audio/timer_tick.wav';
  static const String hintUseSound = 'audio/hint_use.mp3';
  static const String streakFireSound = 'audio/streak_fire.mp3';

  // UI Sounds
  static const String clickSound = 'audio/click.mp3';
  static const String uiTapSound = 'audio/ui_tap.mp3';
  static const String uiBackSound = 'audio/ui_back.mp3';
  static const String uiAlertSound = 'audio/ui_alert.mp3';

  // Multiplayer & Results
  static const String playerJoinSound = 'audio/player_join.mp3';
  static const String gameStartSound = 'audio/game_start_whistle.mp3';
  static const String victorySound = 'audio/victory_fanfare.mp3';
  static const String defeatSound = 'audio/defeat_soft.mp3';
  static const String rankUpSound = 'audio/rank_up.mp3';

  // Random number generator
  final _random = Random();

  // Special player for looping sounds (like timer)
  AudioPlayer? _loopPlayer;

  /// Observable counter for verifying rank-up audio triggers in tests when sound is enabled.
  @visibleForTesting
  int rankUpPlayCount = 0;

  Future<void> playSound(String assetPath, {double volume = 1.0}) async {
    if (!SharedPrefsService.getSoundEnabled()) return;

    try {
      final player = AudioPlayer();
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
      player.onPlayerComplete.listen((event) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Error playing sound ($assetPath): $e');
    }
  }

  // --- Gameplay Methods ---
  Future<void> playCorrect() async {
    final randomSound = _correctSounds[_random.nextInt(_correctSounds.length)];
    await playSound(randomSound);
  }

  Future<void> playWrong() async => playSound(wrongSound);
  Future<void> playLevelComplete() async => playSound(levelCompleteSound);

  // Hint & Streak
  Future<void> playHintUse() async => playSound(hintUseSound);
  Future<void> playStreak() async => playSound(streakFireSound);

  // --- Timer Methods ---
  Future<void> startTimerTick() async {
    if (!SharedPrefsService.getSoundEnabled()) return;
    _loopPlayer?.dispose();
    _loopPlayer = AudioPlayer();
    try {
      await _loopPlayer!.setVolume(0.5);
      await _loopPlayer!.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer!.play(AssetSource(timerTickSound));
    } catch (e) {
      debugPrint('Error starting timer sound: $e');
    }
  }

  Future<void> stopTimerTick() async {
    try {
      await _loopPlayer?.stop();
      await _loopPlayer?.dispose();
      _loopPlayer = null;
    } catch (e) {
      // Ignore
    }
  }

  // --- UI Methods ---
  Future<void> playClick() async => playSound(clickSound);
  Future<void> playTap() async => playSound(uiTapSound);
  Future<void> playBack() async => playSound(uiBackSound);
  Future<void> playAlert() async => playSound(uiAlertSound);

  // --- Multiplayer & Results Methods ---
  Future<void> playPlayerJoin() async => playSound(playerJoinSound);
  Future<void> playGameStart() async => playSound(gameStartSound);
  Future<void> playVictory() async => playSound(victorySound);
  Future<void> playDefeat() async => playSound(defeatSound);

  /// Plays the solemn human vocal rank-up fanfare (`assets/audio/rank_up.mp3`)
  /// safely respecting mute settings and catching any platform audio errors.
  Future<void> playRankUp() async {
    if (!SharedPrefsService.getSoundEnabled()) return;
    rankUpPlayCount++;
    try {
      await playSound(rankUpSound);
    } catch (e) {
      debugPrint('Error in playRankUp: $e');
    }
  }

  Future<void> playNotification() async => playSound(uiAlertSound);
}
