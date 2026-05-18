import 'dart:math';
import 'player.dart';
import 'game_map.dart';

/// Ghost AI - Female ghost that chases the player
/// Features: Proximity damage, noise aggro, multiple AI states
class Ghost {
  // Position
  double x;
  double y;
  double angle;

  // Movement
  double baseSpeed;
  double currentSpeed;

  // AI State
  GhostState state;
  double stateTimer;
  double chaseDistance;
  double killDistance;

  // Behavior
  double patrolAngle;
  double patrolTimer;
  double lostTimer;
  bool isVisible;
  double visibilityTimer;
  double flickerTimer;

  // Horror intensity (affects flashlight and camera)
  double horrorIntensity;

  // Damage system
  double damageCooldown; // Cooldown between damage ticks
  double damagePerSecond; // DPS when close to player

  // Noise aggro
  double noiseAlertTimer; // Timer for noise-triggered chase
  bool isAlertedByNoise;

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
    this.damageCooldown = 0,
    this.damagePerSecond = 8.0,
    this.noiseAlertTimer = 0,
    this.isAlertedByNoise = false,
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

    // Speed increases with proximity and over time
    currentSpeed = baseSpeed + horrorIntensity * 0.012;

    // Update damage cooldown
    if (damageCooldown > 0) {
      damageCooldown -= delta;
    }

