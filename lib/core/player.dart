import 'dart:math';
import 'game_map.dart';

/// Player state and movement controller
class Player {
  // Position
  double x;
  double y;
  double angle; // Facing direction in radians

  // Movement
  double moveSpeed;
  double rotationSpeed;
  double currentMoveSpeed; // For walking/running
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

  Player({
    double? x,
    double? y,
    double? angle,
    this.moveSpeed = 0.04,
    this.rotationSpeed = 0.04,
    this.isRunning = false,
    this.isMoving = false,
    this.bobPhase = 0.0,
    this.bobAmount = 0.0,
    this.health = 100.0,
    this.stamina = 100.0,
    this.maxStamina = 100.0,
  })  : x = x ?? GameMap.spawnX,
        y = y ?? GameMap.spawnY,
        angle = angle ?? GameMap.spawnAngle,
        currentMoveSpeed = moveSpeed,
        currentRotSpeed = rotationSpeed;

  /// Move player forward/backward
  void moveForward(double delta, bool Function(double, double) canWalk) {
    final speed = isRunning ? moveSpeed * 2.0 : moveSpeed;
    final newX = x + cos(angle) * speed * delta;
    final newY = y + sin(angle) * speed * delta;

    // Check collision with sliding along walls
    if (canWalk(newX, y)) x = newX;
    if (canWalk(x, newY)) y = newY;

    isMoving = true;
    _updateBob(delta);
  }

  /// Move player backward
  void moveBackward(double delta, bool Function(double, double) canWalk) {
    final speed = moveSpeed * 0.7;
    final newX = x - cos(angle) * speed * delta;
    final newY = y - sin(angle) * speed * delta;

    if (canWalk(newX, y)) x = newX;
    if (canWalk(x, newY)) y = newY;

    isMoving = true;
    _updateBob(delta);
  }

  /// Strafe left
  void strafeLeft(double delta, bool Function(double, double) canWalk) {
    final speed = moveSpeed * 0.7;
    final newX = x + cos(angle - pi / 2) * speed * delta;
    final newY = y + sin(angle - pi / 2) * speed * delta;

    if (canWalk(newX, y)) x = newX;
    if (canWalk(x, newY)) y = newY;

    isMoving = true;
    _updateBob(delta);
  }

  /// Strafe right
  void strafeRight(double delta, bool Function(double, double) canWalk) {
    final speed = moveSpeed * 0.7;
    final newX = x + cos(angle + pi / 2) * speed * delta;
    final newY = y + sin(angle + pi / 2) * speed * delta;

    if (canWalk(newX, y)) x = newX;
    if (canWalk(x, newY)) y = newY;

    isMoving = true;
    _updateBob(delta);
  }

  /// Rotate player left
  void rotateLeft(double delta) {
    angle -= rotationSpeed * delta;
    // Normalize angle
    while (angle < 0) angle += 2 * pi;
  }

  /// Rotate player right
  void rotateRight(double delta) {
    angle += rotationSpeed * delta;
    while (angle > 2 * pi) angle -= 2 * pi;
  }

  /// Apply joystick input for movement and rotation
  void applyJoystickInput(
    double moveX,
    double moveY,
    double delta,
    bool Function(double, double) canWalk,
  ) {
    // moveX: -1 to 1 (left/right strafe)
    // moveY: -1 to 1 (forward/backward)

    if (moveY.abs() > 0.1) {
      if (moveY > 0) {
        final speed = moveSpeed * moveY * delta * 60;
        final newX = x + cos(angle) * speed;
        final newY = y + sin(angle) * speed;
        if (canWalk(newX, y)) x = newX;
        if (canWalk(x, newY)) y = newY;
      } else {
        final speed = moveSpeed * moveY.abs() * delta * 60 * 0.7;
        final newX = x - cos(angle) * speed;
        final newY = y - sin(angle) * speed;
        if (canWalk(newX, y)) x = newX;
        if (canWalk(x, newY)) y = newY;
      }
      isMoving = true;
    }

    if (moveX.abs() > 0.1) {
      if (moveX > 0) {
        final speed = moveSpeed * moveX * delta * 60 * 0.7;
        final newX = x + cos(angle + pi / 2) * speed;
        final newY = y + sin(angle + pi / 2) * speed;
        if (canWalk(newX, y)) x = newX;
        if (canWalk(x, newY)) y = newY;
      } else {
        final speed = moveSpeed * moveX.abs() * delta * 60 * 0.7;
        final newX = x + cos(angle - pi / 2) * speed;
        final newY = y + sin(angle - pi / 2) * speed;
        if (canWalk(newX, y)) x = newX;
        if (canWalk(x, newY)) y = newY;
      }
      isMoving = true;
    }

    if (isMoving) _updateBob(delta);
  }

  /// Apply touch look (rotation from right side of screen)
  void applyLookInput(double dx) {
    angle += dx * 0.003;
    while (angle > 2 * pi) angle -= 2 * pi;
    while (angle < 0) angle += 2 * pi;
  }

  /// Update head bob animation
  void _updateBob(double delta) {
    final bobSpeed = isRunning ? 12.0 : 8.0;
    bobPhase += bobSpeed * delta;
    bobAmount = sin(bobPhase) * (isRunning ? 8.0 : 4.0);
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

  /// Reset player to spawn position (from GameMap constants)
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
  }
}
