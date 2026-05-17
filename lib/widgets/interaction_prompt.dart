import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/game_map.dart' show InteractionType;

/// Interaction prompt widget - shows "Open", "Pick up", "Read" when near objects
class InteractionPrompt extends StatelessWidget {
  final GameState gameState;

  const InteractionPrompt({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
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
        actionText = 'PICK UP';
        actionIcon = Icons.back_hand;
        accentColor = const Color(0xFFFFD700);
        break;
      case InteractionType.note:
        actionText = 'READ';
        actionIcon = Icons.description;
        accentColor = const Color(0xFFD4C5A9);
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Object label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
            ),
            child: Text(
              obj.label,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Action button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                Icon(actionIcon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  actionText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
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
                      fontSize: 12,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Key requirement hint
          if (obj.type == InteractionType.door && obj.requiredKey != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                gameState.inventory.contains(obj.requiredKey)
                    ? 'Use ${obj.requiredKey!.replaceAll('_', ' ')}'
                    : 'Locked - Requires ${obj.requiredKey!.replaceAll('_', ' ')}',
                style: TextStyle(
                  color: gameState.inventory.contains(obj.requiredKey)
                      ? Colors.green
                      : Colors.red,
                  fontSize: 11,
                  fontFamily: 'Courier',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
