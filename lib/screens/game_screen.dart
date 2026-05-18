import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/game_state.dart';
import '../core/game_map.dart' show InteractionType;
import '../core/ghost.dart' show GhostState;
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
  Timer? _gameLoop;
  final AudioManager _audioManager = AudioManager();
  Offset? _touchStart;
  Offset? _touchCurrent;
  double _moveX = 0.0;
  double _moveY = 0.0;
  bool _hasStartedPlaying = false;
  GhostState? _prevGhostState;
  bool _prevJumpscare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startGameLoop();
    _initAudioSafely();
  }

  Future<void> _initAudioSafely() async {
    try { await _audioManager.init(); } catch (e) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameLoop?.cancel();
    _audioManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  void _startGameLoop() {
    _gameLoop?.cancel();
    _gameLoop = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        if (!mounted) return;
        final gameState = context.read<GameState>();
        if (gameState.phase == GamePhase.playing) {
          _hasStartedPlaying = true;

          // Apply movement (but not if searching - player must stay still)
          if (!gameState.isSearching) {
            if (_moveX.abs() > 0.08 || _moveY.abs() > 0.08) {
              gameState.player.applyJoystickInput(
                _moveX, _moveY, 0.033, gameState.canWalk,
              );
              // Moving cancels search
            } else {
              gameState.player.stopMoving();
            }
          } else {
            // If player moves while searching, cancel the search
            if (_moveX.abs() > 0.3 || _moveY.abs() > 0.3) {
              gameState.cancelSearch();
            }
            gameState.player.stopMoving();
          }

          gameState.update(0.033);

          // Vibrate when ghost starts chasing
          if (_prevGhostState != GhostState.chase && gameState.ghost.state == GhostState.chase) {
            HapticFeedback.heavyImpact();
          }
          if (_prevGhostState != GhostState.noiseAlert && gameState.ghost.state == GhostState.noiseAlert) {
            HapticFeedback.mediumImpact();
          }

          if (!_prevJumpscare && gameState.jumpscareActive) {
            HapticFeedback.mediumImpact();
          }

          if (gameState.killedByGhost && gameState.phase == GamePhase.dead) {
            HapticFeedback.heavyImpact();
            Future.delayed(const Duration(milliseconds: 200), () { HapticFeedback.heavyImpact(); });
            Future.delayed(const Duration(milliseconds: 400), () { HapticFeedback.heavyImpact(); });
          }

          // Damage vibration
          if (gameState.damageFlashActive) {
            HapticFeedback.lightImpact();
          }

          _prevGhostState = gameState.ghost.state;
          _prevJumpscare = gameState.jumpscareActive;

          try {
            if (gameState.player.isMoving) {
              _audioManager.playFootstep();
            }
            _audioManager.updateAmbientIntensity(gameState.ambientIntensity);
          } catch (e) {}
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvoked: (_) { context.read<GameState>().pauseGame(); },
      child: Scaffold(
        body: Consumer<GameState>(
          builder: (context, gameState, _) {
            if (gameState.phase == GamePhase.playing) _hasStartedPlaying = true;
            if (gameState.phase == GamePhase.won) return _buildWinScreen(gameState);
            if (gameState.phase == GamePhase.dead) return _buildDeathScreen(gameState);

            return Stack(
              children: [
                // 1. 3D Raycasting Renderer
                Positioned.fill(child: RaycastRenderer(gameState: gameState)),

                // 2. Camera Overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: CameraOverlay(
                      isRecording: gameState.phase == GamePhase.playing,
                      batteryLevel: gameState.flashlight.batteryLevel,
                      timestamp: gameState.formattedTime,
                      showCrosshair: true,
                      glitchIntensity: gameState.cameraGlitchIntensity,
                    ),
                  ),
                ),

                // 3. Game HUD
                GameHUD(
                  score: gameState.score,
                  gameTime: gameState.formattedTime,
                  stamina: gameState.player.stamina,
                  health: gameState.player.health,
                  inventory: gameState.inventory,
                  hasCrowbar: gameState.hasCrowbar,
                ),

                // 4. Touch look area - RIGHT SIDE ONLY
                Positioned(
                  top: 0,
                  left: screenWidth * 0.35,
                  right: 0,
                  bottom: 120,
                  child: GestureDetector(
                    onPanStart: (details) { _touchStart = details.globalPosition; _touchCurrent = details.globalPosition; },
                    onPanUpdate: (details) {
                      if (_touchCurrent != null) {
                        final dx = details.globalPosition.dx - _touchCurrent!.dx;
                        gameState.player.applyLookInput(dx);
                        _touchCurrent = details.globalPosition;
                      }
                    },
                    onPanEnd: (_) { _touchStart = null; _touchCurrent = null; },
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),

                // 5. Interaction prompt / Search progress
                if (gameState.canInteract || gameState.isSearching)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: InteractionPrompt(gameState: gameState),
                  ),

                // 6. Message overlay
                if (gameState.currentMessage != null)
                  Positioned(
                    top: 140,
                    left: 20,
                    right: 20,
                    child: MessageOverlay(message: gameState.currentMessage),
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
                  Positioned.fill(child: _JumpscareOverlay()),

                // 9. Damage flash overlay (red flash when ghost hurts player)
                if (gameState.damageFlashActive)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: const Color(0x40FF0000),
                      ),
                    ),
                  ),

                // 10. Bottom controls
                Positioned(
                  bottom: 15,
                  left: 10,
                  right: 10,
                  child: _BottomControls(
                    gameState: gameState,
                    onMove: (x, y) { _moveX = x; _moveY = y; },
                    onFlashlightToggle: () {
                      gameState.toggleFlashlight();
                      try { _audioManager.playFlashlightToggle(); } catch (e) {}
                    },
                    onInteract: () {
                      gameState.interact();
                      final obj = gameState.nearbyObject;
                      if (obj != null) {
                        try {
                          switch (obj.type) {
                            case InteractionType.door: _audioManager.playDoorOpen();
                            case InteractionType.item:
                              if (obj.id.startsWith('key_')) { _audioManager.playKeyPickup(); }
                              else { _audioManager.playItemPickup(); }
                            case InteractionType.note: break;
                            case InteractionType.container: break;
                          }
                        } catch (e) {}
                      }
                    },
                    onRunToggle: () => gameState.toggleRun(),
                    onPause: () => gameState.pauseGame(),
                  ),
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
            const Text('YOU ESCAPED', style: TextStyle(color: Color(0xFFFFD700), fontSize: 36, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 30),
            Text('Time: ${gameState.formattedTime}', style: const TextStyle(color: Colors.white54, fontSize: 18, fontFamily: 'Courier')),
            Text('Score: ${gameState.score}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontFamily: 'Courier')),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () { gameState.returnToMenu(); Navigator.of(context).pushReplacementNamed('/'); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFFD700), width: 2)),
                child: const Text('MAIN MENU', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontFamily: 'Courier', letterSpacing: 2)),
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
            const Text('YOU DIED', style: TextStyle(color: Color(0xFFFF0000), fontSize: 42, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 6)),
            const SizedBox(height: 15),
            Text(gameState.killedByGhost ? 'She caught you...' : 'You couldn\'t survive...',
              style: const TextStyle(color: Color(0xFF880000), fontSize: 16, fontFamily: 'Courier', letterSpacing: 2)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => gameState.startGame(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8B0000), width: 2)),
                    child: const Text('RETRY', style: TextStyle(color: Color(0xFFFF0000), fontSize: 14, fontFamily: 'Courier', letterSpacing: 2)),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () { gameState.returnToMenu(); Navigator.of(context).pushReplacementNamed('/'); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 1)),
                    child: const Text('QUIT', style: TextStyle(color: Colors.white38, fontSize: 14, fontFamily: 'Courier', letterSpacing: 2)),
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
    required this.gameState, required this.onMove,
    required this.onFlashlightToggle, required this.onInteract,
    required this.onRunToggle, required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: JoystickWidget(onMove: onMove, size: 150, accentColor: const Color(0xFF8B0000)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // E - Interact/Search button
              if (gameState.canInteract || gameState.isSearching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: gameState.isSearching ? null : onInteract,
                    child: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gameState.isSearching
                            ? const Color(0xFFFF8800).withOpacity(0.4)
                            : const Color(0xFF8B0000).withOpacity(0.4),
                        border: Border.all(
                          color: gameState.isSearching
                              ? const Color(0xFFFF8800)
                              : const Color(0xFFFF0000),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (gameState.isSearching
                                ? const Color(0xFFFF8800)
                                : const Color(0xFFFF0000)).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: gameState.isSearching
                          ? const Center(
                              child: SizedBox(
                                width: 30, height: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFFFF8800)),
                                ),
                              ),
                            )
                          : const Center(
                              child: Text('E', style: TextStyle(color: Color(0xFFFF0000), fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                            ),
                    ),
                  ),
                ),
              // Run + Flashlight row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onLongPressStart: (_) => onRunToggle(),
                    onLongPressEnd: (_) => onRunToggle(),
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gameState.player.isRunning ? Colors.orange.withOpacity(0.35) : Colors.black38,
                        border: Border.all(color: gameState.player.isRunning ? Colors.orange : Colors.white24, width: 1.5),
                      ),
                      child: Icon(Icons.directions_run, color: gameState.player.isRunning ? Colors.orange : Colors.white24, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FlashlightButton(isOn: gameState.flashlight.isOn, batteryLevel: gameState.flashlight.batteryLevel, onToggle: onFlashlightToggle),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onPause,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black26, border: Border.all(color: Colors.white12, width: 1)),
                  child: const Icon(Icons.pause, color: Colors.white24, size: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
            const Text('PAUSED', style: TextStyle(color: Color(0xFF8B0000), fontSize: 32, fontFamily: 'Courier', fontWeight: FontWeight.bold, letterSpacing: 6)),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () => gameState.resumeGame(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8B0000), width: 2)),
                child: const Text('RESUME', style: TextStyle(color: Color(0xFFFF0000), fontSize: 16, fontFamily: 'Courier', letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () { gameState.returnToMenu(); Navigator.of(context).pushReplacementNamed('/'); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 1)),
                child: const Text('QUIT TO MENU', style: TextStyle(color: Colors.white38, fontSize: 14, fontFamily: 'Courier', letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JumpscareOverlay extends StatefulWidget {
  @override
  State<_JumpscareOverlay> createState() => _JumpscareOverlayState();
}

class _JumpscareOverlayState extends State<_JumpscareOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final flashIntensity = _controller.value < 0.3 ? _controller.value / 0.3 : 1.0 - ((_controller.value - 0.3) / 0.7);
        return Container(color: Color.lerp(Colors.transparent, const Color(0x80FF0000), flashIntensity));
      },
    );
  }
}
