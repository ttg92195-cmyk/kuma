import 'dart:math';
import 'package:flutter/material.dart';

/// Raycasting 3D Engine - First-Person Horror View
/// Supports multiple wall types with procedural texture info
class RaycastEngine {
  static const double fov = 60.0 * pi / 180.0;
  static const double halfFov = fov / 2.0;
  static const int numRays = 240;
  static const double maxDepth = 24.0; // Larger map needs deeper rendering
  static const double stripWidth = 1.0;

  /// Cast all rays and return wall strip data for rendering
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

      final correctedDistance = result.distance * cos(rayAngle - playerAngle);

      final safeDistance = correctedDistance.isNaN || correctedDistance <= 0
          ? 0.01
          : correctedDistance;

      strips.add(WallStrip(
        rayIndex: i,
        distance: safeDistance,
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

  static _RayResult _castSingleRay(
    double playerX,
    double playerY,
    double rayAngle,
    List<List<int>> map,
    int mapWidth,
    int mapHeight,
  ) {
    playerX = playerX.clamp(0.5, mapWidth - 0.5);
    playerY = playerY.clamp(0.5, mapHeight - 0.5);

    final rayDirX = cos(rayAngle);
    final rayDirY = sin(rayAngle);

    int mapX = playerX.floor();
    int mapY = playerY.floor();

    final deltaDistX = (rayDirX == 0) ? 1e30 : (1 / rayDirX).abs();
    final deltaDistY = (rayDirY == 0) ? 1e30 : (1 / rayDirY).abs();

    int stepX, stepY;
    double sideDistX, sideDistY;

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

    int hit = 0;
    int side = 0;
    int wallType = 0;
    int iterations = 0;
    const int maxIterations = 120;

    while (hit == 0 && iterations < maxIterations) {
      iterations++;

      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
        side = 0;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
        side = 1;
      }

      if (mapX < 0 || mapX >= mapWidth || mapY < 0 || mapY >= mapHeight) {
        hit = 1;
        wallType = 1;
      } else if (map[mapY][mapX] > 0) {
        hit = 1;
        wallType = map[mapY][mapX];
      }

      final dist = sqrt(pow(mapX - playerX, 2) + pow(mapY - playerY, 2));
      if (dist > maxDepth) {
        hit = 1;
        wallType = 0;
      }
    }

    if (hit == 0) {
      return _RayResult(
        distance: maxDepth,
        wallType: 0,
        hitX: mapX.toDouble(),
        hitY: mapY.toDouble(),
        side: side,
        textureX: 0,
      );
    }

    double perpWallDist;
    double textureX = 0;

    if (side == 0) {
      perpWallDist = (mapX - playerX + (1 - stepX) / 2) / rayDirX;
      textureX = playerY + perpWallDist * rayDirY;
    } else {
      perpWallDist = (mapY - playerY + (1 - stepY) / 2) / rayDirY;
      textureX = playerX + perpWallDist * rayDirX;
    }

    if (perpWallDist <= 0 || perpWallDist.isNaN || perpWallDist.isInfinite) {
      perpWallDist = 0.01;
    }

    textureX -= textureX.floor();

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

  /// Calculate flashlight intensity - BRIGHTER so walls always visible
  static double calculateFlashlightIntensity(
    double rayAngle,
    double playerAngle,
    double distance,
    bool flashlightOn,
    double coneAngle,
  ) {
    if (!flashlightOn) return 0.28;

    final angleDiff = _normalizeAngle(rayAngle - playerAngle);
    final absAngle = angleDiff.abs();

    if (absAngle > coneAngle) return 0.20;

    final coneFactor = 1.0 - (absAngle / coneAngle) * 0.4;
    final distanceFactor = 1.0 / (1.0 + distance * distance * 0.02);

    return (0.28 + 0.72 * coneFactor * distanceFactor).clamp(0.20, 1.0);
  }

  /// Get wall base color - BRIGHTER for phone visibility
  static Color getWallColor(int wallType, int side, double intensity) {
    Color baseColor;

    switch (wallType) {
      case 1: // Concrete wall
        baseColor = const Color(0xFF8A8A8A);
        break;
      case 2: // Bloody wall
        baseColor = const Color(0xFFB03030);
        break;
      case 3: // Rusty metal wall
        baseColor = const Color(0xFF9A7A5A);
        break;
      case 4: // Door frame
        baseColor = const Color(0xFFAB4545);
        break;
      case 5: // Cracked wall
        baseColor = const Color(0xFF7A7A7A);
        break;
      case 6: // Exit door (green glow)
        baseColor = const Color(0xFF3ABB3A);
        break;
      case 7: // Emergency red wall
        baseColor = const Color(0xFFCC2020);
        break;
      case 8: // Dirty tile wall
        baseColor = const Color(0xFF8A8A7A);
        break;
      case 9: // Brick wall
        baseColor = const Color(0xFF8A6A5A);
        break;
      default:
        baseColor = const Color(0xFF6A6A6A);
    }

    if (side == 1) {
      intensity *= 0.80;
    }

    return Color.lerp(const Color(0xFF000000), baseColor, intensity)!;
  }

  /// Get wall texture pattern type for procedural rendering
  static WallTextureType getWallTexture(int wallType) {
    switch (wallType) {
      case 1: return WallTextureType.concrete;
      case 2: return WallTextureType.bloody;
      case 3: return WallTextureType.rusty;
      case 4: return WallTextureType.doorFrame;
      case 5: return WallTextureType.cracked;
      case 6: return WallTextureType.exitDoor;
      case 7: return WallTextureType.emergency;
      case 8: return WallTextureType.tile;
      case 9: return WallTextureType.brick;
      default: return WallTextureType.concrete;
    }
  }

  static Color getFloorColor(double distance, double intensity) {
    const baseColor = Color(0xFF2A2A30);
    return Color.lerp(const Color(0xFF000000), baseColor, intensity * 0.8)!;
  }

  static Color getCeilingColor(double distance, double intensity) {
    const baseColor = Color(0xFF1A1A22);
    return Color.lerp(const Color(0xFF000000), baseColor, intensity * 0.6)!;
  }

  static double _normalizeAngle(double angle) {
    while (angle > pi) angle -= 2 * pi;
    while (angle < -pi) angle += 2 * pi;
    return angle;
  }
}

/// Wall texture types for procedural rendering
enum WallTextureType {
  concrete,
  bloody,
  rusty,
  doorFrame,
  cracked,
  exitDoor,
  emergency,
  tile,
  brick,
}

class WallStrip {
  final int rayIndex;
  final double distance;
  final double rawDistance;
  final int wallType;
  final double hitX;
  final double hitY;
  final int side;
  final double textureX;
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
