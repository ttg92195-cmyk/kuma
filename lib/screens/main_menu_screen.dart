import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/game_state.dart';

/// Main Menu Screen - Horror themed title screen
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flickerController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flickerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context, listen: false);

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Background static noise effect
            CustomPaint(
              painter: _StaticNoisePainter(),
              size: Size.infinite,
            ),

            // Dark vignette
            Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Blood drip decoration
            _BloodDripDecoration(),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  AnimatedBuilder(
                    animation: _flickerController,
                    builder: (context, child) {
                      final flicker = math.Random().nextDouble() > 0.05;
                      return Opacity(
                        opacity: flicker ? 1.0 : 0.3,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        // Found footage label
                        const Text(
                          'FOUND FOOTAGE',
                          style: TextStyle(
                            color: Color(0xFFFF0000),
                            fontSize: 12,
                            fontFamily: 'Courier',
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Main title
                        const Text(
                          'KUMA',
                          style: TextStyle(
                            color: Color(0xFF8B0000),
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            letterSpacing: 20,
                            shadows: [
                              Shadow(
                                color: Color(0xFFFF0000),
                                blurRadius: 20,
                              ),
                              Shadow(
                                color: Color(0x40FF0000),
                                blurRadius: 50,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitle
                        const Text(
                          'DARK ASYLUM',
                          style: TextStyle(
                            color: Color(0xFF4A0000),
                            fontSize: 18,
                            fontFamily: 'Courier',
                            letterSpacing: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Play button
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + _pulseController.value * 0.05,
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        gameState.startGame();
                        Navigator.of(context).pushReplacementNamed('/game');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF8B0000),
                            width: 2,
                          ),
                          color: const Color(0xFF8B0000).withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0000).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              color: Color(0xFFFF0000),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'START GAME',
                              style: TextStyle(
                                color: Color(0xFFFF0000),
                                fontSize: 18,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Instructions
                  const Text(
                    'Find keys. Open doors. Escape.',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      fontFamily: 'Courier',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use joystick to move. Touch screen to look.',
                    style: TextStyle(
                      color: Colors.white12,
                      fontSize: 10,
                      fontFamily: 'Courier',
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Warning
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF8B0000).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning,
                          color: Color(0xFF8B0000),
                          size: 14,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CONTAINS JUMPSCARES & HORROR CONTENT',
                          style: TextStyle(
                            color: Color(0xFF8B0000),
                            fontSize: 9,
                            fontFamily: 'Courier',
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom credits
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text(
                    'A RAYCASTING HORROR EXPERIENCE',
                    style: TextStyle(
                      color: Colors.white10,
                      fontSize: 9,
                      fontFamily: 'Courier',
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flutter + Dart | v1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.05),
                      fontSize: 8,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static noise effect painter
class _StaticNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(12345);
    final paint = Paint();

    // Sparse static for performance
    for (var i = 0; i < 500; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final alpha = rng.nextDouble() * 0.03;

      paint.color = Colors.white.withOpacity(alpha);
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1, 1),
        paint,
      );
    }

    // Scanlines
    paint.color = Colors.black.withOpacity(0.02);
    for (var y = 0.0; y < size.height; y += 2) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Blood drip decoration for menu
class _BloodDripDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BloodDripPainter(),
      size: Size.infinite,
    );
  }
}

class _BloodDripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A0000).withOpacity(0.4);

    // Blood drips from top
    final rng = math.Random(99);
    for (var i = 0; i < 8; i++) {
      final x = rng.nextDouble() * size.width;
      final dripLength = 30 + rng.nextDouble() * 80;
      final dripWidth = 2 + rng.nextDouble() * 4;

      canvas.drawRect(
        Rect.fromLTWH(x, 0, dripWidth, dripLength),
        paint,
      );

      // Drip drop at bottom
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + dripWidth / 2, dripLength),
          width: dripWidth * 2,
          height: dripWidth * 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
