import 'dart:math';
import 'player.dart';
import 'game_map.dart';

/// Ghost AI - Female ghost that chases the player
/// Uses simple pathfinding with wall avoidance
class Ghost {
  // Position
  double x;
  double y;
  double angle; // Current facing direction

  // Movement
  double baseSpeed;
  double currentSpeed;

  // AI State
  GhostState state;
  double stateTimer;
  double chaseDistance; // How close before actively chasing
  double killDistance; // How close before jumpscare

  // Behavior
  double patrolAngle;
  double patrolTimer;
  double lostTimer; // Timer for when player is lost
  bool isVisible;
  double visibilityTimer;
  double flickerTimer;

  // Horror intensity (affects flashlight and camera)
  double horrorIntensity; // 0.0 to 1.0 based on distance to player

  Ghost({
    double? x,
    double? y,
    this.baseSpeed = 0.015,
    this.currentSpeed = 0.015,
    this.state = GhostState.patrol,
    this.stateTimer = 0,
    this.chaseDistance = 8.0,
    this.killDistance = 0.8,
    this.patrolAngle = 0,
    this.patrolTimer = 0,
    this.lostTimer = 0,
    this.isVisible = false,
    this.visibilityTimer = 0,
    this.flickerTimer = 0,
    this.horrorIntensity = 0,
  })  : x = x ?? 15.0,
        y = y ?? 15.0,
        angle = 0;

  /// Update ghost AI each frame
  void update(Player player, List<List<int>> map, double delta) {
    // Calculate distance to player
    final dx = player.x - x;
    final dy = player.y - y;
    final distanceToPlayer = sqrt(dx * dx + dy * dy);

    // Calculate horror intensity based on distance
    if (distanceToPlayer < chaseDistance) {
      horrorIntensity = (1.0 - distanceToPlayer / chaseDistance).clamp(0.0, 1.0);
    } else {
      horrorIntensity = max(0, horrorIntensity - delta * 0.5);
    }

    // Speed increases over time and when chasing
    currentSpeed = baseSpeed + horrorIntensity * 0.01;

    // State machine
    switch (state) {
      case GhostState.patrol:
        _updatePatrol(player, map, delta, distanceToPlayer);
        break;
      case GhostState.chase:
        _updateChase(player, map, delta, distanceToPlayer);
        break;
      case GhostState.lost:
        _updateLost(player, map, delta, distanceToPlayer);
        break;
      case GhostState.stalking:
        _updateStalking(player, map, delta, distanceToPlayer);
        break;
    }

    // Visibility - ghost flickers in and out
    visibilityTimer += delta;
    if (horrorIntensity > 0.3) {
      isVisible = true;
    } else if (horrorIntensity > 0.1) {
      // Flicker visibility
      isVisible = sin(visibilityTimer * 3) > 0;
    } else {
      // Rarely visible when far
      isVisible = sin(visibilityTimer * 0.5) > 0.95;
    }

    // Ghost flicker timer
    flickerTimer += delta;
  }

  /// Patrol state - wander around the map
  void _updatePatrol(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    // Patrol: walk in a direction, occasionally change
    patrolTimer += delta;
    if (patrolTimer > 3.0 + Random().nextDouble() * 5.0) {
      patrolTimer = 0;
      patrolAngle = Random().nextDouble() * 2 * pi;
    }

    // Move in patrol direction
    _moveInDirection(patrolAngle, currentSpeed * 0.5, map, delta);

    // Detect player if close enough or if flashlight is on and facing ghost
    if (distanceToPlayer < chaseDistance) {
      // Check if player can "see" the ghost (rough check)
      final angleToPlayer = atan2(player.y - y, player.x - x);
      if (distanceToPlayer < chaseDistance * 0.5 || player.flashlightBeamVisible) {
        state = GhostState.chase;
        stateTimer = 0;
      }
    }

    // Random chance to start stalking
    if (distanceToPlayer < chaseDistance * 1.5 && Random().nextDouble() < 0.001) {
      state = GhostState.stalking;
      stateTimer = 0;
    }
  }

