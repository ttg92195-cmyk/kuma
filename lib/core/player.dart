import 'dart:math';
import 'game_map.dart';

/// Player state and movement controller
/// CRITICAL: Uses double values for smooth continuous movement
/// Movement is RELATIVE to player facing direction (Mobile Legends style)
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
  /// RELATIVE to player facing direction (Mobile Legends / FPS style)
  ///
  /// moveX: -1 to 1 (left/right strafe)
  /// moveY: -1 to 1 (forward/backward)
  ///
  /// How it works:
  /// - Joystick UP → Player moves FORWARD in the direction they're facing
  /// - Joystick DOWN → Player moves BACKWARD
  /// - Joystick LEFT → Player STRAFES LEFT (relative to their view)
  /// - Joystick RIGHT → Player STRAFES RIGHT (relative to their view)
  ///
  /// Math: Uses combined direction vector from forward + strafe,
  /// normalized to prevent faster diagonal movement
  void applyJoystickInput(
    double moveX,
    double moveY,
    double delta,
    bool Function(double, double) canWalk,
  ) {
    // Dead zone - ignore very small inputs
    if (moveX.abs() < 0.08 && moveY.abs() < 0.08) {
      stopMoving();
      return;
    }

    final runMultiplier = isRunning ? 1.8 : 1.0;
    final speed = moveSpeed * runMultiplier * delta;

    // Combine forward and strafe into a single direction vector
    // Forward direction: (cos(angle), sin(angle))
    // Strafe LEFT direction: (cos(angle - pi/2), sin(angle - pi/2))
    //   = (sin(angle), -cos(angle))
    //
    // In our coordinate system (Y-down, angle=0 faces RIGHT):
    //   - angle - pi/2 gives the LEFT perpendicular direction
    //   - Positive moveX = strafe LEFT, Negative moveX = strafe RIGHT

    double forward = moveY;  // +1 = forward, -1 = backward
    double strafe = moveX;   // +1 = strafe left, -1 = strafe right

    // Normalize diagonal movement so it's not faster than cardinal
    final magnitude = sqrt(forward * forward + strafe * strafe);
    if (magnitude > 1.0) {
      forward /= magnitude;
      strafe /= magnitude;
    }

    // Combined movement direction in world space
    // Forward vector: (cos(angle), sin(angle))
    // Strafe-left vector: (sin(angle), -cos(angle))
    final moveDirX = cos(angle) * forward + sin(angle) * strafe;
    final moveDirY = sin(angle) * forward + (-cos(angle)) * strafe;

    // Apply movement with sliding collision
    final newX = x + moveDirX * speed;
    final newY = y + moveDirY * speed;

    // Sliding collision: try each axis independently
    // This allows "sliding" along walls instead of getting stuck
    bool moved = false;
    if (canWalk(newX, y)) { x = newX; moved = true; }
    if (canWalk(x, newY)) { y = newY; moved = true; }

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
