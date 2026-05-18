import 'dart:math';

/// Game Map / Level Data - LARGE Abandoned Asylum
/// Map values: 0 = empty, 1 = concrete wall, 2 = bloody wall,
/// 3 = rusty metal, 4 = door frame, 5 = cracked wall, 6 = exit door,
/// 7 = emergency red wall, 8 = dirty tile wall, 9 = brick wall
class GameMap {
  /// Large Asylum Maze Map (32x32) - Much bigger and scarier
  /// Features: Long corridors, dead ends, multiple rooms, hiding spots
  static List<List<int>> get hospitalMap => [
    // Row 0 - Top wall
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    // Row 1 - Start room + corridor
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 2 - Start room + side rooms
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 3 - Start room exit + long corridor
    [1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 4 - Cross corridor
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 2, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    // Row 5 - Main corridor (LONG)
    [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 6 - Side rooms
    [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 7 - Corridor walls
    [1, 1, 4, 1, 1, 0, 0, 1, 1, 1, 4, 1, 1, 0, 0, 1, 1, 2, 1, 1, 4, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 1],
    // Row 8 - Patient rooms top
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 5, 5, 5, 1],
    // Row 9 - Patient rooms
    [1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 5, 0, 5, 1],
    // Row 10 - Patient rooms corridor
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 5, 0, 5, 1],
    // Row 11 - Door row
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 0, 0, 1, 1, 1, 4, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 4, 1, 1],
    // Row 12 - Central LONG corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 13 - Central corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 14 - Walls with doors
    [1, 1, 1, 4, 1, 0, 0, 1, 1, 1, 1, 4, 1, 0, 0, 9, 9, 9, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 1, 1, 1],
    // Row 15 - Lab rooms
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
    // Row 16 - Lab rooms
    [1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1],
    // Row 17 - Lab rooms corridor
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
    // Row 18 - Door row
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 4, 1, 1, 1, 1, 1, 1, 1, 1],
    // Row 19 - Lower corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 20 - Lower corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 21 - Isolation ward entrance
    [1, 1, 1, 4, 1, 0, 0, 1, 1, 1, 1, 1, 4, 0, 0, 1, 1, 7, 1, 1, 1, 0, 0, 1, 1, 1, 4, 1, 1, 1, 1, 1],
    // Row 22 - Isolation ward
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 23 - Isolation ward (bloody)
    [1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 24 - Isolation ward
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 25 - Deep basement entrance
    [1, 1, 1, 1, 1, 0, 0, 1, 1, 4, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 9, 9, 9, 1],
    // Row 26 - Basement corridor
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 27 - Basement rooms
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    // Row 28 - Basement walls
    [1, 1, 4, 1, 1, 0, 0, 3, 3, 3, 1, 1, 1, 0, 0, 1, 1, 1, 1, 4, 1, 0, 0, 1, 1, 1, 1, 1, 9, 0, 9, 1],
    // Row 29 - Exit area
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 9, 0, 9, 1],
    // Row 30 - Exit corridor
    [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 9, 6, 9, 1],
    // Row 31 - Bottom wall
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  static int get width => 32;
  static int get height => 32;

  // Spawn in the small start room (top-left corner)
  static double get spawnX => 2.5;
  static double get spawnY => 2.5;
  static double get spawnAngle => 0.0; // Face east

