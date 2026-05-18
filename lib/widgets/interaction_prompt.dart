import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/game_map.dart' show InteractionType;

/// Interaction prompt widget - shows action hints when near objects
class InteractionPrompt extends StatelessWidget {
  final GameState gameState;

  const InteractionPrompt({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    if (gameState.isSearching) {
      return _buildSearchPrompt();
    }

    if (!gameState.canInteract || gameState.nearbyObject == null) {
      return const SizedBox.shrink();
    }

    final obj = gameState.nearbyObject!;
    String actionText;
    IconData actionIcon;
    Color accentColor;

    switch (obj.type) {
      case InteractionType.door:
        actionText = 'OPEN';
        actionIcon = Icons.door_front_door;
        accentColor = const Color(0xFF8B0000);
        break;
      case InteractionType.item:
        if (obj.id.startsWith('medkit_')) {
          actionText = 'USE';
          actionIcon = Icons.medical_services;
          accentColor = const Color(0xFF00FF00);
        } else if (obj.id == 'crowbar') {
          actionText = 'PICK UP';
          actionIcon = Icons.build;
          accentColor = const Color(0xFFFF8800);
        } else {
          actionText = 'PICK UP';
          actionIcon = Icons.back_hand;
          accentColor = const Color(0xFFFFD700);
        }
        break;
      case InteractionType.note:
        actionText = 'READ';
        actionIcon = Icons.description;
        accentColor = const Color(0xFFD4C5A9);
        break;
      case InteractionType.container:
        actionText = 'SEARCH';
        actionIcon = Icons.search;
        accentColor = const Color(0xFFFF8800);
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Object label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
            ),
            child: Text(
              obj.label,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Action button hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actionIcon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  actionText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'E',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Key requirement hint for doors
          if (obj.type == InteractionType.door && obj.requiredKey != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                gameState.inventory.contains(obj.requiredKey)
                    ? 'Use ${obj.requiredKey!.replaceAll('_', ' ')}'
                    : (gameState.hasCrowbar ? 'Locked - Requires ${obj.requiredKey!.replaceAll('_', ' ')} or Crowbar' : 'Locked - Requires ${obj.requiredKey!.replaceAll('_', ' ')}'),
                style: TextStyle(
                  color: gameState.inventory.contains(obj.requiredKey)
                      ? Colors.green
                      : Colors.red,
                  fontSize: 10,
                  fontFamily: 'Courier',
                ),
              ),
            ),
          // Noise warning for containers
          if (obj.type == InteractionType.container && obj.makesNoise)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, color: Colors.orange.withOpacity(0.7), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'WARNING: Loud!',
                    style: TextStyle(
                      color: Colors.orange.withOpacity(0.7),
                      fontSize: 9,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Search progress prompt
  Widget _buildSearchPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Searching label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFF8800), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, color: Color(0xFFFF8800), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      gameState.searchMessage ?? 'Searching...',
                      style: const TextStyle(
                        color: Color(0xFFFF8800),
                        fontSize: 13,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                SizedBox(
                  width: 150,
                  height: 6,
                  child: LinearProgressIndicator(
                    value: gameState.searchProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF8800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
