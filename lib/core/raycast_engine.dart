import 'dart:math';
import 'dart:ui';

/// Raycasting 3D Engine - First-Person Horror View
/// Wolfenstein/Doom style raycasting renderer for Flutter
class RaycastEngine {
  static const double fov = 60.0 * pi / 180.0; // Field of View
  static const double halfFov = fov / 2.0;
  static const int numRays = 320; // Number of rays to cast
  static const double maxDepth = 20.0; // Maximum rendering depth
  static const double stripWidth = 1.0; // Width of each ray strip

  /// Cast all rays and return wall strip data for rendering
  /// [playerX], [playerY] - player position in map coordinates
  /// [playerAngle] - player facing direction in radians
  /// [map] - 2D map grid (0 = empty, 1+ = wall type)
  /// [mapWidth], [mapHeight] - map dimensions
  static List<WallStrip> castRays(
    double playerX,
    double playerY,
    double playerAngle,
    List<List<int>> map,
    int mapWidth,
    int mapHeight,
  ) {
    final strips = <WallStrip>[];

    for (int i = 0; i < numRays; i++) {
      final rayAngle = playerAngle - halfFov + (i / numRays) * fov;

      final result = _castSingleRay(
        playerX,
        playerY,
        rayAngle,
        map,
        mapWidth,
        mapHeight,
      );

      // Fix fisheye effect
      final correctedDistance = result.distance * cos(rayAngle - playerAngle);

      strips.add(WallStrip(
        rayIndex: i,
        distance: correctedDistance,
        rawDistance: result.distance,
        wallType: result.wallType,
        hitX: result.hitX,
        hitY: result.hitY,
        side: result.side,
        textureX: result.textureX,
        rayAngle: rayAngle,
      ));
    }

    return strips;
  }

  /// Cast a single ray using DDA (Digital Differential Analyzer) algorithm
  static _RayResult _castSingleRay(
    double playerX,
    double playerY,
    double rayAngle,
    List<List<int>> map,
    int mapWidth,
    int mapHeight,
  ) {
    final rayDirX = cos(rayAngle);
    final rayDirY = sin(rayAngle);

    int mapX = playerX.floor();
    int mapY = playerY.floor();

    // Delta distances
    final deltaDistX = (rayDirX == 0) ? 1e30 : (1 / rayDirX).abs();
    final deltaDistY = (rayDirY == 0) ? 1e30 : (1 / rayDirY).abs();

    int stepX;
    int stepY;
    double sideDistX;
    double sideDistY;

    // Calculate step and initial sideDist
    if (rayDirX < 0) {
      stepX = -1;
      sideDistX = (playerX - mapX) * deltaDistX;
    } else {
      stepX = 1;
      sideDistX = (mapX + 1.0 - playerX) * deltaDistX;
    }

    if (rayDirY < 0) {
      stepY = -1;
      sideDistY = (playerY - mapY) * deltaDistY;
    } else {
      stepY = 1;
      sideDistY = (mapY + 1.0 - playerY) * deltaDistY;
    }

    // DDA
    int hit = 0;
    int side = 0; // 0 = x-side hit, 1 = y-side hit
    int wallType = 0;

    while (hit == 0) {
      // Jump to next map square
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
        side = 0;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
        side = 1;
      }

      // Check if ray has hit a wall
      if (mapX < 0 || mapX >= mapWidth || mapY < 0 || mapY >= mapHeight) {
        hit = 1;
        wallType = 1;
      } else if (map[mapY][mapX] > 0) {
        hit = 1;
        wallType = map[mapY][mapX];
      }

      // Max depth check
      final dist = sqrt(pow(mapX - playerX, 2) + pow(mapY - playerY, 2));
      if (dist > maxDepth) {
        hit = 1;
        wallType = 0;
      }
    }

    // Calculate distance
    double perpWallDist;
    double textureX = 0;

    if (side == 0) {
      perpWallDist = (mapX - playerX + (1 - stepX) / 2) / rayDirX;
      textureX = playerY + perpWallDist * rayDirY;
    } else {
      perpWallDist = (mapY - playerY + (1 - stepY) / 2) / rayDirY;
      textureX = playerX + perpWallDist * rayDirX;
    }