  /// Interactive objects for the LARGE asylum map
  static List<InteractiveObject> get objects => [
    // === KEYS (must find to progress) ===
    InteractiveObject(
      x: 9.5, y: 9.0,
      type: InteractionType.item,
      id: 'key_ward_b', label: 'Ward B Key',
    ),
    InteractiveObject(
      x: 24.5, y: 16.0,
      type: InteractionType.item,
      id: 'key_master', label: 'Master Key',
    ),
    InteractiveObject(
      x: 16.5, y: 26.0,
      type: InteractionType.item,
      id: 'key_exit', label: 'Exit Key',
    ),

    // === DOORS ===
    InteractiveObject(
      x: 4.0, y: 3.0,
      type: InteractionType.door,
      id: 'door_ward_a', label: 'Ward A Door',
    ),
    InteractiveObject(
      x: 12.0, y: 3.0,
      type: InteractionType.door,
      id: 'door_ward_b', label: 'Ward B Door',
      requiredKey: 'key_ward_b',
    ),
    InteractiveObject(
      x: 20.0, y: 3.0,
      type: InteractionType.door,
      id: 'door_storage', label: 'Storage Room Door',
    ),
    InteractiveObject(
      x: 9.0, y: 11.0,
      type: InteractionType.door,
      id: 'door_lab', label: 'Laboratory Door',
    ),
    InteractiveObject(
      x: 18.0, y: 11.0,
      type: InteractionType.door,
      id: 'door_morgue', label: 'Morgue Door',
    ),
    InteractiveObject(
      x: 12.0, y: 14.0,
      type: InteractionType.door,
      id: 'door_isolation', label: 'Isolation Ward Door',
      requiredKey: 'key_master',
    ),
    InteractiveObject(
      x: 23.0, y: 18.0,
      type: InteractionType.door,
      id: 'door_basement', label: 'Basement Door',
    ),
    InteractiveObject(
      x: 30.0, y: 30.0,
      type: InteractionType.door,
      id: 'door_exit', label: 'EXIT Door',
      requiredKey: 'key_exit',
    ),

    // === BATTERIES ===
    InteractiveObject(
      x: 6.5, y: 1.5,
      type: InteractionType.item,
      id: 'battery_1', label: 'Battery',
    ),
    InteractiveObject(
      x: 16.5, y: 5.5,
      type: InteractionType.item,
      id: 'battery_2', label: 'Battery',
    ),
    InteractiveObject(
      x: 25.5, y: 6.0,
      type: InteractionType.item,
      id: 'battery_3', label: 'Battery',
    ),
    InteractiveObject(
      x: 3.5, y: 13.0,
      type: InteractionType.item,
      id: 'battery_4', label: 'Battery',
    ),
    InteractiveObject(
      x: 28.5, y: 15.0,
      type: InteractionType.item,
      id: 'battery_5', label: 'Battery',
    ),
    InteractiveObject(
      x: 8.5, y: 22.0,
      type: InteractionType.item,
      id: 'battery_6', label: 'Battery',
    ),
    InteractiveObject(
      x: 26.5, y: 27.0,
      type: InteractionType.item,
      id: 'battery_7', label: 'Battery',
    ),

    // === NOTES ===
    InteractiveObject(
      x: 2.5, y: 9.0,
      type: InteractionType.note,
      id: 'note_1', label: 'Torn Note',
      content: 'Day 47... The experiments continue. I can hear them at night. '
          'Scratching behind the walls. They never stop. If you find this, '
          'get out while you still can. The Ward B key is somewhere in the patient rooms... '
          'I think. My memory fades...',
    ),
    InteractiveObject(
      x: 17.5, y: 9.0,
      type: InteractionType.note,
      id: 'note_2', label: 'Blood-stained Note',
      content: 'THE ISOLATION WARD. DO NOT GO THERE. '
          'Unless you have the Master Key. The exit is through the basement. '
          'I can hear the door... it won\'t stop opening on its own. '
          'God help us all. The Master Key is in the lab area somewhere.',
    ),
    InteractiveObject(
      x: 16.5, y: 19.0,
      type: InteractionType.note,
      id: 'note_3', label: 'Doctor\'s Log',
      content: 'Subject 7 has escaped containment. Security protocol failed. '
          'All personnel must evacuate immediately. The exit key has been moved '
          'to the deep basement storage area. Do NOT engage the subject. '
          'It does not respond to reason anymore. Turn off your flashlight if you hear footsteps.',
    ),
    InteractiveObject(
      x: 5.5, y: 26.0,
      type: InteractionType.note,
      id: 'note_4', label: 'Crumpled Note',
      content: 'She walks these halls now. The girl they experimented on. '
          'She can sense your flashlight. If it flickers... RUN. '
          'Don\'t look back. The exit is at the bottom of the building. '
          'You need the Exit Key. I left it in the basement but... '
          'something moved it. Find it. Escape. Before she finds you.',
    ),
  ];

  /// Check if a position is walkable
  /// Uses a small buffer around the player to prevent wall clipping
  static bool isWalkable(double x, double y, List<List<int>> map) {
    const buffer = 0.2; // Collision buffer

    // Check all four corners of the player's bounding box
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

enum InteractionType { door, item, note }

class InteractiveObject {
  final double x;
  final double y;
  final InteractionType type;
  final String id;
  final String label;
  final String? requiredKey;
  final String? content;
  bool isCollected;
  bool isOpened;

  InteractiveObject({
    required this.x,
    required this.y,
    required this.type,
    required this.id,
    required this.label,
    this.requiredKey,
    this.content,
    this.isCollected = false,
    this.isOpened = false,
  });

  bool isInRange(double playerX, double playerY, {double range = 2.0}) {
    final dx = playerX - x;
    final dy = playerY - y;
    return sqrt(dx * dx + dy * dy) < range;
  }
}
