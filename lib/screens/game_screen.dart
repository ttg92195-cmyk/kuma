import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/game_state.dart';
import '../core/game_map.dart' show InteractionType;
import '../core/audio_manager.dart';
import '../widgets/raycast_renderer.dart';
import '../widgets/camera_overlay.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/flashlight_button.dart';
import '../widgets/interaction_prompt.dart';
import '../widgets/game_hud.dart';
import '../widgets/message_overlay.dart';
import '../widgets/note_overlay.dart';

/// Main Game Screen - The 3D horror gameplay view
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late Timer _gameLoop;
  final AudioManager _audioManager = AudioManager();

  // Touch look tracking
  Offset? _touchStart;
  Offset? _touchCurrent;
  double _lookSensitivity = 0.003;

  // Movement state
  double _moveX = 0.0;
  double _moveY = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startGameLoop();
    _audioManager.init();
    _audioManager.startAmbient();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameLoop.cancel();
    _audioManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      context.read<GameState>().pauseGame();
    }
  }

  void _startGameLoop() {
    _gameLoop = Timer.periodic(
      const Duration(milliseconds: 33), // ~30 FPS
      (_) {
        final gameState = context.read<GameState>();
        if (gameState.phase == GamePhase.playing) {
          gameState.update(0.033);

          // Audio updates
          if (gameState.player.isMoving) {
            _audioManager.playFootstep();
          }
          _audioManager.updateAmbientIntensity(gameState.ambientIntensity);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) {
        context.read<GameState>().pauseGame();
      },
      child: Scaffold(
        body: Consumer<GameState>(
          builder: (context, gameState, _) {
            if (gameState.phase == GamePhase.won) {
              return _buildWinScreen(gameState);
            }
            if (gameState.phase == GamePhase.dead) {
              return _buildDeathScreen(gameState);
            }

            return Stack(
              children: [
                // 1. 3D Raycasting Renderer (bottom layer)
                Positioned.fill(
                  child: RaycastRenderer(gameState: gameState),
                ),

                // 2. Camera Overlay (found-footage UI)
                Positioned.fill(
                  child: CameraOverlay(
                    isRecording: true,
                    batteryLevel: gameState.flashlight.batteryLevel,
                    timestamp: gameState.formattedTime,
                    showCrosshair: true,
                  ),
                ),

                // 3. Game HUD
                GameHUD(
                  score: gameState.score,
                  gameTime: gameState.formattedTime,
                  stamina: gameState.player.stamina,
                  health: gameState.player.health,
                  inventory: gameState.inventory,
                ),

                // 4. Touch look area (right side of screen)
                Positioned.fill(
                  child: GestureDetector(
                    onPanStart: (details) {
                      _touchStart = details.globalPosition;
                      _touchCurrent = details.globalPosition;
                    },
                    onPanUpdate: (details) {
                      if (_touchCurrent != null) {
                        final dx = details.globalPosition.dx - _touchCurrent!.dx;
                        gameState.player.applyLookInput(dx);
                        _touchCurrent = details.globalPosition;
                      }
                    },
                    onPanEnd: (_) {
                      _touchStart = null;
                      _touchCurrent = null;
                    },
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),

                // 5. Interaction prompt
                if (gameState.canInteract)
                  Positioned.fill(
                    child: InteractionPrompt(gameState: gameState),
                  ),

                // 6. Message overlay
                if (gameState.currentMessage != null)
                  Positioned.fill(
                    child: MessageOverlay(
                      message: gameState.currentMessage,
                    ),
                  ),

                // 7. Note overlay
                if (gameState.showNoteOverlay)
                  Positioned.fill(
                    child: NoteOverlay(
                      label: gameState.noteLabel,
                      content: gameState.noteContent,
                      onClose: () => gameState.closeNote(),
                    ),
                  ),

                // 8. Jumpscare overlay
                if (gameState.jumpscareActive)
                  Positioned.fill(
                    child: _JumpscareOverlay(),
                  ),

                // 9. Bottom controls
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _BottomControls(
                    gameState: gameState,
                    onMove: (x, y) {
                      _moveX = x;
                      _moveY = y;
                    },
                    onFlashlightToggle: () {
                      gameState.toggleFlashlight();
                      _audioManager.playFlashlightToggle();
                    },
                    onInteract: () {
                      gameState.interact();
                      final obj = gameState.nearbyObject;
                      if (obj != null) {
                        switch (obj.type) {
                          case InteractionType.door:
                            _audioManager.playDoorOpen();
                            break;
                          case InteractionType.item:
                            if (obj.id.startsWith('key_')) {
                              _audioManager.playKeyPickup();
                            } else {
                              _audioManager.playItemPickup();
                            }
                            break;
                          case InteractionType.note:
                            break;
                        }
                      }
                    },
                    onRunToggle: () => gameState.toggleRun(),
                    onPause: () => gameState.pauseGame(),
                  ),
                ),

                // 10. Movement processor (applies joystick input continuously)
                _MovementProcessor(
                  gameState: gameState,
                  moveX: _moveX,
                  moveY: _moveY,
                ),

                // 11. Pause overlay
                if (gameState.phase == GamePhase.paused)
                  _PauseOverlay(gameState: gameState),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWinScreen(GameState gameState) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'YOU ESCAPED',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 36,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Time: ${gameState.formattedTime}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontFamily: 'Courier',
              ),
            ),
            Text(
              'Score: ${gameState.score}',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 18,
                fontFamily: 'Courier',
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                gameState.returnToMenu();
                Navigator.of(context).pushReplacementNamed('/');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                ),
                child: const Text(
                  'MAIN MENU',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 16,
                    fontFamily: 'Courier',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeathScreen(GameState gameState) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'YOU DIED',
              style: TextStyle(
                color: Color(0xFFFF0000),
                fontSize: 42,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    gameState.startGame();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF8B0000), width: 2),
                    ),
                    child: const Text(
                      'RETRY',
                      style: TextStyle(
                        color: Color(0xFFFF0000),
                        fontSize: 14,
                        fontFamily: 'Courier',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    gameState.returnToMenu();
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Text(
                      'QUIT',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        fontFamily: 'Courier',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom control panel
class _BottomControls extends StatelessWidget {
  final GameState gameState;
  final void Function(double x, double y) onMove;
  final VoidCallback onFlashlightToggle;
  final VoidCallback onInteract;
  final VoidCallback onRunToggle;
  final VoidCallback onPause;

  const _BottomControls({
    required this.gameState,
    required this.onMove,
    required this.onFlashlightToggle,
    required this.onInteract,
    required this.onRunToggle,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left side: Joystick
        JoystickWidget(
          onMove: onMove,
          size: 130,
          accentColor: const Color(0xFF8B0000),
        ),

        // Center: Interact + Run buttons
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interact button (E key)
            if (gameState.canInteract)
              GestureDetector(
                onTap: onInteract,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B0000).withOpacity(0.3),
                    border: Border.all(
                      color: const Color(0xFFFF0000),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withOpacity(0.3),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'E',
                      style: TextStyle(
                        color: Color(0xFFFF0000),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            // Run button
            GestureDetector(
              onLongPressStart: (_) => onRunToggle(),
              onLongPressEnd: (_) => onRunToggle(),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gameState.player.isRunning
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.black26,
                  border: Border.all(
                    color: gameState.player.isRunning
                        ? Colors.orange
                        : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.directions_run,
                  color: gameState.player.isRunning
                      ? Colors.orange
                      : Colors.white24,
                  size: 20,
                ),
              ),
            ),
          ],
        ),

        // Right side: Flashlight + Pause
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlashlightButton(
              isOn: gameState.flashlight.isOn,
              batteryLevel: gameState.flashlight.batteryLevel,
              onToggle: onFlashlightToggle,
            ),
            const SizedBox(height: 10),
            // Pause button
            GestureDetector(
              onTap: onPause,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black26,
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: const Icon(
                  Icons.pause,
                  color: Colors.white24,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Movement processor - applies joystick input each frame
class _MovementProcessor extends StatelessWidget {
  final GameState gameState;
  final double moveX;
  final double moveY;

  const _MovementProcessor({
    required this.gameState,
    required this.moveX,
    required this.moveY,
  });

  @override
  Widget build(BuildContext context) {
    // Apply movement in the next frame
    if (moveX.abs() > 0.1 || moveY.abs() > 0.1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        gameState.player.applyJoystickInput(
          moveX,
          moveY,
          0.033,
          gameState.canWalk,
        );
      });
    } else {
      gameState.player.stopMoving();
    }
    return const SizedBox.shrink();
  }
}

/// Pause overlay
class _PauseOverlay extends StatelessWidget {
  final GameState gameState;

  const _PauseOverlay({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Color(0xFF8B0000),
                fontSize: 32,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => gameState.resumeGame(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8B0000), width: 2),
                ),
                child: const Text(
                  'RESUME',
                  style: TextStyle(
                    color: Color(0xFFFF0000),
                    fontSize: 16,
                    fontFamily: 'Courier',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () {
                gameState.returnToMenu();
                Navigator.of(context).pushReplacementNamed('/');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Text(
                  'QUIT TO MENU',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontFamily: 'Courier',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jumpscare overlay effect
class _JumpscareOverlay extends StatefulWidget {
  @override
  State<_JumpscareOverlay> createState() => _JumpscareOverlayState();
}

class _JumpscareOverlayState extends State<_JumpscareOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final flashIntensity = _controller.value < 0.3
            ? _controller.value / 0.3
            : 1.0 - ((_controller.value - 0.3) / 0.7);

        return Container(
          color: Color.lerp(
            Colors.transparent,
            const Color(0x80FF0000),
            flashIntensity,
          ),
        );
      },
    );
  }
}
