import 'dart:math';

/// Game Map / Level Data - ABANDONED ASYLUM with themed rooms
/// Map values: 0 = empty, 1 = concrete (lobby), 2 = bloody (OR),
/// 3 = rusty metal, 4 = door frame, 5 = cracked wall, 6 = exit door,
/// 7 = emergency red wall, 8 = dirty tile (office/pharmacy), 9 = brick (basement),
/// 10 = morgue locker wall, 11 = ICU blue tile, 12 = operating room tile
class GameMap {
  /// Large Asylum Maze Map (32x32) with themed room areas:
  /// Top-left: Lobby/Entrance (wall 1)
  /// Top-right: ICU Ward (wall 11)
  /// Mid-left: Doctor Office (wall 8)
  /// Center: Operating Room (wall 12)
  /// Mid-right: Pharmacy (wall 8)
  /// Bottom-left: Basement (wall 9)
  /// Bottom-center: Morgue (wall 10)
  /// Bottom-right: Exit area (wall 6)
  static List<List<int>> get hospitalMap => [
    // Row 0 - Top wall
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    // Row 1 - Lobby entrance (wall 1 = concrete/lobby)
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,11, 0, 0, 0,11, 0, 0, 0,11, 0, 0,11],
    // Row 2 - Lobby + ICU rooms
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,11, 0, 0, 0,11, 0, 0, 0,11, 0, 0,11],
    // Row 3 - Lobby exit corridor
    [1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0,11],
    // Row 4 - Corridor dividing wall
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1,11, 1, 1, 1,11, 1, 1, 1,11, 1, 1,11],
    // Row 5 - Main corridor (LONG)
    [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 6 - Corridor
    [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 7 - Doctor Office / Pharmacy wall
    [1, 1, 4, 1, 1, 0, 0, 1, 8, 8, 4, 8, 1, 0, 0, 8, 8, 4, 8, 8, 1, 0, 0, 1, 1, 4, 1, 1, 1, 1, 1, 1],
    // Row 8 - Doctor Office interior / Pharmacy
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 9 - Office rooms
    [1, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 10 - Office rooms
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 11 - Operating Room wall
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 0, 0,12,12, 4,12,12, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1],
    // Row 12 - Central LONG corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 13 - Central corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 14 - OR interior walls
    [1, 1, 1, 4, 1, 0, 0, 1,12,12,12,12, 1, 0, 0,12, 0, 0,12, 1, 1, 1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    // Row 15 - Operating Room (bloody OR)
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,12, 0, 0,12, 0, 0,12, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 16 - OR with blood
    [1, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 2, 0, 0, 2, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 17 - OR interior
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,12, 0, 0,12, 0, 0,12, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 18 - OR bottom wall
    [1, 1, 1, 1, 1, 0, 0, 1,12,12,12,12, 1, 0, 0,12,12,12,12, 1, 1, 1, 1, 1, 0, 0, 4, 1, 1, 1, 1, 1],
    // Row 19 - Lower corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 20 - Lower corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 21 - Morgue entrance wall
    [1, 1, 1, 4, 1, 0, 0, 1, 1, 1, 1, 1, 4, 0, 0,10,10, 4,10,10, 1, 1, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1],
    // Row 22 - Morgue interior
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 23 - Morgue (locker walls)
    [1, 0, 0, 0,10, 0, 0, 0, 0,10, 0, 0,10, 0, 0, 0, 0,10, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 24 - Morgue
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 25 - Basement entrance
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 0, 0,10,10,10, 1, 1, 1, 1, 1, 1, 1, 0, 0, 9, 9, 9, 9, 1],
    // Row 26 - Basement corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 27 - Basement rooms
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 28 - Deep basement walls
    [1, 9, 4, 9, 9, 0, 0, 9, 9, 9, 9, 4, 9, 0, 0, 9, 9, 9, 9, 4, 9, 0, 0, 9, 9, 9, 9, 9, 9, 0, 9, 1],
    // Row 29 - Deep basement
    [1, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 9, 0, 9, 1],
    // Row 30 - Exit corridor
    [1, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 9, 6, 9, 1],
    // Row 31 - Bottom wall
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  static int get width => 32;
  static int get height => 32;

  // Spawn in the lobby (top-left corner)
  static double get spawnX => 2.5;
  static double get spawnY => 2.5;
  static double get spawnAngle => 0.0; // Face east

  /// Interactive objects for the themed asylum map
  static List<InteractiveObject> get objects => [
    // === KEYS (progression chain: Lobby → Office → OR → Morgue → Exit) ===
    InteractiveObject(
      x: 3.5, y: 9.0,
      type: InteractionType.item,
      id: 'key_office', label: 'Office Key',
    ),
    InteractiveObject(
      x: 10.5, y: 16.0,
      type: InteractionType.item,
      id: 'key_or', label: 'OR Room Key',
    ),
    InteractiveObject(
      x: 25.5, y: 16.0,
      type: InteractionType.item,
      id: 'key_morgue', label: 'Morgue Key',
    ),
    InteractiveObject(
      x: 17.5, y: 23.0,
      type: InteractionType.item,
      id: 'key_exit', label: 'Exit Key',
    ),

    // === CROWBAR (force open broken doors) ===
    InteractiveObject(
      x: 6.5, y: 1.5,
      type: InteractionType.item,
      id: 'crowbar', label: 'Crowbar',
    ),

    // === DOORS (with key requirements for progression) ===
    InteractiveObject(
      x: 4.0, y: 3.0,
      type: InteractionType.door,
      id: 'door_lobby', label: 'Lobby Exit Door',
    ),
    InteractiveObject(
      x: 9.0, y: 7.0,
      type: InteractionType.door,
      id: 'door_office', label: 'Doctor Office',
      requiredKey: 'key_office',
    ),
    InteractiveObject(
      x: 17.0, y: 7.0,
      type: InteractionType.door,
      id: 'door_pharmacy', label: 'Pharmacy Door',
      requiredKey: 'key_office',
    ),
    InteractiveObject(
      x: 9.0, y: 11.0,
      type: InteractionType.door,
      id: 'door_or', label: 'Operating Room',
      requiredKey: 'key_or',
    ),
    InteractiveObject(
      x: 25.0, y: 11.0,
      type: InteractionType.door,
      id: 'door_icu_exit', label: 'ICU Corridor Door',
    ),
    InteractiveObject(
      x: 12.0, y: 14.0,
      type: InteractionType.door,
      id: 'door_or_inner', label: 'OR Inner Door',
      requiredKey: 'key_or',
    ),
    InteractiveObject(
      x: 27.0, y: 18.0,
      type: InteractionType.door,
      id: 'door_morgue', label: 'Morgue Door',
      requiredKey: 'key_morgue',
    ),
    InteractiveObject(
      x: 9.0, y: 21.0,
      type: InteractionType.door,
      id: 'door_basement', label: 'Basement Stairs',
    ),
    InteractiveObject(
      x: 30.0, y: 30.0,
      type: InteractionType.door,
      id: 'door_exit', label: 'EXIT Door',
      requiredKey: 'key_exit',
    ),

    // === CONTAINERS (searchable drawers, cabinets, lockers) ===
    // Doctor Office - Desk drawer
    InteractiveObject(
      x: 9.5, y: 9.0,
      type: InteractionType.container,
      id: 'drawer_office_1', label: 'Office Desk',
      searchDuration: 2.0,
      lootIds: ['key_or', 'battery_3'],
      makesNoise: false,
    ),
    // Pharmacy - Medicine cabinet
    InteractiveObject(
      x: 17.5, y: 9.0,
      type: InteractionType.container,
      id: 'cabinet_pharmacy', label: 'Medicine Cabinet',
      searchDuration: 1.5,
      lootIds: ['medkit_1', 'battery_4'],
      makesNoise: false,
    ),
    // Operating Room - Supply cabinet
    InteractiveObject(
      x: 10.5, y: 15.5,
      type: InteractionType.container,
      id: 'cabinet_or', label: 'Surgical Cabinet',
      searchDuration: 2.5,
      lootIds: ['key_morgue', 'medkit_2'],
      makesNoise: true, // Searching this is LOUD
    ),
    // Morgue - Body drawer 1
    InteractiveObject(
      x: 10.5, y: 22.5,
      type: InteractionType.container,
      id: 'morgue_drawer_1', label: 'Morgue Drawer A',
      searchDuration: 3.0,
      lootIds: ['battery_5'],
      makesNoise: true, // Very loud!
    ),
    // Morgue - Body drawer 2 (has the exit key!)
    InteractiveObject(
      x: 17.5, y: 23.5,
      type: InteractionType.container,
      id: 'morgue_drawer_2', label: 'Morgue Drawer B',
      searchDuration: 3.5,
      lootIds: ['key_exit', 'note_morgue'],
      makesNoise: true,
    ),
    // ICU - Patient cabinet
    InteractiveObject(
      x: 23.5, y: 2.0,
      type: InteractionType.container,
      id: 'cabinet_icu', label: 'ICU Cabinet',
      searchDuration: 2.0,
      lootIds: ['battery_6', 'medkit_3'],
      makesNoise: false,
    ),
    // Basement storage
    InteractiveObject(
      x: 5.5, y: 27.0,
      type: InteractionType.container,
      id: 'crate_basement', label: 'Storage Crate',
      searchDuration: 2.0,
      lootIds: ['battery_7', 'medkit_4'],
      makesNoise: true,
    ),
    // Lobby reception desk
    InteractiveObject(
      x: 11.5, y: 1.5,
      type: InteractionType.container,
      id: 'drawer_reception', label: 'Reception Desk',
      searchDuration: 1.5,
      lootIds: ['key_office', 'note_reception'],
      makesNoise: false,
    ),

    // === BATTERIES (scattered for flashlight) ===
    InteractiveObject(
      x: 6.5, y: 5.5,
      type: InteractionType.item,
      id: 'battery_1', label: 'Battery',
    ),
    InteractiveObject(
      x: 15.5, y: 12.5,
      type: InteractionType.item,
      id: 'battery_2', label: 'Battery',
    ),
    InteractiveObject(
      x: 28.5, y: 5.0,
      type: InteractionType.item,
      id: 'battery_3', label: 'Battery', // Also in container
    ),
    InteractiveObject(
      x: 3.5, y: 19.0,
      type: InteractionType.item,
      id: 'battery_4', label: 'Battery', // Also in container
    ),
    InteractiveObject(
      x: 22.5, y: 26.0,
      type: InteractionType.item,
      id: 'battery_5', label: 'Battery', // Also in container
    ),

    // === MEDIKITS ===
    InteractiveObject(
      x: 1.5, y: 15.0,
      type: InteractionType.item,
      id: 'medkit_1', label: 'Medkit',
    ),
    InteractiveObject(
      x: 26.5, y: 12.0,
      type: InteractionType.item,
      id: 'medkit_2', label: 'Medkit',
    ),
    InteractiveObject(
      x: 15.5, y: 26.0,
      type: InteractionType.item,
      id: 'medkit_3', label: 'Medkit',
    ),
    InteractiveObject(
      x: 7.5, y: 22.0,
      type: InteractionType.item,
      id: 'medkit_4', label: 'Medkit',
    ),

    // === NOTES (story and hints) ===
    InteractiveObject(
      x: 2.5, y: 9.0,
      type: InteractionType.note,
      id: 'note_1', label: 'Reception Log',
      content: 'October 15, 1998. All visitors must sign in at the front desk. '
          'Ward A is closed for renovation. Doctor Kim\'s office has the Ward B key. '
          'The ICU patients have been... restless. Strange sounds at night.',
    ),
    InteractiveObject(
      x: 17.5, y: 10.0,
      type: InteractionType.note,
      id: 'note_2', label: 'Prescription Note',
      content: 'The experimental sedatives are in the pharmacy cabinet. '
          'Subject 7 needs double dosage now. The Operating Room key is in my desk drawer. '
          'Whatever you do, do NOT enter the OR alone at night.',
    ),
    InteractiveObject(
      x: 10.5, y: 17.0,
      type: InteractionType.note,
      id: 'note_3', label: 'Blood-stained Log',
      content: 'The surgery went wrong. Subject 7 woke up during the procedure. '
          'She... she ripped out the tubes. The Morgue key was on the surgical tray. '
          'I can hear her screaming. Not screaming... LAUGHING. God help us.',
    ),
    InteractiveObject(
      x: 5.5, y: 26.0,
      type: InteractionType.note,
      id: 'note_morgue', label: 'Crumpled Note',
      content: 'She walks these halls now. The girl they experimented on. '
          'She can sense your flashlight. If it flickers... RUN. '
          'The exit key is in Morgue Drawer B. I could hear it moving in there. '
          'Find it. Escape. Before she finds you.',
    ),
    InteractiveObject(
      x: 9.5, y: 1.5,
      type: InteractionType.note,
      id: 'note_reception', label: 'Torn Reception Note',
      content: 'DAY 1: New job at Kuma Asylum. Everything seems normal.\n'
          'DAY 14: The screams from Ward B. They say it\'s nothing.\n'
          'DAY 30: Doctor Kim hasn\'t come out of his office in days.\n'
          'DAY 47: I found blood in the hallway. The OR key is missing.\n'
          'DAY ???: I can\'t remember how long it\'s been. She watches me.',
    ),
  ];

  /// Check if a position is walkable
  static bool isWalkable(double x, double y, List<List<int>> map) {
    const buffer = 0.2;
    for (final dx in [-buffer, buffer]) {
      for (final dy in [-buffer, buffer]) {
        final mapX = (x + dx).floor();
        final mapY = (y + dy).floor();
        if (mapX < 0 || mapX >= width || mapY < 0 || mapY >= height) return false;
        if (map[mapY][mapX] != 0) return false;
      }
    }
    return true;
  }

  static int getWallAt(double x, double y, List<List<int>> map) {
    final mapX = x.floor();
    final mapY = y.floor();
    if (mapX < 0 || mapX >= width || mapY < 0 || mapY >= height) return 1;
    return map[mapY][mapX];
  }
}

enum InteractionType { door, item, note, container }

class InteractiveObject {
  final double x;
  final double y;
  final InteractionType type;
  final String id;
  final String label;
  final String? requiredKey;
  final String? content;

  // Container-specific fields
  final double searchDuration; // seconds to search (0 = instant)
  final List<String> lootIds; // items found when searched
  final bool makesNoise; // whether searching alerts ghost

  bool isCollected;
  bool isOpened;
  bool isSearched;

  InteractiveObject({
    required this.x,
    required this.y,
    required this.type,
    required this.id,
    required this.label,
    this.requiredKey,
    this.content,
    this.searchDuration = 0,
    this.lootIds = const [],
    this.makesNoise = false,
    this.isCollected = false,
    this.isOpened = false,
    this.isSearched = false,
  });

  bool isInRange(double playerX, double playerY, {double range = 2.0}) {
    final dx = playerX - x;
    final dy = playerY - y;
    return sqrt(dx * dx + dy * dy) < range;
  }
}
