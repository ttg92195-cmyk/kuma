import 'dart:math';
import 'package:flutter/foundation.dart';
import 'player.dart';
import 'game_map.dart';
import 'flashlight.dart';
import 'ghost.dart';

/// Central game state manager - manages all game systems
class GameState extends ChangeNotifier {
  // Core systems
  late Player player;
  late Flashlight flashlight;
  late Ghost ghost;
  late List<List<int>> currentMap;
  late List<InteractiveObject> interactiveObjects;

  // Game state
  GamePhase phase;
  double gameTime;
  int score;
  Set<String> inventory = {};
  String? currentMessage;
  double messageTimer;
  bool showNoteOverlay;
  String? noteContent;
  String? noteLabel;

  // Horror events
  double horrorEventTimer;
  int horrorEventCount;
  bool jumpscareActive;
  double jumpscareTimer;
  double ambientIntensity;

  // Interaction
  InteractiveObject? nearbyObject;
  bool canInteract;

  // Ghost-caused death
  bool killedByGhost;
  double deathTimer;

  // Camera glitch intensity (0.0 to 1.0)
  double cameraGlitchIntensity;

  GameState({
    Player? player,
    Flashlight? flashlight,
    Ghost? ghost,
    this.phase = GamePhase.menu,
    this.gameTime = 0.0,
    this.score = 0,
    Set<String>? inventory,
    this.currentMessage,
    this.messageTimer = 0.0,
    this.showNoteOverlay = false,
    this.noteContent,
    this.noteLabel,
    this.horrorEventTimer = 15.0,
    this.horrorEventCount = 0,
    this.jumpscareActive = false,
    this.jumpscareTimer = 0.0,
    this.ambientIntensity = 0.3,
    this.nearbyObject,
    this.canInteract = false,
    this.killedByGhost = false,
    this.deathTimer = 0,
    this.cameraGlitchIntensity = 0,
  }) {
    this.player = player ?? Player();
    this.flashlight = flashlight ?? Flashlight();
    this.ghost = ghost ?? Ghost();
    this.inventory = inventory ?? {};
    currentMap = GameMap.hospitalMap.map((row) => List<int>.from(row)).toList();
    interactiveObjects = GameMap.objects
        .map((obj) => InteractiveObject(
              x: obj.x,
              y: obj.y,
              type: obj.type,
              id: obj.id,
              label: obj.label,
              requiredKey: obj.requiredKey,
              content: obj.content,
            ))
        .toList();
  }

  /// Initialize a new game
  void startGame() {
    // Reset the map
    currentMap = GameMap.hospitalMap.map((row) => List<int>.from(row)).toList();

    player.reset();
    flashlight.reset();
    ghost.reset();
    gameTime = 0.0;
    score = 0;
    inventory.clear();
    currentMessage = null;
    messageTimer = 0.0;
    showNoteOverlay = false;
    noteContent = null;
    noteLabel = null;
    horrorEventTimer = 15.0 + Random().nextDouble() * 20.0;
    horrorEventCount = 0;
    jumpscareActive = false;
    jumpscareTimer = 0.0;
    ambientIntensity = 0.3;
    nearbyObject = null;
    canInteract = false;
    killedByGhost = false;
    deathTimer = 0;
    cameraGlitchIntensity = 0;
    phase = GamePhase.playing;

    // Reset interactive objects
    for (final obj in interactiveObjects) {
      obj.isCollected = false;
      obj.isOpened = false;
    }

    // Validate spawn position
    _validateSpawnPosition();

    // Show intro message
    showMessage('Find the keys. Escape the asylum. Don\'t let her catch you...', duration: 5.0);

    notifyListeners();
  }

  void _validateSpawnPosition() {
    if (!GameMap.isWalkable(player.x, player.y, currentMap)) {
      debugPrint('WARNING: Player spawn inside wall! Finding valid position...');
      for (int radius = 1; radius < 10; radius++) {
        for (int dx = -radius; dx <= radius; dx++) {
          for (int dy = -radius; dy <= radius; dy++) {
            final testX = GameMap.spawnX + dx;
            final testY = GameMap.spawnY + dy;
            if (testX > 0 && testX < GameMap.width &&
                testY > 0 && testY < GameMap.height &&
                GameMap.isWalkable(testX, testY, currentMap)) {
              player.x = testX + 0.5;
              player.y = testY + 0.5;
              debugPrint('Player repositioned to (${player.x}, ${player.y})');
              return;
            }
          }
        }
      }
    }
  }