    // Handle noise alert
    if (isAlertedByNoise) {
      noiseAlertTimer -= delta;
      if (noiseAlertTimer <= 0) {
        isAlertedByNoise = false;
      }
    }

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
      case GhostState.noiseAlert:
        _updateNoiseAlert(player, map, delta, distanceToPlayer);
        break;
    }

    // Visibility - ghost flickers in and out
    visibilityTimer += delta;
    if (horrorIntensity > 0.3) {
      isVisible = true;
    } else if (horrorIntensity > 0.1) {
      isVisible = sin(visibilityTimer * 3) > 0;
    } else {
      isVisible = sin(visibilityTimer * 0.5) > 0.95;
    }

    flickerTimer += delta;
  }

  /// Calculate damage to player based on proximity
  /// Returns damage amount (0 if not damaging)
  double calculateDamage(Player player, double delta) {
    final dx = player.x - x;
    final dy = player.y - y;
    final distance = sqrt(dx * dx + dy * dy);

    // Close proximity damage (within 2.5 units but not touching)
    if (distance < 2.5 && distance > killDistance && state == GhostState.chase) {
      if (damageCooldown <= 0) {
        final damage = damagePerSecond * delta * (1.0 - distance / 2.5);
        damageCooldown = 0.5; // Damage every 0.5 seconds
        return damage;
      }
    }

    return 0;
  }

  /// Alert ghost to a noise at a specific location
  void alertToNoise(double noiseX, double noiseY) {
    isAlertedByNoise = true;
    noiseAlertTimer = 8.0; // Chase for 8 seconds after noise
    if (state != GhostState.chase) {
      state = GhostState.noiseAlert;
      stateTimer = 0;
    }
  }

  /// Patrol state - wander around the map
  void _updatePatrol(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    patrolTimer += delta;
    if (patrolTimer > 3.0 + Random().nextDouble() * 5.0) {
      patrolTimer = 0;
      patrolAngle = Random().nextDouble() * 2 * pi;
    }

    _moveInDirection(patrolAngle, currentSpeed * 0.5, map, delta);

    if (distanceToPlayer < chaseDistance) {
      final angleToPlayer = atan2(player.y - y, player.x - x);
      if (distanceToPlayer < chaseDistance * 0.5 || player.flashlightBeamVisible) {
        state = GhostState.chase;
        stateTimer = 0;
      }
    }

    if (distanceToPlayer < chaseDistance * 1.5 && Random().nextDouble() < 0.001) {
      state = GhostState.stalking;
      stateTimer = 0;
    }
  }

  /// Chase state - actively chase the player
  void _updateChase(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    stateTimer += delta;

    final angleToPlayer = atan2(player.y - y, player.x - x);

    if (!_moveInDirection(angleToPlayer, currentSpeed, map, delta)) {
      if (!_moveInDirection(angleToPlayer + pi / 4, currentSpeed * 0.8, map, delta)) {
        if (!_moveInDirection(angleToPlayer - pi / 4, currentSpeed * 0.8, map, delta)) {
          if (!_moveInDirection(angleToPlayer + pi / 2, currentSpeed * 0.6, map, delta)) {
            _moveInDirection(angleToPlayer - pi / 2, currentSpeed * 0.6, map, delta);
          }
        }
      }
    }

    angle = angleToPlayer;

    if (distanceToPlayer > chaseDistance * 2.0) {
      state = GhostState.lost;
      lostTimer = 0;
    }
  }

  /// Lost state - lost sight of player, search area
  void _updateLost(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    lostTimer += delta;

    final angleToPlayer = atan2(player.y - y, player.x - x);
    _moveInDirection(angleToPlayer + sin(lostTimer * 2) * 0.5, currentSpeed * 0.3, map, delta);

    if (distanceToPlayer < chaseDistance * 0.7) {
      state = GhostState.chase;
      stateTimer = 0;
    }

    if (lostTimer > 10.0) {
      state = GhostState.patrol;
      patrolTimer = 0;
    }
  }

  /// Stalking state - follow player at a distance
  void _updateStalking(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    stateTimer += delta;

    final angleToPlayer = atan2(player.y - y, player.x - x);

    if (distanceToPlayer > 5.0) {
      _moveInDirection(angleToPlayer, currentSpeed * 0.4, map, delta);
    } else if (distanceToPlayer < 3.0) {
      _moveInDirection(angleToPlayer + pi, currentSpeed * 0.2, map, delta);
    }

    angle = angleToPlayer;

    if (distanceToPlayer < 3.0 && stateTimer > 5.0) {
      state = GhostState.chase;
      stateTimer = 0;
    }

    if (stateTimer > 15.0) {
      state = GhostState.patrol;
      patrolTimer = 0;
    }
  }

  /// Noise alert state - ghost heard a noise and is going to investigate
  void _updateNoiseAlert(Player player, List<List<int>> map, double delta, double distanceToPlayer) {
    stateTimer += delta;

    // Rush toward the player's last known position (approximated as current position)
    final angleToPlayer = atan2(player.y - y, player.x - x);

    // Move faster than normal chase when alerted by noise
    if (!_moveInDirection(angleToPlayer, currentSpeed * 1.3, map, delta)) {
      if (!_moveInDirection(angleToPlayer + pi / 3, currentSpeed * 1.0, map, delta)) {
        _moveInDirection(angleToPlayer - pi / 3, currentSpeed * 1.0, map, delta);
      }
    }

    angle = angleToPlayer;

    // If player is found, switch to regular chase
    if (distanceToPlayer < chaseDistance) {
      state = GhostState.chase;
      stateTimer = 0;
    }

    // Give up after noise timer expires
    if (noiseAlertTimer <= 0) {
      state = GhostState.lost;
      lostTimer = 0;
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

    if (GameMap.isWalkable(newX, y, map)) {
      x = newX;
      movedX = true;
    }

    if (GameMap.isWalkable(x, newY, map)) {
      y = newY;
      movedY = true;
    }

    return movedX || movedY;
  }

  /// Check if ghost has caught the player (instant kill range)
  bool hasCaughtPlayer(Player player) {
    final dx = player.x - x;
    final dy = player.y - y;
    return sqrt(dx * dx + dy * dy) < killDistance;
  }

  /// Reset ghost
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
    damageCooldown = 0;
    noiseAlertTimer = 0;
    isAlertedByNoise = false;
  }
}

/// Ghost AI states
enum GhostState {
  patrol,      // Wandering around
  chase,       // Actively chasing player
  lost,        // Lost sight of player, searching
  stalking,    // Following at a distance
  noiseAlert,  // Alerted by noise, rushing to investigate
}
