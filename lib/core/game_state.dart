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

  // Container search system
  bool isSearching;
  double searchProgress; // 0.0 to 1.0
  InteractiveObject? searchTarget;
  String? searchMessage;

  // Ghost damage flash
  bool damageFlashActive;
  double damageFlashTimer;

  // Crowbar usage
  bool hasCrowbar;

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
    this.isSearching = false,
    this.searchProgress = 0.0,
    this.searchTarget,
    this.searchMessage,
    this.damageFlashActive = false,
    this.damageFlashTimer = 0,
    this.hasCrowbar = false,
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
              searchDuration: obj.searchDuration,
              lootIds: List<String>.from(obj.lootIds),
              makesNoise: obj.makesNoise,
            ))
        .toList();
  }

  /// Initialize a new game
  void startGame() {
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
    isSearching = false;
    searchProgress = 0.0;
    searchTarget = null;
    searchMessage = null;
    damageFlashActive = false;
    damageFlashTimer = 0;
    hasCrowbar = false;
    phase = GamePhase.playing;

    for (final obj in interactiveObjects) {
      obj.isCollected = false;
      obj.isOpened = false;
      obj.isSearched = false;
    }

    _validateSpawnPosition();
    showMessage('Find the keys. Search the rooms. Escape the asylum. Don\'t let her catch you...', duration: 5.0);
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

    gameTime += delta;

    // Update flashlight
    flashlight.update(delta);

    // Ghost flashlight flicker
    if (ghost.horrorIntensity > 0.3 && flashlight.isOn) {
      flashlight.isFlickering = true;
    } else if (ghost.horrorIntensity < 0.1) {
      if (flashlight.batteryLevel >= 20.0) {
        flashlight.isFlickering = false;
      }
    }

    // Update ghost AI
    ghost.update(player, currentMap, delta);

    // Ghost proximity damage
    final ghostDamage = ghost.calculateDamage(player, delta);
    if (ghostDamage > 0) {
      player.health = (player.health - ghostDamage).clamp(0.0, 100.0);
      damageFlashActive = true;
      damageFlashTimer = 0.3;
    }

    // Update damage flash
    if (damageFlashActive) {
      damageFlashTimer -= delta;
      if (damageFlashTimer <= 0) {
        damageFlashActive = false;
        damageFlashTimer = 0;
      }
    }

    // Update camera glitch intensity
    cameraGlitchIntensity = ghost.horrorIntensity;

    // Check if ghost caught the player (instant kill)
    if (ghost.hasCaughtPlayer(player)) {
      killedByGhost = true;
      phase = GamePhase.dead;
      jumpscareActive = true;
      jumpscareTimer = 2.0;
      showMessage('She caught you...', duration: 3.0);
      notifyListeners();
      return;
    }

    // Check if player health reached 0
    if (player.health <= 0) {
      killedByGhost = true;
      phase = GamePhase.dead;
      jumpscareActive = true;
      jumpscareTimer = 2.0;
      showMessage('You collapsed from the horror...', duration: 3.0);
      notifyListeners();
      return;
    }

    // Update search progress
    if (isSearching && searchTarget != null) {
      searchProgress += delta / searchTarget!.searchDuration;
      if (searchProgress >= 1.0) {
        _completeSearch();
      }
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

    _checkWinCondition();
    notifyListeners();
  }

  void _checkNearbyObjects() {
    nearbyObject = null;
    canInteract = false;

    // Don't allow new interactions while searching
    if (isSearching) return;

    for (final obj in interactiveObjects) {
      // Skip collected items and opened doors
      if (obj.isCollected || obj.isOpened) continue;
      // Skip already searched containers
      if (obj.type == InteractionType.container && obj.isSearched) continue;

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
    if (isSearching) return; // Already searching

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
      case InteractionType.container:
        _interactContainer(obj);
        break;
    }

    notifyListeners();
  }

  void _interactDoor(InteractiveObject obj) {
    if (obj.requiredKey != null && !inventory.contains(obj.requiredKey)) {
      // Check if player has crowbar for forced entry
      if (hasCrowbar && obj.id.startsWith('door_basement')) {
        // Crowbar can force open basement door
        obj.isOpened = true;
        final mapX = obj.x.floor();
        final mapY = obj.y.floor();
        if (mapX >= 0 && mapX < GameMap.width && mapY >= 0 && mapY < GameMap.height) {
          currentMap[mapY][mapX] = 0;
        }
        showMessage('Forced open with crowbar!', duration: 2.0);
        score += 50;
        // Forced entry is LOUD - alert ghost
        ghost.alertToNoise(player.x, player.y);
        return;
      }
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

    // Opening doors can alert ghost
    if (Random().nextDouble() < 0.3) {
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
      showMessage('Collected: Battery (+35%)', duration: 2.0);
      score += 25;
    } else if (obj.id.startsWith('key_')) {
      inventory.add(obj.id);
      showMessage('Collected: ${obj.label}', duration: 2.5);
      score += 100;
      ambientIntensity = (ambientIntensity + 0.05).clamp(0.0, 1.0);
      if (Random().nextDouble() < 0.5) {
        ghost.state = GhostState.stalking;
        ghost.stateTimer = 0;
      }
    } else if (obj.id.startsWith('medkit_')) {
      player.health = (player.health + 40.0).clamp(0.0, 100.0);
      showMessage('Used Medkit! (+40 HP)', duration: 2.0);
      score += 30;
    } else if (obj.id == 'crowbar') {
      hasCrowbar = true;
      inventory.add('crowbar');
      showMessage('Collected: Crowbar (can force some doors)', duration: 3.0);
      score += 50;
    }
  }

  void _interactNote(InteractiveObject obj) {
    obj.isCollected = true;
    showNoteOverlay = true;
    noteContent = obj.content;
    noteLabel = obj.label;
    score += 30;
  }

  void _interactContainer(InteractiveObject obj) {
    if (obj.isSearched) return;

    // Start searching
    isSearching = true;
    searchProgress = 0.0;
    searchTarget = obj;
    searchMessage = 'Searching ${obj.label}...';
  }

  /// Complete the container search and give loot
  void _completeSearch() {
    if (searchTarget == null) return;

    final obj = searchTarget!;
    obj.isSearched = true;

    // Give loot items
    final foundItems = <String>[];
    for (final lootId in obj.lootIds) {
      // Skip if already in inventory
      if (inventory.contains(lootId)) continue;

      if (lootId.startsWith('key_')) {
        inventory.add(lootId);
        foundItems.add(lootId.replaceAll('_', ' ').toUpperCase());
        score += 100;
        ambientIntensity = (ambientIntensity + 0.05).clamp(0.0, 1.0);
      } else if (lootId.startsWith('battery_')) {
        flashlight.addBattery(35.0);
        foundItems.add('Battery');
        score += 25;
      } else if (lootId.startsWith('medkit_')) {
        player.health = (player.health + 40.0).clamp(0.0, 100.0);
        foundItems.add('Medkit');
        score += 30;
      } else if (lootId.startsWith('note_')) {
        // Find and show the note
        final noteObj = interactiveObjects.where((o) => o.id == lootId).firstOrNull;
        if (noteObj != null && !noteObj.isCollected) {
          noteObj.isCollected = true;
          showNoteOverlay = true;
          noteContent = noteObj.content;
          noteLabel = noteObj.label;
          foundItems.add(noteObj.label);
          score += 30;
        }
      }
    }

    // Show what was found
    if (foundItems.isNotEmpty) {
      showMessage('Found: ${foundItems.join(', ')}', duration: 3.0);
    } else {
      showMessage('Nothing useful here...', duration: 2.0);
    }

    // Alert ghost if container makes noise
    if (obj.makesNoise) {
      ghost.alertToNoise(obj.x, obj.y);
      // Show warning
      Future.delayed(const Duration(milliseconds: 500), () {
        if (phase == GamePhase.playing) {
          showMessage('... Something heard you ...', duration: 2.0);
        }
      });
    }

    // Reset search state
    isSearching = false;
    searchProgress = 0.0;
    searchTarget = null;
    searchMessage = null;
  }

  /// Cancel the current search (e.g., player moved away)
  void cancelSearch() {
    isSearching = false;
    searchProgress = 0.0;
    searchTarget = null;
    searchMessage = null;
    notifyListeners();
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
        if (ghost.state == GhostState.patrol) {
          ghost.state = GhostState.stalking;
          ghost.stateTimer = 0;
          showMessage('... You hear footsteps behind you ...', duration: 2.5);
        }
        break;
    }
  }

  void _checkWinCondition() {
    final exitX = 30.5;
    final exitY = 30.5;

    final dx = player.x - exitX;
    final dy = player.y - exitY;
    if (sqrt(dx * dx + dy * dy) < 1.5) {
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
