import 'dart:async';
import 'package:flutter/foundation.dart';

/// Audio Manager - manages all game audio
/// Uses audioplayers package for sound playback
/// All methods are wrapped in try-catch so missing audio files won't crash the game
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  bool _initialized = false;
  bool _ambientPlaying = false;

  /// Initialize audio system - safe even without audio files
  Future<void> init() async {
    if (_initialized) return;
    try {
      // Audio players will be initialized when sounds are played
      // In a real implementation, we'd preload audio assets here
      _initialized = true;
      debugPrint('AudioManager: Initialized (stub mode - no audio files)');
    } catch (e) {
      _initialized = false;
      debugPrint('AudioManager: Init error (safe) - $e');
    }
  }

  /// Play footstep sound
  Future<void> playFootstep() async {
    try {
      if (!_initialized) return;
      // In a full implementation:
      // final player = AudioPlayer();
      // await player.play(AssetSource('audio/footstep.wav'));
    } catch (e) {
      debugPrint('AudioManager: Footstep error (safe) - $e');
    }
  }

  /// Play door open sound
  Future<void> playDoorOpen() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Door open error (safe) - $e');
    }
  }

  /// Play door locked sound
  Future<void> playDoorLocked() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Door locked error (safe) - $e');
    }
  }

  /// Play item pickup sound
  Future<void> playItemPickup() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Item pickup error (safe) - $e');
    }
  }

  /// Play key pickup sound
  Future<void> playKeyPickup() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Key pickup error (safe) - $e');
    }
  }

  /// Play jumpscare sound
  Future<void> playJumpscare() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Jumpscare error (safe) - $e');
    }
  }

  /// Start ambient horror sound - safe even without audio files
  Future<void> startAmbient() async {
    try {
      if (!_initialized || _ambientPlaying) return;
      _ambientPlaying = true;
      // In full implementation:
      // _ambientPlayer = AudioPlayer();
      // await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      // await _ambientPlayer.play(AssetSource('audio/ambient.wav'));
      // await _ambientPlayer.setVolume(0.3);
    } catch (e) {
      _ambientPlaying = false;
      debugPrint('AudioManager: Ambient start error (safe) - $e');
    }
  }

  /// Stop ambient sound
  Future<void> stopAmbient() async {
    try {
      if (!_ambientPlaying) return;
      _ambientPlaying = false;
    } catch (e) {
      debugPrint('AudioManager: Ambient stop error (safe) - $e');
    }
  }

  /// Play flashlight toggle sound
  Future<void> playFlashlightToggle() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Flashlight toggle error (safe) - $e');
    }
  }

  /// Play breathing sound (when running)
  Future<void> playBreathing() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Breathing error (safe) - $e');
    }
  }

  /// Play wall scratch sound (horror event)
  Future<void> playWallScratch() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Wall scratch error (safe) - $e');
    }
  }

  /// Play whisper sound (horror event)
  Future<void> playWhisper() async {
    try {
      if (!_initialized) return;
    } catch (e) {
      debugPrint('AudioManager: Whisper error (safe) - $e');
    }
  }

  /// Update ambient intensity based on game state
  void updateAmbientIntensity(double intensity) {
    try {
      if (!_initialized) return;
      // Adjust ambient volume and add horror elements based on intensity
    } catch (e) {
      debugPrint('AudioManager: Ambient intensity error (safe) - $e');
    }
  }

  /// Dispose all audio resources
  void dispose() {
    try {
      stopAmbient();
      _initialized = false;
    } catch (e) {
      debugPrint('AudioManager: Dispose error (safe) - $e');
    }
  }
}
