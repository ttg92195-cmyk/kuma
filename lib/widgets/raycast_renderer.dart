import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/raycast_engine.dart';
import '../core/game_state.dart';

/// Main 3D raycasting renderer widget using CustomPainter
class RaycastRenderer extends StatelessWidget {
  final GameState gameState;

  const RaycastRenderer({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RaycastPainter(gameState: gameState),
      size: Size.infinite,
    );
  }
}

/// CustomPainter that renders the 3D raycasting view
class RaycastPainter extends CustomPainter {
  final GameState gameState;

  RaycastPainter({required this.gameState});

  @override
  void paint(Canvas canvas, Size size) {
    final player = gameState.player;
    final flashlight = gameState.flashlight;

    // Cast all rays
    final strips = RaycastEngine.castRays(
      player.x,
      player.y,
      player.angle,
      gameState.currentMap,
      gameState.currentMap[0].length,
      gameState.currentMap.length,
    );

    // Draw ceiling (dark gradient)
    final ceilingPaint = Paint()..color = const Color(0xFF020202);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      ceilingPaint,
    );

    // Draw floor (slightly lighter)
    final floorPaint = Paint()..color = const Color(0xFF080808);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      floorPaint,
    );

    // Render each wall strip
    final stripPixelWidth = size.width / RaycastEngine.numRays;

    for (final strip in strips) {
      if (strip.distance <= 0) continue;

      // Calculate wall height based on distance
      final wallHeight = size.height / strip.distance;

      // Apply head bob
      final bobOffset = player.bobAmount;

      // Wall top and bottom positions
      final wallTop = (size.height / 2 - wallHeight / 2) + bobOffset;
      final wallBottom = (size.height / 2 + wallHeight / 2) + bobOffset;

      // Calculate flashlight intensity for this strip
      final lightIntensity = RaycastEngine.calculateFlashlightIntensity(
        strip.rayAngle,
        player.angle,
        strip.distance,
        flashlight.isOn && !flashlight.isFlickering,
        flashlight.coneAngle * (flashlight.batteryLevel / 100.0).clamp(0.3, 1.0),
      );

      // Get wall color with lighting
      Color wallColor = RaycastEngine.getWallColor(
        strip.wallType,
        strip.side,
        lightIntensity,
      );

      // Add distance fog
      final fogFactor = (1.0 - strip.distance / RaycastEngine.maxDepth)
          .clamp(0.0, 1.0);
      wallColor = Color.lerp(const Color(0xFF000000), wallColor, fogFactor)!;

      // Draw wall strip
      final wallPaint = Paint()..color = wallColor;
      canvas.drawRect(
        Rect.fromLTWH(
          strip.rayIndex * stripPixelWidth,
          wallTop,
          stripPixelWidth + 1,
          wallBottom - wallTop,
        ),
        wallPaint,
      );

      // Add texture pattern effect (horizontal lines for concrete)
      if (strip.wallType == 1 && lightIntensity > 0.1) {
        _drawWallTexture(
          canvas,
          strip,
          wallTop,
          wallBottom,
          stripPixelWidth,
          lightIntensity,
          size,
        );
      }

      // Blood drip effect for bloody walls
      if (strip.wallType == 2 && lightIntensity > 0.05) {
        _drawBloodEffect(
          canvas,
          strip,
          wallTop,
          wallBottom,
          stripPixelWidth,
          lightIntensity,
        );
      }

      // Draw floor gradient (distance-based)
      _drawFloorGradient(
        canvas,
        strip.rayIndex * stripPixelWidth,
        wallBottom,
        stripPixelWidth,
        size.height - wallBottom,
        strip.distance,
        lightIntensity,
      );

      // Draw ceiling gradient
      _drawCeilingGradient(
        canvas,
        strip.rayIndex * stripPixelWidth,
        0,
        stripPixelWidth,
        wallTop,
        strip.distance,
        lightIntensity,
      );
    }

    // Draw interactive object sprites
    _drawObjectSprites(canvas, size, strips, stripPixelWidth);

    // Draw vignette overlay (darker edges)
    _drawVignette(canvas, size);

    // Draw noise/grain overlay for found-footage effect
    _drawNoiseOverlay(canvas, size);

    // Draw jumpscare flash
    if (gameState.jumpscareActive) {
      final jumpPaint = Paint()..color = const Color(0x80FF0000);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        jumpPaint,
      );
    }
  }

  /// Draw wall texture pattern
  void _drawWallTexture(
    Canvas canvas,
    WallStrip strip,
    double wallTop,
    double wallBottom,
    double stripWidth,
    double intensity,
    Size size,
  ) {
    final lineSpacing = (wallBottom - wallTop) / 8;
    if (lineSpacing < 3) return;

    final linePaint = Paint()
      ..color = Color.lerp(
        Colors.transparent,
        const Color(0xFF1A1A1A),
        intensity * 0.3,
      )!
      ..strokeWidth = 1;

    for (var y = wallTop + lineSpacing; y < wallBottom; y += lineSpacing) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        linePaint,
      );
    }
  }

  /// Draw blood drip effect on bloody walls
  void _drawBloodEffect(
    Canvas canvas,
    WallStrip strip,
    double wallTop,
    double wallBottom,
    double stripWidth,
    double intensity,
  ) {
    final rng = math.Random(strip.hitX.toInt() * 100 + strip.hitY.toInt());
    final numDrips = rng.nextInt(3) + 1;

    for (var i = 0; i < numDrips; i++) {
      final dripX = strip.rayIndex * stripWidth + rng.nextDouble() * stripWidth;
      final dripStart = wallTop + (wallBottom - wallTop) * rng.nextDouble() * 0.3;
      final dripLength = (wallBottom - wallTop) * (0.2 + rng.nextDouble() * 0.5);

      final bloodPaint = Paint()
        ..color = Color.lerp(
          Colors.transparent,
          const Color(0xFF660000),
          intensity * 0.6,
        )!;

      canvas.drawRect(
        Rect.fromLTWH(dripX, dripStart, stripWidth * 0.5, dripLength),
        bloodPaint,
      );
    }
  }

  /// Draw floor gradient based on distance
  void _drawFloorGradient(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double distance,
    double intensity,
  ) {
    if (height <= 0) return;

    final floorColor = RaycastEngine.getFloorColor(distance, intensity);
    final paint = Paint()..color = floorColor;
    canvas.drawRect(Rect.fromLTWH(x, y, width + 1, height), paint);
  }

  /// Draw ceiling gradient based on distance
  void _drawCeilingGradient(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double distance,
    double intensity,
  ) {
    if (height <= 0) return;

    final ceilColor = RaycastEngine.getCeilingColor(distance, intensity);
    final paint = Paint()..color = ceilColor;
    canvas.drawRect(Rect.fromLTWH(x, y, width + 1, height), paint);
  }

  /// Draw sprite indicators for interactive objects
  void _drawObjectSprites(
    Canvas canvas,
    Size size,
    List<WallStrip> strips,
    double stripWidth,
  ) {
    for (final obj in gameState.interactiveObjects) {
      if (obj.isCollected || obj.isOpened) continue;

      final dx = obj.x - gameState.player.x;
      final dy = obj.y - gameState.player.y;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance > RaycastEngine.maxDepth || distance < 0.5) continue;

      // Calculate angle to object
      var angleToObj = math.atan2(dy, dx) - gameState.player.angle;
      while (angleToObj > math.pi) angleToObj -= 2 * math.pi;
      while (angleToObj < -math.pi) angleToObj += 2 * math.pi;

      // Check if object is in view
      if (angleToObj.abs() > RaycastEngine.halfFov + 0.1) continue;

      // Screen position
      final screenX = size.width / 2 + (angleToObj / RaycastEngine.halfFov) * (size.width / 2);
      final spriteHeight = size.height / distance * 0.3;
      final spriteWidth = spriteHeight * 0.6;

      // Check if object is behind a wall (simple occlusion)
      final rayIndex = (screenX / stripWidth).floor().clamp(0, strips.length - 1);
      if (strips[rayIndex].distance < distance) continue;

      // Draw sprite based on type
      final spriteY = size.height / 2 - spriteHeight / 2 + gameState.player.bobAmount;

      switch (obj.type) {
        case InteractionType.door:
          _drawDoorSprite(canvas, screenX - spriteWidth / 2, spriteY, spriteWidth, spriteHeight, distance);
          break;
        case InteractionType.item:
          _drawItemSprite(canvas, screenX - spriteWidth / 2, spriteY, spriteWidth, spriteHeight, obj.id, distance);
          break;
        case InteractionType.note:
          _drawNoteSprite(canvas, screenX - spriteWidth / 2, spriteY, spriteWidth, spriteHeight, distance);
          break;
      }
    }
  }

  void _drawDoorSprite(Canvas canvas, double x, double y, double w, double h, double dist) {
    final fogFactor = (1.0 - dist / RaycastEngine.maxDepth).clamp(0.1, 1.0);
    final paint = Paint()
      ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF4A1515), fogFactor)!;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);

    // Door frame
    final framePaint = Paint()
      ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF6B2020), fogFactor)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), framePaint);
  }

  void _drawItemSprite(Canvas canvas, double x, double y, double w, double h, String id, double dist) {
    final fogFactor = (1.0 - dist / RaycastEngine.maxDepth).clamp(0.1, 1.0);
    Color itemColor;
    if (id.startsWith('key_')) {
      itemColor = const Color(0xFFFFD700); // Gold for keys
    } else if (id.startsWith('battery_')) {
      itemColor = const Color(0xFF00FF00); // Green for batteries
    } else {
      itemColor = const Color(0xFFFFFFFF);
    }

    final paint = Paint()
      ..color = Color.lerp(const Color(0xFF000000), itemColor, fogFactor * 0.8)!;

    // Floating item effect
    final floatOffset = math.sin(gameState.gameTime * 3) * 3;
    canvas.drawOval(
      Rect.fromLTWH(x + w * 0.2, y + h * 0.3 + floatOffset, w * 0.6, h * 0.4),
      paint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = Color.lerp(const Color(0x00000000), itemColor.withOpacity(0.3), fogFactor)!;;
    canvas.drawOval(
      Rect.fromLTWH(x, y + h * 0.1 + floatOffset, w, h * 0.8),
      glowPaint,
    );
  }

  void _drawNoteSprite(Canvas canvas, double x, double y, double w, double h, double dist) {
    final fogFactor = (1.0 - dist / RaycastEngine.maxDepth).clamp(0.1, 1.0);
    final paint = Paint()
      ..color = Color.lerp(const Color(0xFF000000), const Color(0xFFD4C5A9), fogFactor)!;

    // Paper-like shape
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.15, y + h * 0.2, w * 0.7, h * 0.6),
      paint,
    );

    // Text lines
    final linePaint = Paint()
      ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF333333), fogFactor)!;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(x + w * 0.25, y + h * 0.35 + i * h * 0.1),
        Offset(x + w * 0.75, y + h * 0.35 + i * h * 0.1),
        linePaint,
      );
    }
  }

  /// Draw vignette (darkened edges for found-footage feel)
  void _drawVignette(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.sqrt(centerX * centerX + centerY * centerY);

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.6,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.3),
          Colors.black.withOpacity(0.7),
          Colors.black.withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  /// Draw noise/grain overlay for found-footage effect
  void _drawNoiseOverlay(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final noisePaint = Paint();

    // Sparse noise particles for performance
    for (var i = 0; i < 200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final alpha = rng.nextDouble() * 0.05;

      noisePaint.color = Colors.white.withOpacity(alpha);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 2, height: 2),
        noisePaint,
      );
    }

    // Scanline effect
    final scanPaint = Paint()..color = Colors.black.withOpacity(0.03);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RaycastPainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}
