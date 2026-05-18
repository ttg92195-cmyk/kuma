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

    // Draw ceiling
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      Paint()..color = const Color(0xFF0D0D12),
    );

    // Draw floor
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      Paint()..color = const Color(0xFF14141A),
    );

    // Render wall strips with procedural textures
    final stripPixelWidth = size.width / RaycastEngine.numRays;

    for (final strip in strips) {
      if (strip.distance <= 0) continue;

      final wallHeight = size.height / strip.distance;
      final wallTop = size.height / 2 - wallHeight / 2;
      final wallBottom = size.height / 2 + wallHeight / 2;

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

    // Vignette
    _drawVignette(canvas, size);

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
    }
  }

  /// Concrete texture: horizontal mortar lines
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

    // Vertical crack lines (based on textureX)
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

  /// Bloody wall: drips and smears
  void _textureBloody(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final rng = math.Random(strip.hitX.toInt() * 97 + strip.hitY.toInt());

    // Blood drips
    final numDrips = rng.nextInt(4) + 1;
    for (var i = 0; i < numDrips; i++) {
      final dripX = strip.rayIndex * stripWidth + rng.nextDouble() * stripWidth;
      final dripStart = wallTop + (wallBottom - wallTop) * rng.nextDouble() * 0.3;
      final dripLength = (wallBottom - wallTop) * (0.15 + rng.nextDouble() * 0.4);

      final bloodPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF660000), alpha * 2)!;

      canvas.drawRect(
        Rect.fromLTWH(dripX, dripStart, stripWidth * 0.5, dripLength),
        bloodPaint,
      );
    }

    // Blood smear (horizontal)
    if (rng.nextDouble() > 0.5) {
      final smearY = wallTop + (wallBottom - wallTop) * (0.2 + rng.nextDouble() * 0.6);
      final smearPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF880000), alpha)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, smearY, stripWidth + 1, 2),
        smearPaint,
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
    if (rng.nextDouble() > 0.6) {
      final rustY = wallTop + rng.nextDouble() * (wallBottom - wallTop);
      final rustPaint = Paint()
        ..color = Color.lerp(Colors.transparent, const Color(0xFF6A4A2A), alpha * 1.5)!;
      canvas.drawRect(
        Rect.fromLTWH(strip.rayIndex * stripWidth, rustY, stripWidth + 1, 4),
        rustPaint,
      );
    }
  }

  /// Door frame: distinct border pattern
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

  /// Dirty tile wall: grid pattern
  void _textureTile(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final gridSize = (wallBottom - wallTop) / 6;
    if (gridSize < 5) return;

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(alpha.clamp(0, 0.2))
      ..strokeWidth = 0.5;

    // Horizontal tile lines
    for (var y = wallTop; y < wallBottom; y += gridSize) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        gridPaint,
      );
    }
  }

  /// Brick wall: brick pattern with mortar
  void _textureBrick(Canvas canvas, WallStrip strip,
      double wallTop, double wallBottom, double stripWidth, double alpha) {
    final brickHeight = (wallBottom - wallTop) / 8;
    if (brickHeight < 4) return;

    final mortarPaint = Paint()
      ..color = Color.lerp(Colors.transparent, const Color(0xFF3A3A3A), alpha)!;

    // Horizontal mortar lines
    for (var y = wallTop; y < wallBottom; y += brickHeight) {
      canvas.drawLine(
        Offset(strip.rayIndex * stripWidth, y),
        Offset((strip.rayIndex + 1) * stripWidth, y),
        mortarPaint..strokeWidth = 1,
      );
    }

    // Vertical mortar lines (offset every other row)
    final brickIndex = strip.rayIndex;
    for (var i = 0; i < 8; i++) {
      final y = wallTop + i * brickHeight;
      final offset = (i % 2 == 0) ? 0.0 : stripWidth * 0.5;
      final x = strip.rayIndex * stripWidth + offset;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + brickHeight),
        mortarPaint..strokeWidth = 0.5,
      );
    }
  }

  /// Draw ghost as a 2D billboard sprite
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
    final spriteHeight = size.height / distance * 0.8; // Tall ghost
    final spriteWidth = spriteHeight * 0.4; // Thin ghost

    // Occlusion check
    final rayIndex = (screenX / stripWidth).floor().clamp(0, strips.length - 1);
    if (strips[rayIndex].distance < distance - 0.5) return;

    final spriteY = size.height / 2 - spriteHeight / 2 + spriteHeight * 0.1;
    final fogFactor = (1.0 - distance / RaycastEngine.maxDepth).clamp(0.1, 1.0);

    // Glitch effect: ghost flickers horizontally
    final glitchOffset = math.sin(ghost.flickerTimer * 15) * ghost.horrorIntensity * 8;

    // Ghost body - white/gray gown
    final bodyPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF000000),
        const Color(0xFFD0D0E8),
        fogFactor * 0.7,
      )!;

    // Draw ghost body (long gown shape)
    final bodyPath = Path();
    final cx = screenX + glitchOffset;
    final topY = spriteY;
    final bottomY = spriteY + spriteHeight;

    // Head
    bodyPath.addOval(Rect.fromCenter(
      center: Offset(cx, topY + spriteHeight * 0.08),
      width: spriteWidth * 0.7,
      height: spriteHeight * 0.12,
    ));

    // Body (tapered gown)
    bodyPath.moveTo(cx - spriteWidth * 0.3, topY + spriteHeight * 0.15);
    bodyPath.lineTo(cx - spriteWidth * 0.5, bottomY);
    bodyPath.lineTo(cx + spriteWidth * 0.5, bottomY);
    bodyPath.lineTo(cx + spriteWidth * 0.3, topY + spriteHeight * 0.15);
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);

    // Dark hair (cascading down)
    final hairPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF000000),
        const Color(0xFF1A1A2A),
        fogFactor * 0.8,
      )!;

    canvas.drawRect(
      Rect.fromLTWH(cx - spriteWidth * 0.35, topY + spriteHeight * 0.06,
          spriteWidth * 0.3, spriteHeight * 0.3),
      hairPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + spriteWidth * 0.05, topY + spriteHeight * 0.06,
          spriteWidth * 0.3, spriteHeight * 0.3),
      hairPaint,
    );

    // Glowing eyes
    final eyeGlow = math.sin(gameState.gameTime * 5) * 0.3 + 0.7;
    final eyePaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF000000),
        const Color(0xFFFF0000),
        fogFactor * eyeGlow,
      )!;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - spriteWidth * 0.12, topY + spriteHeight * 0.08),
        width: spriteWidth * 0.12,
        height: spriteHeight * 0.04,
      ),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + spriteWidth * 0.12, topY + spriteHeight * 0.08),
        width: spriteWidth * 0.12,
        height: spriteHeight * 0.04,
      ),
      eyePaint,
    );

    // Ghost distortion effect (horizontal glitch lines near ghost)
    if (ghost.horrorIntensity > 0.3) {
      final rng = math.Random(frameCount ~/ 3);
      final glitchLinePaint = Paint()
        ..color = Color.lerp(
          Colors.transparent,
          const Color(0xFFFF0000),
          ghost.horrorIntensity * 0.2,
        )!;

      for (var i = 0; i < 3; i++) {
        final gy = spriteY + rng.nextDouble() * spriteHeight;
        final gx = screenX - spriteWidth + rng.nextDouble() * spriteWidth * 2;
        canvas.drawLine(
          Offset(gx - 10, gy),
          Offset(gx + 10, gy),
          glitchLinePaint,
        );
      }
    }
  }

  /// Draw interactive object sprites
  void _drawObjectSprites(Canvas canvas, Size size, List<WallStrip> strips, double stripWidth) {
    for (final obj in gameState.interactiveObjects) {
      if (obj.isCollected || obj.isOpened) continue;

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

      final spriteY = size.height / 2 - spriteHeight / 2;
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
          } else {
            itemColor = const Color(0xFFFFFFFF);
          }
          final paint = Paint()
            ..color = Color.lerp(const Color(0xFF000000), itemColor, fogFactor * 0.8)!;
          final floatOffset = math.sin(gameState.gameTime * 3) * 3;
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

  void _drawVignette(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final intensity = gameState.cameraGlitchIntensity;
    final baseRadius = 1.0 - intensity * 0.3; // Tighter vignette when ghost near

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: baseRadius,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.05 + intensity * 0.15),
          Colors.black.withOpacity(0.15 + intensity * 0.2),
          Colors.black.withOpacity(0.3 + intensity * 0.3),
        ],
        stops: const [0.0, 0.65, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
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