  /// Main game update loop
  void update(double delta) {
    if (phase != GamePhase.playing) return;

    // Update game time
    gameTime += delta;

    // Update flashlight
    flashlight.update(delta);

    // Ghost flashlight flicker: if ghost is near, force flashlight to flicker
    if (ghost.horrorIntensity > 0.3 && flashlight.isOn) {
      flashlight.isFlickering = true;
    } else if (ghost.horrorIntensity < 0.1) {
      // Only stop flickering if ghost is far (natural flicker from low battery still works)
      if (flashlight.batteryLevel >= 20.0) {
        flashlight.isFlickering = false;
      }
    }

    // Update ghost AI
    ghost.update(player, currentMap, delta);

    // Update camera glitch intensity based on ghost proximity
    cameraGlitchIntensity = ghost.horrorIntensity;

    // Check if ghost caught the player
    if (ghost.hasCaughtPlayer(player)) {
      killedByGhost = true;
      phase = GamePhase.dead;
      jumpscareActive = true;
      jumpscareTimer = 2.0;
      showMessage('She caught you...', duration: 3.0);
      notifyListeners();
      return;
    }

    // Update player stamina
    player.updateStamina(delta);

    // Check for nearby interactive objects
    _checkNearbyObjects();

    // Update message timer
    if (messageTimer > 0) {
      messageTimer -= delta;
      if (messageTimer <= 0) {
        currentMessage = null;
        messageTimer = 0;
      }
    }

    // Update jumpscare
    if (jumpscareActive) {
      jumpscareTimer -= delta;
      if (jumpscareTimer <= 0) {
        jumpscareActive = false;
        jumpscareTimer = 0;
      }
    }

    // Horror event timer
    horrorEventTimer -= delta;
    if (horrorEventTimer <= 0) {
      _triggerHorrorEvent();
      horrorEventTimer = 15.0 + Random().nextDouble() * 30.0;
    }

    // Check win condition
    _checkWinCondition();

    notifyListeners();
  }

  void _checkNearbyObjects() {
    nearbyObject = null;
    canInteract = false;

    for (final obj in interactiveObjects) {
      if (obj.isCollected || obj.isOpened) continue;

      if (obj.isInRange(player.x, player.y, range: 2.0)) {
        final angleToObj = atan2(obj.y - player.y, obj.x - player.x);
        var angleDiff = angleToObj - player.angle;
        while (angleDiff > pi) angleDiff -= 2 * pi;
        while (angleDiff < -pi) angleDiff += 2 * pi;

        if (angleDiff.abs() < pi / 3) {
          nearbyObject = obj;
          canInteract = true;
          return;
        }
      }
    }
  }

  void interact() {
    if (!canInteract || nearbyObject == null) return;

    final obj = nearbyObject!;

    switch (obj.type) {
      case InteractionType.door:
        _interactDoor(obj);
        break;
      case InteractionType.item:
        _interactItem(obj);
        break;
      case InteractionType.note:
        _interactNote(obj);
        break;
    }

    notifyListeners();
  }

  void _interactDoor(InteractiveObject obj) {
    if (obj.requiredKey != null && !inventory.contains(obj.requiredKey)) {
      showMessage('Locked. You need: ${obj.requiredKey?.replaceAll('_', ' ') ?? 'unknown key'}');
      return;
    }

    obj.isOpened = true;
    final mapX = obj.x.floor();
    final mapY = obj.y.floor();
    if (mapX >= 0 && mapX < GameMap.width && mapY >= 0 && mapY < GameMap.height) {
      currentMap[mapY][mapX] = 0;
    }

    showMessage('Opened: ${obj.label}');
    score += 50;
    ambientIntensity = (ambientIntensity + 0.1).clamp(0.0, 1.0);

    // Opening doors can alert the ghost
    if (Random().nextDouble() < 0.3) {
      // Ghost starts chasing
      if (ghost.state != GhostState.chase) {
        ghost.state = GhostState.chase;
        ghost.stateTimer = 0;
      }
    }
  }

