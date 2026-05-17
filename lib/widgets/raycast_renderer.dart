import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/raycast_engine.dart';
import '../core/game_state.dart';
import '../core/game_map.dart' show InteractionType;

/// Main 3D raycasting renderer widget
/// CRITICAL FIX: Uses StatefulWidget with Ticker for reliable continuous rendering.
/// The old StatelessWidget approach relied on Consumer rebuilds which were unreliable.
class RaycastRenderer extends StatefulWidget {
  final GameState gameState;

  const RaycastRenderer({super.key, required this.gameState});

  @override
  State<RaycastRenderer> createState() => _RaycastRendererState();
}

class _RaycastRendererState extends State<RaycastRenderer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _frameCount = 0;
  double _fps = 0;
  DateTime _lastFpsTime = DateTime.now();
  int _fpsFrameCount = 0;

  @override
  void initState() {
    super.initState();
    // Create a Ticker that fires every frame (vsync) to ensure
    // the CustomPaint repaints continuously, independent of Provider rebuilds
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    _frameCount++;
    _fpsFrameCount++;

    // Calculate FPS every second
    final now = DateTime.now();
    final diff = now.difference(_lastFpsTime).inMilliseconds;
    if (diff >= 1000) {
      _fps = _fpsFrameCount * 1000 / diff;
      _fpsFrameCount = 0;
      _lastFpsTime = now;
    }

    // Force a repaint by calling setState
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against zero or invalid sizes
        if (constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0 ||
            constraints.maxWidth.isNaN ||
            constraints.maxHeight.isNaN ||
            constraints.maxWidth.isInfinite ||
            constraints.maxHeight.isInfinite) {
          return Container(color: Colors.black);
        }
        return CustomPaint(
          painter: RaycastPainter(
            gameState: widget.gameState,
            fps: _fps,
            frameCount: _frameCount,
          ),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

/// CustomPainter that renders the 3D raycasting view
class RaycastPainter extends CustomPainter {
  final GameState gameState;
  final double fps;
  final int frameCount;

  RaycastPainter({
    required this.gameState,
    this.fps = 0,
    this.frameCount = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      _doPaint(canvas, size);
    } catch (e) {
      // If rendering fails, draw error indicator instead of silent black screen
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF880000),
      );
      final errorPainter = TextPainter(
        text: TextSpan(
          text: 'RENDER ERROR: $e',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      errorPainter.layout(maxWidth: size.width - 20);
      errorPainter.paint(canvas, const Offset(10, 10));
    }
  }

  void _doPaint(Canvas canvas, Size size) {
    // Guard against invalid canvas size
    if (size.width <= 0 ||
        size.height <= 0 ||
        size.width.isNaN ||
        size.height.isNaN) {
      return;
    }

    final player = gameState.player;
    final flashlight = gameState.flashlight;

    // Fill entire canvas black first (background)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    // Cast all rays
    final strips = RaycastEngine.castRays(
      player.x,
      player.y,
      player.angle,
      gameState.currentMap,
      gameState.currentMap[0].length,
      gameState.currentMap.length,
    );

    // Draw ceiling - MUCH brighter so you can see the 3D space
    final ceilingPaint = Paint()..color = const Color(0xFF0D0D12);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      ceilingPaint,
    );

    // Draw floor - brighter so you can see depth
    final floorPaint = Paint()..color = const Color(0xFF14141A);
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

      // Wall top and bottom positions (no head bob - it was causing issues)
      final wallTop = (size.height / 2 - wallHeight / 2);
      final wallBottom = (size.height / 2 + wallHeight / 2);

      // Calculate flashlight intensity for this strip
      final lightIntensity = RaycastEngine.calculateFlashlightIntensity(
        strip.rayAngle,
        player.angle,
        strip.distance,
        flashlight.isOn && !flashlight.isFlickering,
        flashlight.coneAngle *
            (flashlight.batteryLevel / 100.0).clamp(0.3, 1.0),
      );

      // Get wall color with lighting
      Color wallColor = RaycastEngine.getWallColor(
        strip.wallType,
        strip.side,
        lightIntensity,
      );

      // Add distance fog
      final fogFactor =
          (1.0 - strip.distance / RaycastEngine.maxDepth).clamp(0.0, 1.0);
      wallColor =
          Color.lerp(const Color(0xFF000000), wallColor, fogFactor)!;

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

    // Draw vignette overlay - very subtle, doesn't obscure walls
    _drawVignette(canvas, size);

    // Draw jumpscare flash
    if (gameState.jumpscareActive) {
      final jumpPaint = Paint()..color = const Color(0x80FF0000);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        jumpPaint,
      );
    }

    // ALWAYS draw debug info so we can verify rendering is working
    _drawDebugInfo(canvas, size);
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
      final screenX = size.width / 2 +
          (angleToObj / RaycastEngine.halfFov) * (size.width / 2);
      final spriteHeight = size.height / distance * 0.3;
      final spriteWidth = spriteHeight * 0.6;

      // Check if object is behind a wall (simple occlusion)
      final rayIndex =
          (screenX / stripWidth).floor().clamp(0, strips.length - 1);
      if (strips[rayIndex].distance < distance) continue;

      // Draw sprite based on type
      final spriteY = size.height / 2 - spriteHeight / 2;

      switch (obj.type) {
        case InteractionType.door:
          _drawDoorSprite(canvas, screenX - spriteWidth / 2, spriteY,
              spriteWidth, spriteHeight, distance);
          break;
        case InteractionType.item:
          _drawItemSprite(canvas, screenX - spriteWidth / 2, spriteY,
              spriteWidth, spriteHeight, obj.id, distance);
          break;
        case InteractionType.note:
          _drawNoteSprite(canvas, screenX - spriteWidth / 2, spriteY,
              spriteWidth, spriteHeight, distance);
          break;
      }
    }
  }

  void _drawDoorSprite(
      Canvas canvas, double x, double y, double w, double h, double dist) {
    final fogFactor = (1.0 - dist / RaycastEngine.maxDepth).clamp(0.1, 1.0);
    final paint = Paint()
      ..color = Color.lerp(
          const Color(0xFF000000), const Color(0xFF4A1515), fogFactor)!;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);

    // Door frame
    final framePaint = Paint()
      ..color = Color.lerp(
          const Color(0xFF000000), const Color(0xFF6B2020), fogFactor)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), framePaint);
  }

  void _drawItemSprite(Canvas canvas, double x, double y, double w, double h,
      String id, double dist) {
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
      ..color =
          Color.lerp(const Color(0xFF000000), itemColor, fogFactor * 0.8)!;

    // Floating item effect
    final floatOffset = math.sin(gameState.gameTime * 3) * 3;
    canvas.drawOval(
      Rect.fromLTWH(
          x + w * 0.2, y + h * 0.3 + floatOffset, w * 0.6, h * 0.4),
      paint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = Color.lerp(
          const Color(0x00000000), itemColor.withOpacity(0.3), fogFactor)!;
    canvas.drawOval(
      Rect.fromLTWH(x, y + h * 0.1 + floatOffset, w, h * 0.8),
      glowPaint,
    );
  }

  void _drawNoteSprite(
      Canvas canvas, double x, double y, double w, double h, double dist) {
    final fogFactor = (1.0 - dist / RaycastEngine.maxDepth).clamp(0.1, 1.0);
    final paint = Paint()
      ..color = Color.lerp(
          const Color(0xFF000000), const Color(0xFFD4C5A9), fogFactor)!;

    // Paper-like shape
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.15, y + h * 0.2, w * 0.7, h * 0.6),
      paint,
    );

    // Text lines
    final linePaint = Paint()
      ..color = Color.lerp(
          const Color(0xFF000000), const Color(0xFF333333), fogFactor)!;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(x + w * 0.25, y + h * 0.35 + i * h * 0.1),
        Offset(x + w * 0.75, y + h * 0.35 + i * h * 0.1),
        linePaint,
      );
    }
  }

  /// Draw vignette (darkened edges for found-footage feel)
  /// VERY subtle - doesn't obscure the 3D view
  void _drawVignette(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0, // Wide radius
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.05),
          Colors.black.withOpacity(0.15),
          Colors.black.withOpacity(0.3),
        ],
        stops: const [0.0, 0.65, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  /// Draw debug info - ALWAYS VISIBLE so we can verify rendering works
  void _drawDebugInfo(Canvas canvas, Size size) {
    final player = gameState.player;
    final debugText =
        'FPS: ${fps.toStringAsFixed(0)} | '
        'Pos: (${player.x.toStringAsFixed(1)}, ${player.y.toStringAsFixed(1)}) | '
        'Angle: ${(player.angle * 180 / math.pi).toStringAsFixed(0)}\u00B0 | '
        'Flash: ${gameState.flashlight.isOn ? "ON" : "OFF"} | '
        'Phase: ${gameState.phase.name} | '
        'Frame: $frameCount';

    final tp = TextPainter(
      text: TextSpan(
        text: debugText,
        style: TextStyle(
          color: Colors.green.withOpacity(0.8),
          fontSize: 9,
          fontFamily: 'Courier',
          backgroundColor: Colors.black.withOpacity(0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: size.width - 10);
    tp.paint(canvas, const Offset(5, 25));
  }

  @override
  bool shouldRepaint(covariant RaycastPainter oldDelegate) {
    // Always repaint - the Ticker drives continuous animation
    return true;
  }
}
