import 'dart:math';

/// Game Map / Level Data
/// Map values: 0 = empty, 1 = concrete wall, 2 = bloody wall,
/// 3 = rusty metal, 4 = door frame, 5 = cracked wall, 6 = exit door
class GameMap {
  /// Hospital/Asylum map - narrow corridors and rooms
  static List<List<int>> get hospitalMap => [
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 2, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 1, 2, 4, 1, 0, 0, 0, 0, 1, 1, 4, 1, 1, 0, 1, 1, 1, 4, 1, 1, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 1],
        [1, 0, 0, 0, 1, 1, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
        [1, 0, 0, 0, 3, 0, 0, 3, 0, 0, 3, 0, 0, 3, 0, 0, 1, 1, 4, 1, 1, 0, 0, 1],
        [1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 0, 0, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 4, 0, 0, 2, 0, 0, 2, 0, 0, 4, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 4, 1, 0, 0, 0, 1],
        [1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
        [1, 1, 4, 1, 1, 0, 0, 0, 0, 0, 1, 1, 4, 1, 1, 0, 0, 0, 0, 4, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1],
        [1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 4, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 1],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      ];

  static int get width => 24;
  static int get height => 24;

  static double get spawnX => 1.5;
  static double get spawnY => 1.5;
  static double get spawnAngle => 0.0;

  static List<InteractiveObject> get objects => [
        InteractiveObject(
          x: 7.5, y: 12.0, type: InteractionType.door,
          id: 'door_main_hall', label: 'Main Hall Door', requiredKey: 'key_rusty',
        ),
        InteractiveObject(
          x: 15.5, y: 6.0, type: InteractionType.door,
          id: 'door_storage', label: 'Storage Room Door',
        ),
        InteractiveObject(
          x: 5.5, y: 15.0, type: InteractionType.door,
          id: 'door_basement', label: 'Basement Door', requiredKey: 'key_rusty',
        ),
        InteractiveObject(
          x: 19.5, y: 17.0, type: InteractionType.door,
          id: 'door_exit_hall', label: 'Exit Hall Door', requiredKey: 'key_master',
        ),
        InteractiveObject(
          x: 2.0, y: 6.0, type: InteractionType.item,
          id: 'key_rusty', label: 'Rusty Key',
        ),
        InteractiveObject(
          x: 11.0, y: 1.5, type: InteractionType.item,
          id: 'key_master', label: 'Master Key',
        ),
        InteractiveObject(
          x: 13.0, y: 1.5, type: InteractionType.item,
          id: 'battery_1', label: 'Battery',
        ),
        InteractiveObject(
          x: 1.5, y: 21.0, type: InteractionType.item,
          id: 'battery_2', label: 'Battery',
        ),
        InteractiveObject(
          x: 11.5, y: 8.0, type: InteractionType.item,
          id: 'battery_3', label: 'Battery',
        ),
        InteractiveObject(
          x: 3.5, y: 11.5, type: InteractionType.note,
          id: 'note_1', label: 'Torn Note',
          content: 'Day 47... The experiments continue. I can hear them at night. '
              'Scratching behind the walls. They never stop. If you find this, '
              'get out while you still can. The key is in the storage room... '
              'I think. My memory fades...',
        ),
        InteractiveObject(
          x: 17.5, y: 11.5, type: InteractionType.note,
          id: 'note_2', label: 'Blood-stained Note',
          content: 'THE BASEMENT. DO NOT GO TO THE BASEMENT. '
              'Unless you have the master key. The exit is through there. '
              'I can hear the door... it won\'t stop opening on its own. '
              'God help us all.',
        ),
        InteractiveObject(
          x: 7.5, y: 22.5, type: InteractionType.item,
          id: 'battery_4', label: 'Battery',
        ),
      ];

  static bool isWalkable(double x, double y, List<List<int>> map) {
    final mapX = x.floor();
    final mapY = y.floor();
    if (mapX < 0 || mapX >= width || mapY < 0 || mapY >= height) return false;
    return map[mapY][mapX] == 0;
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

  bool isInRange(double playerX, double playerY, {double range = 1.5}) {
    final dx = playerX - x;
    final dy = playerY - y;
    return sqrt(dx * dx + dy * dy) < range;
  }
}
