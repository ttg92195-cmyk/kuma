import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'player.dart';
import 'game_map.dart';
import 'interactive_object.dart';

/// Flashlight system with battery mechanics
class Flashlight {
  bool isOn;
  double batteryLevel; // 0.0 to 100.0
  double drainRate; // Battery drain per second when on
  double coneAngle; // Flashlight cone angle in radians
  double flickerTimer;
  bool isFlickering;

  Flashlight({
    this.isOn = true,
    this.batteryLevel = 100.0,
    this.drainRate = 2.0, // % per second
    this.coneAngle = 1.2, // Wider flashlight cone for better visibility (~70 degrees)
    this.flickerTimer = 0.0,
    this.isFlickering = false,
  });

  /// Toggle flashlight on/off
  void toggle() {
    if (batteryLevel > 0) {
      isOn = !isOn;
    } else {
      isOn = false;
    }
  }

  /// Update flashlight state
  void update(double delta) {
    if (isOn) {
      // Drain battery
      batteryLevel = (batteryLevel - drainRate * delta).clamp(0.0, 100.0);

      // Auto-off when battery dies
      if (batteryLevel <= 0) {
        isOn = false;
        isFlickering = false;
      }

      // Flicker effect when battery is low
      if (batteryLevel < 20.0 && batteryLevel > 0) {
        flickerTimer += delta;
        if (flickerTimer > 0.1) {
          flickerTimer = 0;
          isFlickering = Random().nextDouble() > (batteryLevel / 20.0);
        }
      } else {
        isFlickering = false;
      }
    }
  }

  /// Add battery from collected batteries
  void addBattery(double amount) {
    batteryLevel = (batteryLevel + amount).clamp(0.0, 100.0);
    if (batteryLevel > 0 && !isOn) {
      // Auto-turn on when battery is added
      isOn = true;
    }
  }

  /// Get current flashlight intensity (accounting for flicker)
  double get intensity {
    if (!isOn) return 0.0;
    if (isFlickering) return 0.3;
    return batteryLevel / 100.0;
  }

  void reset() {
    isOn = true;
    batteryLevel = 100.0;
    flickerTimer = 0.0;
    isFlickering = false;
  }
}
