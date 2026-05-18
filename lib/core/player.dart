import 'dart:math';
import 'game_map.dart';

/// Player state and movement controller
/// CRITICAL: Uses double values for smooth continuous movement
class Player {
  // Position (double for smooth movement - NOT grid-locked)
  double x;
  double y;
  double angle; // Facing direction in radians

  // Movement - INCREASED for smooth feel
  double moveSpeed;      // Base movement speed (units per second)
  double rotationSpeed;
  double currentMoveSpeed;
  double currentRotSpeed;

  // State
  bool isRunning;
  bool isMoving;
  double bobPhase; // Head bob animation
  double bobAmount; // Current bob offset

  // Health & Stamina
  double health;
  double stamina;
  double maxStamina;

  // Flashlight beam visibility (for ghost detection)
  bool flashlightBeamVisible;

  Player({
    double? x,
    double? y,
    double? angle,
    this.moveSpeed = 3.0, // MUCH faster: 3.0 units/sec (was 0.04 per frame)
    this.rotationSpeed = 3.0,
    this.isRunning = false,
    this.isMoving = false,
    this.bobPhase = 0.0,
    this.bobAmount = 0.0,
    this.health = 100.0,
    this.stamina = 100.0,
    this.maxStamina = 100.0,
    this.flashlightBeamVisible = true,
  })  : x = x ?? GameMap.spawnX,
        y = y ?? GameMap.spawnY,
        angle = angle ?? GameMap.spawnAngle,
        currentMoveSpeed = 3.0,
        currentRotSpeed = 3.0;

  /// Apply joystick input for SMOOTH continuous movement
  /// moveX: -1 to 1 (left/right strafe)
  /// moveY: -1 to 1 (forward/backward)
  void applyJoystickInput(
    double moveX,
    double moveY,
    double delta,
    bool Function(double, double) canWalk,
  ) {
    bool moved = false;
    final runMultiplier = isRunning ? 1.8 : 1.0;
    final speed = moveSpeed * runMultiplier * delta;

    // Forward/Backward movement
    if (moveY.abs() > 0.1) {
      final moveAmount = speed * moveY;
      final newX = x + cos(angle) * moveAmount;
      final newY = y + sin(angle) * moveAmount;

      // Sliding collision: try each axis independently
      if (canWalk(newX, y)) { x = newX; moved = true; }
      if (canWalk(x, newY)) { y = newY; moved = true; }
    }

    // Strafe movement (left/right)
    if (moveX.abs() > 0.1) {
      final strafeAmount = speed * moveX * 0.7; // Strafe is slower
      final newX = x + cos(angle + pi / 2) * strafeAmount;
      final newY = y + sin(angle + pi / 2) * strafeAmount;

      if (canWalk(newX, y)) { x = newX; moved = true; }
      if (canWalk(x, newY)) { y = newY; moved = true; }
    }

    isMoving = moved;
    if (isMoving) _updateBob(delta);
  }

  /// Apply touch look (rotation from right side of screen)
  void applyLookInput(double dx) {
    angle += dx * 0.004; // Smooth rotation sensitivity
    while (angle > 2 * pi) angle -= 2 * pi;
    while (angle < 0) angle += 2 * pi;
  }

  /// Update head bob animation
  void _updateBob(double delta) {
    final bobSpeed = isRunning ? 12.0 : 8.0;
    bobPhase += bobSpeed * delta;
    bobAmount = sin(bobPhase) * (isRunning ? 4.0 : 2.0);
  }

  /// Update stamina based on movement
  void updateStamina(double delta) {
    if (isRunning && isMoving) {
      stamina = (stamina - 20.0 * delta).clamp(0.0, maxStamina);
      if (stamina <= 0) {
        isRunning = false;
      }
    } else if (!isRunning) {
      stamina = (stamina + 8.0 * delta).clamp(0.0, maxStamina);
    }
  }

  /// Stop movement
  void stopMoving() {
    isMoving = false;
    bobAmount *= 0.9; // Smoothly stop bobbing
  }

  /// Reset player to spawn position
  void reset() {
    x = GameMap.spawnX;
    y = GameMap.spawnY;
    angle = GameMap.spawnAngle;
    health = 100.0;
    stamina = 100.0;
    isRunning = false;
    isMoving = false;
    bobPhase = 0.0;
    bobAmount = 0.0;
    flashlightBeamVisible = true;
  }
}