    textureX -= textureX.floor(); // Get fractional part for texture mapping

    // Flip texture if needed
    if ((side == 0 && rayDirX > 0) || (side == 1 && rayDirY < 0)) {
      textureX = 1.0 - textureX;
    }

    return _RayResult(
      distance: perpWallDist,
      wallType: wallType,
      hitX: mapX.toDouble(),
      hitY: mapY.toDouble(),
      side: side,
      textureX: textureX,
    );
  }

  /// Calculate flashlight intensity for a given wall strip
  /// Returns 0.0 to 1.0 based on angle from center and distance
  static double calculateFlashlightIntensity(
    double rayAngle,
    double playerAngle,
    double distance,
    bool flashlightOn,
    double coneAngle,
  ) {
    if (!flashlightOn) return 0.03; // Very dim ambient light

    final angleDiff = _normalizeAngle(rayAngle - playerAngle);
    final absAngle = angleDiff.abs();

    // Outside flashlight cone
    if (absAngle > coneAngle / 2) return 0.03;

    // Within cone - intensity falls off from center
    final coneFactor = 1.0 - (absAngle / (coneAngle / 2));
    final distanceFactor = 1.0 / (1.0 + distance * distance * 0.1);

    return (0.15 + 0.85 * coneFactor * distanceFactor).clamp(0.03, 1.0);
  }

  /// Calculate color for a wall based on wall type, side, and lighting
  static Color getWallColor(int wallType, int side, double intensity) {
    Color baseColor;

    switch (wallType) {
      case 1: // Dark concrete wall
        baseColor = const Color(0xFF2A2A2A);
        break;
      case 2: // Bloody wall
        baseColor = const Color(0xFF3D1010);
        break;
      case 3: // Rusty metal wall
        baseColor = const Color(0xFF3D2A1A);
        break;
      case 4: // Door frame (red tint)
        baseColor = const Color(0xFF4A1515);
        break;
      case 5: // Cracked wall
        baseColor = const Color(0xFF252525);
        break;
      default:
        baseColor = const Color(0xFF1A1A1A);
    }

    // Side shading (y-side walls are slightly darker)
    if (side == 1) {
      intensity *= 0.7;
    }

    return Color.lerp(Colors.black, baseColor, intensity)!;
  }

  /// Calculate floor color for a given position
  static Color getFloorColor(double distance, double intensity) {
    const baseColor = Color(0xFF0D0D0D);
    return Color.lerp(Colors.black, baseColor, intensity * 0.5)!;
  }

  /// Calculate ceiling color for a given position
  static Color getCeilingColor(double distance, double intensity) {
    const baseColor = Color(0xFF050505);
    return Color.lerp(Colors.black, baseColor, intensity * 0.3)!;
  }

  static double _normalizeAngle(double angle) {
    while (angle > pi) angle -= 2 * pi;
    while (angle < -pi) angle += 2 * pi;
    return angle;
  }
}

/// Data class for a single wall strip (vertical column)
class WallStrip {
  final int rayIndex;
  final double distance; // Corrected distance (fisheye fixed)
  final double rawDistance; // Raw distance
  final int wallType;
  final double hitX;
  final double hitY;
  final int side; // 0 = x-side, 1 = y-side
  final double textureX; // Texture coordinate (0.0 to 1.0)
  final double rayAngle;

  const WallStrip({
    required this.rayIndex,
    required this.distance,
    required this.rawDistance,
    required this.wallType,
    required this.hitX,
    required this.hitY,
    required this.side,
    required this.textureX,
    required this.rayAngle,
  });
}

class _RayResult {
  final double distance;
  final int wallType;
  final double hitX;
  final double hitY;
  final int side;
  final double textureX;

  const _RayResult({
    required this.distance,
    required this.wallType,
    required this.hitX,
    required this.hitY,
    required this.side,
    required this.textureX,
  });
}
