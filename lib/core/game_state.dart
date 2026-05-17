import 'dart:math';
import 'package:flutter/foundation.dart';
import 'player.dart';
import 'game_map.dart';
import 'flashlight.dart';

/// Central game state manager - manages all game systems
class GameState extends ChangeNotifier {
  // Core systems
  late Player player;
  late Flashlight flashlight;
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
  double ambientIntensity; // 0.0 to 1.0

  // Interaction
  InteractiveObject? nearbyObject;
  bool canInteract;

  GameState({
    Player? player,
    Flashlight? flashlight,
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
  }) {
    this.player = player ?? Player();
    this.flashlight = flashlight ?? Flashlight();
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
    player.reset();
    flashlight.reset();
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
    phase = GamePhase.playing;

    // Reset interactive objects
    for (final obj in interactiveObjects) {
      obj.isCollected = false;
      obj.isOpened = false;
    }

    notifyListeners();
  }

  /// Main game update loop
  void update(double delta) {
    if (phase != GamePhase.playing) return;

    // Update game time
    gameTime += delta;

    // Update flashlight
    flashlight.update(delta);

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

    // Check win condition (player reached exit)
    _checkWinCondition();

    notifyListeners();
  }

  /// Check if any interactive objects are nearby
  void _checkNearbyObjects() {
    nearbyObject = null;
    canInteract = false;

    for (final obj in interactiveObjects) {
      if (obj.isCollected || obj.isOpened) continue;

      if (obj.isInRange(player.x, player.y, range: 2.0)) {
        // Check if player is facing the object (within 90 degree cone)
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

  /// Interact with nearby object
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
    // Check if door requires a key
    if (obj.requiredKey != null && !inventory.contains(obj.requiredKey)) {
      showMessage('This door is locked. You need: ${obj.requiredKey?.replaceAll('_', ' ') ?? 'unknown key'}');
      return;
    }

    // Open the door
    obj.isOpened = true;

    // Remove wall at door position in map
    final mapX = obj.x.floor();
    final mapY = obj.y.floor();
    if (mapX >= 0 && mapX < GameMap.width && mapY >= 0 && mapY < GameMap.height) {
      currentMap[mapY][mapX] = 0; // Remove wall
    }

    showMessage('Opened: ${obj.label}');
    score += 50;

    // Increase horror intensity after opening doors
    ambientIntensity = (ambientIntensity + 0.1).clamp(0.0, 1.0);
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
      // Key pickup triggers subtle horror
      ambientIntensity = (ambientIntensity + 0.05).clamp(0.0, 1.0);
    }
  }

  void _interactNote(InteractiveObject obj) {
    obj.isCollected = true;
    showNoteOverlay = true;
    noteContent = obj.content;
    noteLabel = obj.label;
    score += 30;
  }

  /// Close note overlay
  void closeNote() {
    showNoteOverlay = false;
    noteContent = null;
    noteLabel = null;
    notifyListeners();
  }

  /// Show a temporary message
  void showMessage(String message, {double duration = 3.0}) {
    currentMessage = message;
    messageTimer = duration;
  }

  /// Trigger a horror event
  void _triggerHorrorEvent() {
    horrorEventCount++;
    final event = Random().nextInt(4);

    switch (event) {
      case 0:
        // Ambient intensity spike
        ambientIntensity = (ambientIntensity + 0.15).clamp(0.0, 0.8);
        showMessage('... Something feels different ...', duration: 2.0);
        break;
      case 1:
        // Flashlight flicker
        flashlight.isFlickering = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          flashlight.isFlickering = false;
        });
        break;
      case 2:
        // Jumpscare
        jumpscareActive = true;
        jumpscareTimer = 0.5;
        break;
      case 3:
        // Battery drain scare
        if (flashlight.isOn) {
          flashlight.batteryLevel = (flashlight.batteryLevel - 5.0).clamp(0.0, 100.0);
          showMessage('The flashlight flickers...', duration: 2.0);
        }
        break;
    }
  }

  /// Check if player has reached the exit
  void _checkWinCondition() {
    // Exit is at position (22, 22) - wall type 6
    final exitX = 22;
    final exitY = 22;

    final dx = player.x - exitX;
    final dy = player.y - exitY;
    if (sqrt(dx * dx + dy * dy) < 1.5) {
      phase = GamePhase.won;
      showMessage('You escaped! Time: ${gameTime.toStringAsFixed(1)}s');
    }
  }

  /// Toggle flashlight
  void toggleFlashlight() {
    flashlight.toggle();
    notifyListeners();
  }

  /// Toggle run
  void toggleRun() {
    player.isRunning = !player.isRunning;
    notifyListeners();
  }

  /// Check if a position is walkable
  bool canWalk(double x, double y) {
    return GameMap.isWalkable(x, y, currentMap);
  }

  /// Pause game
  void pauseGame() {
    if (phase == GamePhase.playing) {
      phase = GamePhase.paused;
      notifyListeners();
    }
  }

  /// Resume game
  void resumeGame() {
    if (phase == GamePhase.paused) {
      phase = GamePhase.playing;
      notifyListeners();
    }
  }

  /// Return to menu
  void returnToMenu() {
    phase = GamePhase.menu;
    notifyListeners();
  }

  /// Get formatted game time
  String get formattedTime {
    final minutes = (gameTime / 60).floor();
    final seconds = (gameTime % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Game phases
enum GamePhase {
  menu,
  playing,
  paused,
  won,
  dead,
}