  void _interactItem(InteractiveObject obj) {
    obj.isCollected = true;

    if (obj.id.startsWith('battery_')) {
      flashlight.addBattery(35.0);
      showMessage('Collected: Battery (+35%)');
      score += 25;
    } else if (obj.id.startsWith('key_')) {
      inventory.add(obj.id);
      showMessage('Collected: ${obj.label}');
      score += 100;
      ambientIntensity = (ambientIntensity + 0.05).clamp(0.0, 1.0);

      // Key pickup triggers horror
      if (Random().nextDouble() < 0.5) {
        ghost.state = GhostState.stalking;
        ghost.stateTimer = 0;
      }
    }
  }

  void _interactNote(InteractiveObject obj) {
    obj.isCollected = true;
    showNoteOverlay = true;
    noteContent = obj.content;
    noteLabel = obj.label;
    score += 30;
  }

  void closeNote() {
    showNoteOverlay = false;
    noteContent = null;
    noteLabel = null;
    notifyListeners();
  }

  void showMessage(String message, {double duration = 3.0}) {
    currentMessage = message;
    messageTimer = duration;
  }

  void _triggerHorrorEvent() {
    horrorEventCount++;
    final event = Random().nextInt(5);

    switch (event) {
      case 0:
        ambientIntensity = (ambientIntensity + 0.15).clamp(0.0, 0.8);
        showMessage('... Something feels different ...', duration: 2.0);
        break;
      case 1:
        flashlight.isFlickering = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          flashlight.isFlickering = false;
        });
        break;
      case 2:
        jumpscareActive = true;
        jumpscareTimer = 0.5;
        break;
      case 3:
        if (flashlight.isOn) {
          flashlight.batteryLevel = (flashlight.batteryLevel - 5.0).clamp(0.0, 100.0);
          showMessage('The flashlight flickers...', duration: 2.0);
        }
        break;
      case 4:
        // Ghost changes behavior
        if (ghost.state == GhostState.patrol) {
          ghost.state = GhostState.stalking;
          ghost.stateTimer = 0;
          showMessage('... You hear footsteps behind you ...', duration: 2.5);
        }
        break;
    }
  }

  void _checkWinCondition() {
    // Exit door at position (30, 30) - wall type 6
    final exitX = 30.5;
    final exitY = 30.5;

    final dx = player.x - exitX;
    final dy = player.y - exitY;
    if (sqrt(dx * dx + dy * dy) < 1.5) {
      // Check if exit door is opened
      final exitDoor = interactiveObjects.firstWhere(
        (obj) => obj.id == 'door_exit',
        orElse: () => InteractiveObject(x: 0, y: 0, type: InteractionType.door, id: '', label: ''),
      );
      if (exitDoor.isOpened) {
        phase = GamePhase.won;
        showMessage('You escaped! Time: ${gameTime.toStringAsFixed(1)}s');
      } else if (inventory.contains('key_exit')) {
        showMessage('Press E to open the EXIT!', duration: 2.0);
      }
    }
  }

  void toggleFlashlight() {
    flashlight.toggle();
    // Flashlight toggle can alert ghost
    if (flashlight.isOn && ghost.horrorIntensity < 0.3) {
      player.flashlightBeamVisible = true;
    }
    notifyListeners();
  }

  void toggleRun() {
    player.isRunning = !player.isRunning;
    notifyListeners();
  }

  bool canWalk(double x, double y) {
    return GameMap.isWalkable(x, y, currentMap);
  }

  void pauseGame() {
    if (phase == GamePhase.playing) {
      phase = GamePhase.paused;
      notifyListeners();
    }
  }

  void resumeGame() {
    if (phase == GamePhase.paused) {
      phase = GamePhase.playing;
      notifyListeners();
    }
  }

  void returnToMenu() {
    phase = GamePhase.menu;
    notifyListeners();
  }

  String get formattedTime {
    final minutes = (gameTime / 60).floor();
    final seconds = (gameTime % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

enum GamePhase {
  menu,
  playing,
  paused,
  won,
  dead,
}