  /// Chase state - actively chase the player
  void _updateChase(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    stateTimer += delta;

    // Move directly toward player with wall avoidance
    final angleToPlayer = atan2(player.y - y, player.x - x);

    // Try direct path first
    if (!_moveInDirection(angleToPlayer, currentSpeed, map, delta)) {
      // If blocked, try sliding along walls
      if (!_moveInDirection(angleToPlayer + pi / 4, currentSpeed * 0.8, map, delta)) {
        if (!_moveInDirection(angleToPlayer - pi / 4, currentSpeed * 0.8, map, delta)) {
          if (!_moveInDirection(angleToPlayer + pi / 2, currentSpeed * 0.6, map, delta)) {
            _moveInDirection(angleToPlayer - pi / 2, currentSpeed * 0.6, map, delta);
          }
        }
      }
    }

    angle = angleToPlayer; // Face the player

    // If player gets too far, switch to lost
    if (distanceToPlayer > chaseDistance * 2.0) {
      state = GhostState.lost;
      lostTimer = 0;
    }

    // If very close, stay in chase (this leads to kill check in GameState)
  }

  /// Lost state - lost sight of player, search area
  void _updateLost(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    lostTimer += delta;

    // Move toward last known position (player's current position as approximation)
    final angleToPlayer = atan2(player.y - y, player.x - x);

    // Slowly move toward player but not directly
    _moveInDirection(angleToPlayer + sin(lostTimer * 2) * 0.5, currentSpeed * 0.3, map, delta);

    // Re-detect if player is close
    if (distanceToPlayer < chaseDistance * 0.7) {
      state = GhostState.chase;
      stateTimer = 0;
    }

    // Give up after a while
    if (lostTimer > 10.0) {
      state = GhostState.patrol;
      patrolTimer = 0;
    }
  }

  /// Stalking state - follow player at a distance, creating tension
  void _updateStalking(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    stateTimer += delta;

    final angleToPlayer = atan2(player.y - y, player.x - x);

    if (distanceToPlayer > 5.0) {
      // Move closer but slowly
      _moveInDirection(angleToPlayer, currentSpeed * 0.4, map, delta);
    } else if (distanceToPlayer < 3.0) {
      // Back off slightly to maintain distance
      _moveInDirection(angleToPlayer + pi, currentSpeed * 0.2, map, delta);
    }
    // Otherwise stay still

    angle = angleToPlayer;

    // Transition to chase if player sees ghost
    if (distanceToPlayer < 3.0 && stateTimer > 5.0) {
      state = GhostState.chase;
      stateTimer = 0;
    }

    // Go back to patrol after a while
    if (stateTimer > 15.0) {
      state = GhostState.patrol;
      patrolTimer = 0;
    }
  }

  /// Try to move in a direction, returns true if successful
  bool _moveInDirection(double direction, double speed, List<List<int>> map, double delta) {
    final moveX = cos(direction) * speed * delta * 60;
    final moveY = sin(direction) * speed * delta * 60;

    final newX = x + moveX;
    final newY = y + moveY;

    bool movedX = false;
    bool movedY = false;

    // Try X movement
    if (GameMap.isWalkable(newX, y, map)) {
      x = newX;
      movedX = true;
    }

    // Try Y movement
    if (GameMap.isWalkable(x, newY, map)) {
      y = newY;
      movedY = true;
    }

    return movedX || movedY;
  }

  /// Check if ghost has caught the player
  bool hasCaughtPlayer(Player player) {
    final dx = player.x - x;
    final dy = player.y - y;
    return sqrt(dx * dx + dy * dy) < killDistance;
  }

  /// Reset ghost to starting position
  void reset() {
    x = 15.0;
    y = 15.0;
    angle = 0;
    state = GhostState.patrol;
    stateTimer = 0;
    patrolAngle = 0;
    patrolTimer = 0;
    lostTimer = 0;
    isVisible = false;
    visibilityTimer = 0;
    flickerTimer = 0;
    horrorIntensity = 0;
    currentSpeed = baseSpeed;
  }
}

/// Ghost AI states
enum GhostState {
  patrol,   // Wandering around
  chase,    // Actively chasing player
  lost,     // Lost sight of player, searching
  stalking, // Following at a distance
}
