import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/raycast_engine.dart';
import '../core/game_state.dart';
import '../core/game_map.dart' show InteractionType;
import '../core/ghost.dart' show GhostState;

/// Main 3D raycasting renderer widget with Ticker for continuous rendering
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
    final now = DateTime.now();
    final diff = now.difference(_lastFpsTime).inMilliseconds;
    if (diff >= 1000) {
      _fps = _fpsFrameCount * 1000 / diff;
      _fpsFrameCount = 0;
      _lastFpsTime = now;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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

/// CustomPainter with procedural textures, ghost sprite, and glitch effects
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
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF880000),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'RENDER ERROR: $e',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: size.width - 20);
      tp.paint(canvas, const Offset(10, 10));
    }
  }

  void _doPaint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || size.width.isNaN || size.height.isNaN) return;

    final player = gameState.player;
    final flashlight = gameState.flashlight;
    final ghost = gameState.ghost;

    // Black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    // Cast rays
    final strips = RaycastEngine.castRays(
      player.x, player.y, player.angle,
      gameState.currentMap,
      gameState.currentMap[0].length,
      gameState.currentMap.length,
    );

    // Draw ceiling - darker for more horror atmosphere
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      Paint()..color = const Color(0xFF08080C),
    );

    // Draw floor - darker for more horror atmosphere
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      Paint()..color = const Color(0xFF0C0C10),
    );

    // Render wall strips with procedural textures
    final stripPixelWidth = size.width / RaycastEngine.numRays;

    for (final strip in strips) {
      if (strip.distance <= 0) continue;

      final wallHeight = size.height / strip.distance;
      final wallTop = size.height / 2 - wallHeight / 2 + player.bobAmount;
      final wallBottom = size.height / 2 + wallHeight / 2 + player.bobAmount;

      final lightIntensity = RaycastEngine.calculateFlashlightIntensity(
        strip.rayAngle, player.angle, strip.distance,
        flashlight.isOn && !flashlight.isFlickering,
        flashlight.coneAngle * (flashlight.batteryLevel / 100.0).clamp(0.3, 1.0),
      );

      Color wallColor = RaycastEngine.getWallColor(
        strip.wallType, strip.side, lightIntensity,
      );

      final fogFactor = (1.0 - strip.distance / RaycastEngine.maxDepth).clamp(0.0, 1.0);
      wallColor = Color.lerp(const Color(0xFF000000), wallColor, fogFactor)!;

      // Draw base wall strip
      canvas.drawRect(
        Rect.fromLTWH(
          strip.rayIndex * stripPixelWidth, wallTop,
          stripPixelWidth + 1, wallBottom - wallTop,
        ),
        Paint()..color = wallColor,
      );

      // Draw procedural texture overlay
      if (strip.wallType > 0 && fogFactor > 0.1 && lightIntensity > 0.1) {
        _drawProceduralTexture(
          canvas, strip, wallTop, wallBottom,
          stripPixelWidth, lightIntensity, fogFactor, size,
        );
      }

      // Floor gradient
      _drawFloorGradient(canvas,
        strip.rayIndex * stripPixelWidth, wallBottom,
        stripPixelWidth, size.height - wallBottom,
        strip.distance, lightIntensity);

      // Ceiling gradient
      _drawCeilingGradient(canvas,
        strip.rayIndex * stripPixelWidth, 0,
        stripPixelWidth, wallTop,
        strip.distance, lightIntensity);
    }

    // Draw ghost sprite
    _drawGhostSprite(canvas, size, strips, stripPixelWidth);

    // Draw interactive object sprites
    _drawObjectSprites(canvas, size, strips, stripPixelWidth);

    // Camera glitch effect when ghost is near
    _drawCameraGlitch(canvas, size);

    // Enhanced Flashlight Vignette - dramatic dark overlay with circular light
    _drawFlashlightVignette(canvas, size);

    // Jumpscare flash
    if (gameState.jumpscareActive) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0x80FF0000),
      );
    }

    // Debug info
    _drawDebugInfo(canvas, size);
  }

  /// Procedural wall texture rendering
  void _drawProceduralTexture(
    Canvas canvas, WallStrip strip,
    double wallTop, double wallBottom,
    double stripWidth, double intensity, double fogFactor, Size size,
  ) {
    final wallHeight = wallBottom - wallTop;
    if (wallHeight < 4) return;

    final textureType = RaycastEngine.getWallTexture(strip.wallType);
    final texAlpha = (intensity * fogFactor * 0.4).clamp(0.0, 0.5);

    switch (textureType) {
      case WallTextureType.concrete:
        _textureConcrete(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.bloody:
        _textureBloody(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.rusty:
        _textureRusty(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.doorFrame:
        _textureDoorFrame(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.cracked:
        _textureCracked(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.exitDoor:
        _textureExitDoor(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha, size);
        break;
      case WallTextureType.emergency:
        _textureEmergency(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.tile:
        _textureTile(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.brick:
        _textureBrick(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.morgue:
        _textureMorgue(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.icuTile:
        _textureIcuTile(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
      case WallTextureType.operatingRoom:
        _textureOperatingRoom(canvas, strip, wallTop, wallBottom, stripWidth, texAlpha);
        break;
    }
  }

  /// Concrete texture: horizontal mortar lines with stain variation
  void _textureConcrete(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final lineSpacing = (wallBottom - wallTop) / 6;
    if (lineSpacing < 4) return;

    final paint = Paint()
      ..color = Colors.black.withOpacity(alpha.clamp(0, 0.3))
      ..strokeWidth = 1;

    for (var y = wallTop + lineSpacing; y < wallBottom; y += lineSpacing) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        paint,
      );
    }

    // Stain/dirt patches (based on textureX position)
    final rng = math.Random(strip.hitX.toInt() * 97 + strip.hitY.toInt());
    if (rng.nextDouble() > 0.6) {
      final stainY = wallTop + (wallBottom - wallTop) * rng.nextDouble();
      final stainPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF3A3530), alpha * 0.6)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, stainY, stripWidth + 1, lineSpacing * 0.4),
        stainPaint,
      );
    }

    // Vertical crack lines
    if (strip.textureX > 0.3 && strip.textureX < 0.35) {
      final crackPaint = Paint()
        ..color = Colors.black.withOpacity(alpha.clamp(0, 0.25))
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth + stripWidth * 0.5, wallTop),
        Offset(strip.rayIndex * stripWidth + stripWidth * 0.5, wallBottom),
        crackPaint,
      );
    }
  }

  /// Bloody wall: drips, smears, and handprints
  void _textureBloody(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final rng = math.Random(strip.hitX.toInt() * 97 + strip.hitY.toInt());

    // Blood drips (vertical streaks)
    final numDrips = rng.nextInt(5) + 1;
    for (var i = 0; i < numDrips; i++) {
      final dripX = strip.rayIndex * stripWidth + rng.nextDouble() * stripWidth;
      final dripStart = wallTop + (wallBottom - wallTop) * rng.nextDouble() * 0.3;
      final dripLength = (wallBottom - wallTop) * (0.15 + rng.nextDouble() * 0.5);

      final bloodPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF660000), alpha * 2)!;

      canvas.drawRect(
        Rect.fromLTWH(dripX, dripStart, stripWidth * 0.5, dripLength),
        bloodPaint,
      );
    }

    // Blood smear (horizontal)
    if (rng.nextDouble() > 0.4) {
      final smearY = wallTop + (wallBottom - wallTop) * (0.2 + rng.nextDouble() * 0.6);
      final smearPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF880000), alpha * 1.2)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, smearY, stripWidth + 1, 3),
        smearPaint,
      );
    }

    // Blood splash/pool at bottom
    if (rng.nextDouble() > 0.6) {
      final poolPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF550000), alpha * 1.5)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, wallBottom - (wallBottom - wallTop) * 0.15, stripWidth + 1, (wallBottom - wallTop) * 0.15),
        poolPaint,
      );
    }
  }

  /// Rusty metal: horizontal lines and rust spots
  void _textureRusty(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final lineSpacing = (wallBottom - wallTop) / 4;
    if (lineSpacing < 5) return;

    // Horizontal rivet lines
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(alpha.clamp(0, 0.25))
      ..strokeWidth = 1.5;

    for (var y = wallTop + lineSpacing; y < wallBottom; y += lineSpacing) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        linePaint,
      );
    }

    // Rust spots
    final rng = math.Random(strip.hitX.toInt() * 31 + strip.hitY.toInt());
    if (rng.nextDouble() > 0.5) {
      final rustY = wallTop + rng.nextDouble() * (wallBottom - wallTop);
      final rustPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF6A4A2A), alpha * 1.5)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, rustY, stripWidth + 1, 5),
        rustPaint,
      );
    }

    // Vertical weld line
    if (strip.textureX > 0.45 && strip.textureX < 0.55) {
      final weldPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF4A3A2A), alpha)!
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth + stripWidth / 2, wallTop),
        Offset(strip.rayIndex * stripWidth + stripWidth / 2, wallBottom),
        weldPaint,
      );
    }
  }

  /// Door frame: distinct border pattern with detail
  void _textureDoorFrame(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    // Frame border lines
    final borderPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF4A2020), alpha * 2)!
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(strip.rayIndex * stripWidth, wallTop),
      Offset(strip.rayIndex * stripWidth, wallBottom),
      borderPaint,
    );

    // Door handle indicator
    final handleY = wallTop + (wallBottom - wallTop) * 0.5;
    final handlePaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFFFFD700), alpha * 0.8)!;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(strip.rayIndex * stripWidth + stripWidth / 2, handleY),
        width: stripWidth * 0.4,
        height: stripWidth * 0.4,
      ),
      handlePaint,
    );

    // Door panel lines
    final panelPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF2A1010), alpha)!
      ..strokeWidth = 1;

    final panelY1 = wallTop + (wallBottom - wallTop) * 0.3;
    final panelY2 = wallTop + (wallBottom - wallTop) * 0.7;
    canvas.drawLine(
      Offset(strip.rayIndex * stripWidth, panelY1),
      Offset((strip.rayIndex + 1) * stripWidth, panelY1),
      panelPaint,
    );
    canvas.drawLine(
      Offset(strip.rayIndex * stripWidth, panelY2),
      Offset((strip.rayIndex + 1) * stripWidth, panelY2),
      panelPaint,
    );
  }

  /// Cracked wall: irregular cracks
  void _textureCracked(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final rng = math.Random(strip.hitX.toInt() * 53 + strip.hitY.toInt());

    if (rng.nextDouble() > 0.3) {
      final crackPaint = Paint()
        ..color = Colors.black.withOpacity(alpha.clamp(0, 0.35))
        ..strokeWidth = 1;

      // Draw a jagged vertical crack
      var y = wallTop;
      var x = strip.rayIndex * stripWidth + stripWidth * 0.5;
      while (y < wallBottom) {
        final nextY = y + (wallBottom - wallTop) * 0.1;
        final nextX = x + (rng.nextDouble() - 0.5) * stripWidth * 0.5;
        canvas.drawLine(Offset(x, y), Offset(nextX, nextY), crackPaint);
        x = nextX;
        y = nextY;
      }
    }

    // Plaster falling off effect
    if (rng.nextDouble() > 0.7) {
      final patchY = wallTop + (wallBottom - wallTop) * rng.nextDouble();
      final patchPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF5A5A4A), alpha * 0.5)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, patchY, stripWidth + 1, (wallBottom - wallTop) * 0.08),
        patchPaint,
      );
    }
  }

  /// Exit door: green glow with pulsing
  void _textureExitDoor(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha, Size size) {
    // Pulsing green glow
    final pulse = math.sin(gameState.gameTime * 3) * 0.3 + 0.7;
    final glowPaint = Paint()
      ..color = Color.lerp(
        Colors.transparent,
        const Color(0xFF00FF00),
        alpha * pulse * 0.5,
      )!;

    canvas.drawRect(
      Rect.fromLTWH(strip.rayIndex * stripWidth, wallTop, stripWidth + 1, wallBottom - wallTop),
      glowPaint,
    );

    // EXIT text indicator
    final midY = (wallTop + wallBottom) / 2;
    final textPaint = Paint()
      ..color = Color.lerp(
        Colors.transparent,
        const Color(0xFF00FF00),
        alpha * pulse,
      )!;
    canvas.drawRect(
      Rect.fromLTWH(strip.rayIndex * stripWidth, midY - 3, stripWidth + 1, 6),
      textPaint,
    );
  }

  /// Emergency red wall: flashing red stripes
  void _textureEmergency(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    // Flashing red effect
    final flash = math.sin(gameState.gameTime * 6) > 0 ? 1.0 : 0.3;

    final paint = Paint()
      ..color = Color.lerp(
        Colors.transparent,
        const Color(0xFFFF0000),
        alpha * flash * 0.6,
      )!;

    // Red horizontal stripes
    final stripeHeight = (wallBottom - wallTop) / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(
          strip.rayIndex * stripWidth,
          wallTop + i * stripeHeight,
          stripWidth + 1,
          stripeHeight,
        ),
        paint,
      );
    }
  }

  /// Dirty tile wall: hospital grid pattern with grout and stains
  void _textureTile(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final gridSize = (wallBottom - wallTop) / 6;
    if (gridSize < 5) return;

    // Tile grout lines (dirty brown/grey)
    final gridPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF2A2A28), alpha * 1.2)!
      ..strokeWidth = 1.5;

    // Horizontal tile lines
    for (var y = wallTop; y < wallBottom; y += gridSize) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        gridPaint,
      );
    }

    // Vertical tile lines (offset every other row for brick-like tile pattern)
    final tileIndex = (strip.textureX * 4).floor();
    final offset = (tileIndex % 2 == 0) ? 0.0 : stripWidth * 0.5;
    canvas.drawLine(
      Offset(strip.rayIndex * stripWidth + offset, wallTop),
      Offset(strip.rayIndex * stripWidth + offset, wallBottom),
      gridPaint..strokeWidth = 1,
    );

    // Water stain / mold patches
    final rng = math.Random(strip.hitX.toInt() * 41 + strip.hitY.toInt());
    if (rng.nextDouble() > 0.5) {
      final stainY = wallTop + rng.nextDouble() * (wallBottom - wallTop) * 0.5;
      final stainPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF3A3A20), alpha * 0.5)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, stainY, stripWidth + 1, gridSize * 0.6),
        stainPaint,
      );
    }
  }

  /// Brick wall: detailed brick pattern with mortar and variation
  void _textureBrick(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final brickHeight = (wallBottom - wallTop) / 8;
    if (brickHeight < 4) return;

    // Mortar color - greyish
    final mortarPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF3A3A3A), alpha * 1.2)!;

    // Horizontal mortar lines
    for (var y = wallTop; y < wallBottom; y += brickHeight) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        mortarPaint..strokeWidth = 1.5,
      );
    }

    // Vertical mortar lines (offset every other row - proper brick pattern)
    for (var i = 0; i < 8; i++) {
      final y = wallTop + i * brickHeight;
      final offset = (i % 2 == 0) ? 0.0 : stripWidth * 0.5;
      final x = strip.rayIndex * stripWidth + offset;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + brickHeight),
        mortarPaint..strokeWidth = 1,
      );
    }

    // Brick color variation (some bricks are slightly different shade)
    final rng = math.Random(strip.hitX.toInt() * 67 + strip.hitY.toInt() * 13);
    if (rng.nextDouble() > 0.7) {
      final brickRow = rng.nextInt(8);
      final variationPaint = Paint()
        ..color = Color.lerp(
          Colors.transparent,
          rng.nextDouble() > 0.5 ? const Color(0xFF7A5A4A) : const Color(0xFF5A4030),
          alpha * 0.5,
        )!;
      canvas.drawRect(
        Rect.fromLTWH(
          strip.rayIndex * stripWidth,
          wallTop + brickRow * brickHeight + 1,
          stripWidth + 1,
          brickHeight - 2,
        ),
        variationPaint,
      );
    }

    // Damaged/broken brick
    if (rng.nextDouble() > 0.85) {
      final crackPaint = Paint()
        ..color = Colors.black.withOpacity(alpha.clamp(0, 0.3))
        ..strokeWidth = 1;
      final startY = wallTop + rng.nextDouble() * (wallBottom - wallTop);
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, startY),
        Offset((strip.rayIndex + 1) * stripWidth, startY + brickHeight * 0.5),
        crackPaint,
      );
    }
  }

  /// Morgue locker wall: steel compartment doors with handles
  void _textureMorgue(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final lockerHeight = (wallBottom - wallTop) / 4;
    if (lockerHeight < 6) return;

    // Locker compartment borders (dark steel lines)
    final borderPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF2A3A4A), alpha * 1.5)!
      ..strokeWidth = 2;

    // Horizontal borders between lockers
    for (var y = wallTop; y < wallBottom; y += lockerHeight) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        borderPaint,
      );
    }

    // Vertical center line (locker door gap)
    final centerX = strip.rayIndex * stripWidth + stripWidth / 2;
    canvas.drawLine(
      Offset(centerX, wallTop),
      Offset(centerX, wallBottom),
      borderPaint..strokeWidth = 1,
    );

    // Locker handles (small rectangles on right side of each locker)
    final handlePaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF8A9AAA), alpha * 1.2)!;

    for (var i = 0; i < 4; i++) {
      final handleY = wallTop + i * lockerHeight + lockerHeight * 0.4;
      canvas.drawRect(
        Rect.fromLTWH(centerX + stripWidth * 0.1, handleY, stripWidth * 0.15, lockerHeight * 0.08),
        handlePaint,
      );
    }

    // Rust stains on some lockers
    final rng = math.Random(strip.hitX.toInt() * 29 + strip.hitY.toInt());
    if (rng.nextDouble() > 0.5) {
      final rustY = wallTop + rng.nextDouble() * (wallBottom - wallTop);
      final rustPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF5A4A3A), alpha * 0.8)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, rustY, stripWidth + 1, lockerHeight * 0.2),
        rustPaint,
      );
    }
  }

  /// ICU blue tile wall: hospital white-blue tiles with peeling
  void _textureIcuTile(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final gridSize = (wallBottom - wallTop) / 5;
    if (gridSize < 5) return;

    // Blue-white tile grout
    final groutPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF5A7A9A), alpha * 0.8)!
      ..strokeWidth = 1;

    // Horizontal grout lines
    for (var y = wallTop; y < wallBottom; y += gridSize) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        groutPaint,
      );
    }

    // Vertical grout lines (offset every other row)
    final tileIndex = (strip.textureX * 4).floor();
    for (var i = 0; i < 5; i++) {
      final offset = (i % 2 == 0) ? 0.0 : stripWidth * 0.5;
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth + offset, wallTop + i * gridSize),
        Offset(strip.rayIndex * stripWidth + offset, wallTop + (i + 1) * gridSize),
        groutPaint..strokeWidth = 0.5,
      );
    }

    // Peeling tile effect (missing tile patches)
    final rng = math.Random(strip.hitX.toInt() * 43 + strip.hitY.toInt());
    if (rng.nextDouble() > 0.6) {
      final peelY = wallTop + rng.nextDouble() * (wallBottom - wallTop);
      final peelPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF4A5A6A), alpha * 0.6)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, peelY, stripWidth + 1, gridSize * 0.5),
        peelPaint,
      );
    }

    // Water/mold stain
    if (rng.nextDouble() > 0.7) {
      final stainY = wallTop + (wallBottom - wallTop) * rng.nextDouble() * 0.5;
      final stainPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF3A4A5A), alpha * 0.4)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, stainY, stripWidth + 1, gridSize * 0.3),
        stainPaint,
      );
    }
  }

  /// Operating Room wall: pale green-white tiles with blood splatters
  void _textureOperatingRoom(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final gridSize = (wallBottom - wallTop) / 6;
    if (gridSize < 5) return;

    // Pale green tile grout
    final groutPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF5A6A5A), alpha * 0.7)!
      ..strokeWidth = 0.8;

    // Horizontal tile lines
    for (var y = wallTop; y < wallBottom; y += gridSize) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        groutPaint,
      );
    }

    // Vertical tile lines
    for (var i = 0; i < 6; i++) {
      final offset = (i % 2 == 0) ? 0.0 : stripWidth * 0.5;
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth + offset, wallTop + i * gridSize),
        Offset(strip.rayIndex * stripWidth + offset, wallTop + (i + 1) * gridSize),
        groutPaint..strokeWidth = 0.5,
      );
    }

    // Blood splatters (OR has LOTS of blood)
    final rng = math.Random(strip.hitX.toInt() * 71 + strip.hitY.toInt());
    final numSplats = rng.nextInt(3) + 1;
    for (var i = 0; i < numSplats; i++) {
      final splatY = wallTop + rng.nextDouble() * (wallBottom - wallTop);
      final splatHeight = rng.nextDouble() * gridSize * 0.4 + 2;
      final splatPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF660000), alpha * 2.0)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, splatY, stripWidth + 1, splatHeight),
        splatPaint,
      );
    }

    // Blood drip trail
    if (rng.nextDouble() > 0.4) {
      final dripStartY = wallTop + (wallBottom - wallTop) * rng.nextDouble() * 0.3;
      final dripLength = (wallBottom - wallTop) * (0.2 + rng.nextDouble() * 0.5);
      final dripPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF880000), alpha * 1.5)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth + stripWidth * 0.3, dripStartY, stripWidth * 0.4, dripLength),
        dripPaint,
      );
    }
  }

  /// Draw ghost as an animated 2D billboard sprite
  /// Features: Swaying animation, flowing hair, glowing eyes, glitch distortion
  void _drawGhostSprite(Canvas canvas, Size size, List<WallStrip> strips, double stripWidth) {
    final ghost = gameState.ghost;
    if (!ghost.isVisible) return;

    final player = gameState.player;
    final dx = ghost.x - player.x;
    final dy = ghost.y - player.y;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > RaycastEngine.maxDepth || distance < 0.3) return;

    // Calculate screen position
    var angleToGhost = math.atan2(dy, dx) - player.angle;
    while (angleToGhost > math.pi) angleToGhost -= 2 * math.pi;
    while (angleToGhost < -math.pi) angleToGhost += 2 * math.pi;

    if (angleToGhost.abs() > RaycastEngine.halfFov + 0.2) return;

    final screenX = size.width / 2 + (angleToGhost / RaycastEngine.halfFov) * (size.width / 2);
    final spriteHeight = size.height / distance * 0.9; // Taller ghost
    final spriteWidth = spriteHeight * 0.45; // Thin ghost

    // Occlusion check
    final rayIndex = (screenX / stripWidth).floor().clamp(0, strips.length - 1);
    if (strips[rayIndex].distance < distance - 0.5) return;

    final spriteY = size.height / 2 - spriteHeight / 2 + player.bobAmount + spriteHeight * 0.05;
    final fogFactor = (1.0 - distance / RaycastEngine.maxDepth).clamp(0.1, 1.0);

    // === ANIMATION ===
    // Swaying motion - ghost sways side to side
    final swayAmount = math.sin(gameState.gameTime * 2.5) * spriteWidth * 0.08;
    // Vertical bobbing - ghost hovers
    final bobOffset = math.sin(gameState.gameTime * 1.8) * spriteHeight * 0.02;
    // Glitch horizontal displacement
    final glitchOffset = math.sin(ghost.flickerTimer * 15) * ghost.horrorIntensity * 10;

    final cx = screenX + swayAmount + glitchOffset;
    final topY = spriteY + bobOffset;
    final bottomY = topY + spriteHeight;

    // === GHOST BODY (white/gray flowing gown) ===
    final bodyAlpha = fogFactor * 0.75;
    final bodyPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF000000),
        const Color(0xFFD0D0E8),
        bodyAlpha,
      )!;

    // Body path - flowing gown shape with animation
    final bodyPath = Path();

    // Head
    bodyPath.addOval(Rect.fromCenter(
      center: Offset(cx, topY + spriteHeight * 0.08),
      width: spriteWidth * 0.7,
      height: spriteHeight * 0.12,
    ));

    // Neck to shoulders
    bodyPath.moveTo(cx - spriteWidth * 0.25, topY + spriteHeight * 0.14);
    bodyPath.lineTo(cx - spriteWidth * 0.35, topY + spriteHeight * 0.18);

    // Left side of gown (flowing with animation)
    final gownSway1 = math.sin(gameState.gameTime * 3.0) * spriteWidth * 0.05;
    bodyPath.quadraticBezierTo(
      cx - spriteWidth * 0.45 + gownSway1, topY + spriteHeight * 0.5,
      cx - spriteWidth * 0.55, bottomY,
    );

    // Bottom hem (wavy)
    bodyPath.quadraticBezierTo(
      cx - spriteWidth * 0.2, bottomY + spriteHeight * 0.02 + math.sin(gameState.gameTime * 4) * 3,
      cx, bottomY,
    );
    bodyPath.quadraticBezierTo(
      cx + spriteWidth * 0.2, bottomY + spriteHeight * 0.02 + math.sin(gameState.gameTime * 4 + 1) * 3,
      cx + spriteWidth * 0.55, bottomY,
    );

    // Right side of gown
    final gownSway2 = math.sin(gameState.gameTime * 3.0 + 1) * spriteWidth * 0.05;
    bodyPath.quadraticBezierTo(
      cx + spriteWidth * 0.45 + gownSway2, topY + spriteHeight * 0.5,
      cx + spriteWidth * 0.35, topY + spriteHeight * 0.18,
    );

    bodyPath.lineTo(cx + spriteWidth * 0.25, topY + spriteHeight * 0.14);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);

    // === DARK HAIR (cascading down with flowing animation) ===
    final hairPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF000000),
        const Color(0xFF1A1A2A),
        fogFactor * 0.85,
      )!;

    // Left hair strand (animated)
    final hairSway1 = math.sin(gameState.gameTime * 2.0) * spriteWidth * 0.04;
    final hairPath1 = Path();
    hairPath1.moveTo(cx - spriteWidth * 0.2, topY + spriteHeight * 0.04);
    hairPath1.quadraticBezierTo(
      cx - spriteWidth * 0.35 + hairSway1, topY + spriteHeight * 0.15,
      cx - spriteWidth * 0.3 + hairSway1 * 1.5, topY + spriteHeight * 0.35,
    );
    hairPath1.lineTo(cx - spriteWidth * 0.15 + hairSway1 * 0.5, topY + spriteHeight * 0.35);
    hairPath1.quadraticBezierTo(
      cx - spriteWidth * 0.2, topY + spriteHeight * 0.15,
      cx - spriteWidth * 0.1, topY + spriteHeight * 0.04,
    );
    canvas.drawPath(hairPath1, hairPaint);

    // Right hair strand (animated, offset phase)
    final hairSway2 = math.sin(gameState.gameTime * 2.0 + 0.8) * spriteWidth * 0.04;
    final hairPath2 = Path();
    hairPath2.moveTo(cx + spriteWidth * 0.1, topY + spriteHeight * 0.04);
    hairPath2.quadraticBezierTo(
      cx + spriteWidth * 0.25 + hairSway2, topY + spriteHeight * 0.15,
      cx + spriteWidth * 0.2 + hairSway2 * 1.5, topY + spriteHeight * 0.35,
    );
    hairPath2.lineTo(cx + spriteWidth * 0.05 + hairSway2 * 0.5, topY + spriteHeight * 0.35);
    hairPath2.quadraticBezierTo(
      cx + spriteWidth * 0.1, topY + spriteHeight * 0.15,
      cx + spriteWidth * 0.0, topY + spriteHeight * 0.04,
    );
    canvas.drawPath(hairPath2, hairPaint);

    // Center hair (covering face partially)
    canvas.drawRect(
      Rect.fromLTWH(cx - spriteWidth * 0.08, topY + spriteHeight * 0.03,
          spriteWidth * 0.16, spriteHeight * 0.2),
      hairPaint,
    );

    // === GLOWING EYES ===
    final eyeGlow = math.sin(gameState.gameTime * 5) * 0.3 + 0.7;
    final eyePaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF000000),
        const Color(0xFFFF0000),
        fogFactor * eyeGlow,
      )!;

    // Left eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - spriteWidth * 0.12, topY + spriteHeight * 0.08),
        width: spriteWidth * 0.13,
        height: spriteHeight * 0.04,
      ),
      eyePaint,
    );
    // Right eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + spriteWidth * 0.12, topY + spriteHeight * 0.08),
        width: spriteWidth * 0.13,
        height: spriteHeight * 0.04,
      ),
      eyePaint,
    );

    // Eye glow effect (soft red light around eyes)
    if (fogFactor > 0.3) {
      final glowPaint = Paint()
        ..color = Color.lerp(
          Colors.transparent,
          const Color(0xFFFF0000),
          fogFactor * eyeGlow * 0.15,
        )!;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, topY + spriteHeight * 0.08),
          width: spriteWidth * 0.6,
          height: spriteHeight * 0.1,
        ),
        glowPaint,
      );
    }

    // === GHOST ARMS (reaching forward when chasing) ===
    if (ghost.state == GhostState.chase || ghost.horrorIntensity > 0.5) {
      final armPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFF000000),
          const Color(0xFFB0B0C8),
          fogFactor * 0.6,
        )!;

      // Left arm reaching
      final armSway = math.sin(gameState.gameTime * 4) * spriteWidth * 0.05;
      final armPath = Path();
      armPath.moveTo(cx - spriteWidth * 0.3, topY + spriteHeight * 0.2);
      armPath.quadraticBezierTo(
        cx - spriteWidth * 0.6 + armSway, topY + spriteHeight * 0.3,
        cx - spriteWidth * 0.7 + armSway, topY + spriteHeight * 0.45,
      );
      armPath.lineTo(cx - spriteWidth * 0.55 + armSway, topY + spriteHeight * 0.47);
      armPath.quadraticBezierTo(
        cx - spriteWidth * 0.45, topY + spriteHeight * 0.32,
        cx - spriteWidth * 0.2, topY + spriteHeight * 0.22,
      );
      canvas.drawPath(armPath, armPaint);

      // Right arm reaching (opposite phase)
      final armSway2 = math.sin(gameState.gameTime * 4 + math.pi) * spriteWidth * 0.05;
      final armPath2 = Path();
      armPath2.moveTo(cx + spriteWidth * 0.3, topY + spriteHeight * 0.2);
      armPath2.quadraticBezierTo(
        cx + spriteWidth * 0.6 + armSway2, topY + spriteHeight * 0.3,
        cx + spriteWidth * 0.7 + armSway2, topY + spriteHeight * 0.45,
      );
      armPath2.lineTo(cx + spriteWidth * 0.55 + armSway2, topY + spriteHeight * 0.47);
      armPath2.quadraticBezierTo(
        cx + spriteWidth * 0.45, topY + spriteHeight * 0.32,
        cx + spriteWidth * 0.2, topY + spriteHeight * 0.22,
      );
      canvas.drawPath(armPath2, armPaint);
    }

    // === GHOST DISTORTION EFFECT ===
    if (ghost.horrorIntensity > 0.3) {
      final rng = math.Random(frameCount ~/ 3);
      final glitchLinePaint = Paint()
        ..color = Color.lerp(
          Colors.transparent,
          const Color(0xFFFF0000),
          ghost.horrorIntensity * 0.2,
        )!;

      for (var i = 0; i < 4; i++) {
        final gy = topY + rng.nextDouble() * spriteHeight;
        final gx = screenX - spriteWidth + rng.nextDouble() * spriteWidth * 2;
        canvas.drawLine(
          Offset(gx - 15, gy),
          Offset(gx + 15, gy),
          glitchLinePaint,
        );
      }
    }
  }

  /// Draw interactive object sprites
  void _drawObjectSprites(Canvas canvas, Size size, List<WallStrip> strips, double stripWidth) {
    for (final obj in gameState.interactiveObjects) {
      if (obj.isCollected || obj.isOpened) continue;
      if (obj.type == InteractionType.container && obj.isSearched) continue;

      final dx = obj.x - gameState.player.x;
      final dy = obj.y - gameState.player.y;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance > RaycastEngine.maxDepth || distance < 0.5) continue;

      var angleToObj = math.atan2(dy, dx) - gameState.player.angle;
      while (angleToObj > math.pi) angleToObj -= 2 * math.pi;
      while (angleToObj < -math.pi) angleToObj += 2 * math.pi;

      if (angleToObj.abs() > RaycastEngine.halfFov + 0.1) continue;

      final screenX = size.width / 2 + (angleToObj / RaycastEngine.halfFov) * (size.width / 2);
      final spriteHeight = size.height / distance * 0.25;
      final spriteWidth = spriteHeight * 0.6;

      final rayIndex = (screenX / stripWidth).floor().clamp(0, strips.length - 1);
      if (strips[rayIndex].distance < distance) continue;

      final spriteY = size.height / 2 - spriteHeight / 2 + gameState.player.bobAmount;
      final fogFactor = (1.0 - distance / RaycastEngine.maxDepth).clamp(0.1, 1.0);

      switch (obj.type) {
        case InteractionType.door:
          final paint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF4A1515), fogFactor)!;
          canvas.drawRect(Rect.fromLTWH(screenX - spriteWidth / 2, spriteY, spriteWidth, spriteHeight), paint);
          final framePaint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF6B2020), fogFactor)!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRect(Rect.fromLTWH(screenX - spriteWidth / 2, spriteY, spriteWidth, spriteHeight), framePaint);

        case InteractionType.item:
          Color itemColor;
          if (obj.id.startsWith('key_')) {
            itemColor = const Color(0xFFFFD700);
          } else if (obj.id.startsWith('battery_')) {
            itemColor = const Color(0xFF00FF00);
          } else if (obj.id.startsWith('medkit_')) {
            itemColor = const Color(0xFF00FF88);
          } else if (obj.id == 'crowbar') {
            itemColor = const Color(0xFFFF8800);
          } else {
            itemColor = const Color(0xFFFFFFFF);
          }
          final paint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), itemColor, fogFactor * 0.8)!;
          final floatOffset = math.sin(gameState.gameTime * 3) * 3;
          // Medkit = cross shape
          if (obj.id.startsWith('medkit_')) {
            // White box with red cross
            final boxPaint = Paint()
              ..color = Color.lerp(const Color(0xFF000000), const Color(0xFFDDDDDD), fogFactor * 0.7)!;
            canvas.drawRect(
              Rect.fromLTWH(screenX - spriteWidth * 0.3, spriteY + spriteHeight * 0.2 + floatOffset, spriteWidth * 0.6, spriteHeight * 0.5),
              boxPaint,
            );
            final crossPaint = Paint()
              ..color = Color.lerp(const Color(0xFF000000), const Color(0xFFFF0000), fogFactor * 0.9)!;
            // Horizontal bar
            canvas.drawRect(
              Rect.fromLTWH(screenX - spriteWidth * 0.2, spriteY + spriteHeight * 0.38 + floatOffset, spriteWidth * 0.4, spriteHeight * 0.08),
              crossPaint,
            );
            // Vertical bar
            canvas.drawRect(
              Rect.fromLTWH(screenX - spriteWidth * 0.06, spriteY + spriteHeight * 0.25 + floatOffset, spriteWidth * 0.12, spriteHeight * 0.35),
              crossPaint,
            );
          } else if (obj.id == 'crowbar') {
            // Crowbar = orange/red metallic bar
            final barPaint = Paint()
              ..color = Color.lerp(const Color(0xFF000000), const Color(0xFFAA5500), fogFactor * 0.8)!;
            canvas.drawRect(
              Rect.fromLTWH(screenX - spriteWidth * 0.4, spriteY + spriteHeight * 0.4 + floatOffset, spriteWidth * 0.8, spriteHeight * 0.1),
              barPaint,
            );
            // Curved end
            canvas.drawOval(
              Rect.fromLTWH(screenX + spriteWidth * 0.25, spriteY + spriteHeight * 0.3 + floatOffset, spriteWidth * 0.2, spriteHeight * 0.2),
              barPaint,
            );
          } else {
            // Keys/battery - floating glow
            canvas.drawOval(
              Rect.fromLTWH(screenX - spriteWidth * 0.3, spriteY + spriteHeight * 0.3 + floatOffset, spriteWidth * 0.6, spriteHeight * 0.4),
              paint,
            );
            final glowPaint = Paint()
              ..color = Color.lerp(const Color(0x00000000), itemColor.withOpacity(0.3), fogFactor)!;
            canvas.drawOval(
              Rect.fromLTWH(screenX - spriteWidth / 2, spriteY + spriteHeight * 0.1 + floatOffset, spriteWidth, spriteHeight * 0.8),
              glowPaint,
            );
          }

        case InteractionType.note:
          final paint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), const Color(0xFFD4C5A9), fogFactor)!;
          canvas.drawRect(
            Rect.fromLTWH(screenX - spriteWidth * 0.35, spriteY + spriteHeight * 0.2, spriteWidth * 0.7, spriteHeight * 0.6),
            paint,
          );
          final linePaint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF333333), fogFactor)!;
          for (var i = 0; i < 3; i++) {
            canvas.drawLine(
              Offset(screenX - spriteWidth * 0.25, spriteY + spriteHeight * 0.35 + i * spriteHeight * 0.1),
              Offset(screenX + spriteWidth * 0.25, spriteY + spriteHeight * 0.35 + i * spriteHeight * 0.1),
              linePaint,
            );
          }

        case InteractionType.container:
          // Container = wooden/metal cabinet or drawer
          final isSearched = obj.isSearched;
          final containerColor = isSearched
              ? const Color(0xFF3A3A3A) // Greyed out after searched
              : (obj.id.startsWith('morgue_')
                  ? const Color(0xFF5A6A7A) // Steel morgue drawer
                  : obj.id.startsWith('cabinet_')
                      ? const Color(0xFF8A7A5A) // Wooden cabinet
                      : const Color(0xFF6A5A4A)); // Default drawer

          final containerPaint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), containerColor, fogFactor * 0.8)!;

          // Container body
          final cHeight = spriteHeight * 0.7;
          final cWidth = spriteWidth * 0.8;
          canvas.drawRect(
            Rect.fromLTWH(screenX - cWidth / 2, spriteY + spriteHeight * 0.15, cWidth, cHeight),
            containerPaint,
          );

          // Container border
          final borderPaint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF4A3A2A), fogFactor * 0.6)!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRect(
            Rect.fromLTWH(screenX - cWidth / 2, spriteY + spriteHeight * 0.15, cWidth, cHeight),
            borderPaint,
          );

          // Drawer/cabinet handle
          if (!isSearched) {
            final handlePaint = Paint()
              ..color = Color.lerp(const Color(0xFF000000), const Color(0xFFAA9A6A), fogFactor * 0.7)!;
            canvas.drawRect(
              Rect.fromLTWH(screenX - cWidth * 0.15, spriteY + spriteHeight * 0.45, cWidth * 0.3, cHeight * 0.08),
              handlePaint,
            );
            // Glow hint (searchable indicator)
            final glowPulse = math.sin(gameState.gameTime * 2) * 0.3 + 0.7;
            final glowPaint = Paint()
              ..color = Color.lerp(
                Colors.transparent,
                obj.makesNoise
                    ? const Color(0xFFFF4400) // Orange glow = loud
                    : const Color(0xFF00FF00), // Green glow = quiet
                fogFactor * 0.2 * glowPulse,
              )!;
            canvas.drawOval(
              Rect.fromLTWH(screenX - cWidth / 2 - 3, spriteY + spriteHeight * 0.1, cWidth + 6, cHeight + 10),
              glowPaint,
            );
          } else {
            // Already searched - show open drawer
            final openPaint = Paint()
              ..color = Color.lerp(const Color(0xFF000000), const Color(0xFF1A1A1A), fogFactor * 0.5)!;
            canvas.drawRect(
              Rect.fromLTWH(screenX - cWidth * 0.3, spriteY + spriteHeight * 0.55, cWidth * 0.6, cHeight * 0.3),
              openPaint,
            );
          }
      }
    }
  }

  /// Camera glitch effect when ghost is near
  void _drawCameraGlitch(Canvas canvas, Size size) {
    final intensity = gameState.cameraGlitchIntensity;
    if (intensity < 0.05) return;

    final rng = math.Random(frameCount);

    // Static noise lines
    final numLines = (intensity * 30).floor();
    for (var i = 0; i < numLines; i++) {
      final y = rng.nextDouble() * size.height;
      final lineX = rng.nextDouble() * size.width;
      final lineWidth = rng.nextDouble() * size.width * intensity;

      final glitchPaint = Paint()
        ..color = Color.fromRGBO(
          rng.nextDouble() > 0.5 ? 255 : 0,
          rng.nextDouble() > 0.7 ? 255 : 0,
          rng.nextDouble() > 0.7 ? 255 : 0,
          intensity * 0.15,
        );

      canvas.drawLine(
        Offset(lineX, y),
        Offset(lineX + lineWidth, y),
        glitchPaint,
      );
    }

    // Red tint overlay when ghost is very close
    if (intensity > 0.5) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Color.fromRGBO(255, 0, 0, (intensity - 0.5) * 0.1),
      );
    }

    // Horizontal displacement bars (scanline glitch)
    if (intensity > 0.3) {
      final numBars = (intensity * 5).floor();
      for (var i = 0; i < numBars; i++) {
        final barY = rng.nextDouble() * size.height;
        final barHeight = 2.0 + rng.nextDouble() * 8.0 * intensity;
        final offset = (rng.nextDouble() - 0.5) * 20.0 * intensity;

        canvas.drawRect(
          Rect.fromLTWH(offset, barY, size.width, barHeight),
          Paint()..color = Colors.black.withOpacity(0.1),
        );
      }
    }
  }

  void _drawFloorGradient(Canvas canvas, double x, double y, double width, double height, double distance, double intensity) {
    if (height <= 0) return;
    final floorColor = RaycastEngine.getFloorColor(distance, intensity);
    canvas.drawRect(Rect.fromLTWH(x, y, width + 1, height), Paint()..color = floorColor);
  }

  void _drawCeilingGradient(Canvas canvas, double x, double y, double width, double height, double distance, double intensity) {
    if (height <= 0) return;
    final ceilColor = RaycastEngine.getCeilingColor(distance, intensity);
    canvas.drawRect(Rect.fromLTWH(x, y, width + 1, height), Paint()..color = ceilColor);
  }

  /// ENHANCED Flashlight Vignette - dramatic dark overlay with circular light
  /// Creates the "only what the flashlight illuminates is visible" effect
  void _drawFlashlightVignette(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final ghost = gameState.ghost;
    final flashlight = gameState.flashlight;
    final intensity = gameState.cameraGlitchIntensity;

    // Base vignette tightness depends on flashlight state
    double baseRadius;
    List<double> stops;
    List<Color> colors;

    if (flashlight.isOn && !flashlight.isFlickering) {
      // Flashlight ON: Bright center, dark edges
      // Tighter cone when ghost is near
      baseRadius = 0.75 - intensity * 0.2;
      stops = const [0.0, 0.25, 0.5, 0.7, 0.85, 1.0];
      colors = [
        Colors.transparent,                                    // Center: clear
        Colors.transparent,                                    // Inner: clear
        Colors.black.withOpacity(0.15 + intensity * 0.1),     // Mid: slight dark
        Colors.black.withOpacity(0.4 + intensity * 0.15),     // Outer-mid: darker
        Colors.black.withOpacity(0.7 + intensity * 0.15),     // Outer: very dark
        Colors.black.withOpacity(0.85 + intensity * 0.1),     // Edge: near black
      ];
    } else if (flashlight.isFlickering) {
      // Flashlight FLICKERING: Unstable light
      final flickerPhase = math.sin(gameState.gameTime * 20) * 0.5 + 0.5;
      baseRadius = 0.5 - flickerPhase * 0.2 - intensity * 0.15;
      stops = const [0.0, 0.2, 0.4, 0.65, 0.85, 1.0];
      colors = [
        Colors.transparent,
        Colors.black.withOpacity(0.1 * flickerPhase),
        Colors.black.withOpacity(0.3 + flickerPhase * 0.2),
        Colors.black.withOpacity(0.6 + flickerPhase * 0.15),
        Colors.black.withOpacity(0.8),
        Colors.black.withOpacity(0.9),
      ];
    } else {
      // Flashlight OFF: Very dark, barely visible
      baseRadius = 0.35 - intensity * 0.1;
      stops = const [0.0, 0.15, 0.35, 0.6, 0.85, 1.0];
      colors = [
        Colors.black.withOpacity(0.1),
        Colors.black.withOpacity(0.3),
        Colors.black.withOpacity(0.55),
        Colors.black.withOpacity(0.75),
        Colors.black.withOpacity(0.9),
        Colors.black.withOpacity(0.95),
      ];
    }

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: baseRadius,
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Additional corner darkness for extra horror atmosphere
    final cornerPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.1 + intensity * 0.1),
          Colors.black.withOpacity(0.2 + intensity * 0.15),
        ],
        stops: const [0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), cornerPaint);
  }

  void _drawDebugInfo(Canvas canvas, Size size) {
    final player = gameState.player;
    final ghost = gameState.ghost;

    String ghostStateStr;
    switch (ghost.state) {
      case GhostState.patrol: ghostStateStr = 'PATROL';
      case GhostState.chase: ghostStateStr = 'CHASE';
      case GhostState.lost: ghostStateStr = 'LOST';
      case GhostState.stalking: ghostStateStr = 'STALK';
      case GhostState.noiseAlert: ghostStateStr = 'NOISE!';
    }

    final debugText =
        'FPS: ${fps.toStringAsFixed(0)} | '
        'Pos: (${player.x.toStringAsFixed(1)}, ${player.y.toStringAsFixed(1)}) | '
        'Angle: ${(player.angle * 180 / math.pi).toStringAsFixed(0)}\u00B0 | '
        'Ghost: ${ghostStateStr} D:${math.sqrt(math.pow(ghost.x - player.x, 2) + math.pow(ghost.y - player.y, 2)).toStringAsFixed(1)} | '
        'Phase: ${gameState.phase.name}';

    final tp = TextPainter(
      text: TextSpan(
        text: debugText,
        style: TextStyle(
          color: Colors.green.withOpacity(0.7),
          fontSize: 8,
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
  bool shouldRepaint(covariant RaycastPainter oldDelegate) => true;
}
