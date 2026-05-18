import 'package:flutter/material.dart';

/// HUD overlay showing game status info
class GameHUD extends StatelessWidget {
  final int score;
  final String gameTime;
  final double stamina;
  final double health;
  final Set<String> inventory;
  final bool hasCrowbar;

  const GameHUD({
    super.key,
    required this.score,
    required this.gameTime,
    required this.stamina,
    required this.health,
    required this.inventory,
    this.hasCrowbar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hudItem(icon: Icons.star, label: 'SCORE', value: score.toString(), color: const Color(0xFFFFD700)),
          const SizedBox(height: 6),
          _hudItem(icon: Icons.access_time, label: 'TIME', value: gameTime, color: Colors.white38),
          const SizedBox(height: 6),
          // Health bar (PROMINENT - red when low)
          _healthBar(),
          const SizedBox(height: 6),
          // Stamina bar
          _staminaBar(),
          // Inventory indicators
          if (inventory.isNotEmpty) ...[
            const SizedBox(height: 10),
            _inventoryDisplay(),
          ],
        ],
      ),
    );
  }

  Widget _hudItem({required IconData icon, required String label, required String value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'Courier')),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _healthBar() {
    final healthColor = health > 60
        ? Colors.green
        : health > 30
            ? Colors.yellow
            : Colors.red;

    // Pulse when low health
    final isLow = health < 30;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite, color: isLow ? Colors.red : Colors.white24, size: 12),
        const SizedBox(width: 4),
        SizedBox(
          width: 70,
          height: 5,
          child: Stack(
            children: [
              // Background
              Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Health fill
              FractionallySizedBox(
                widthFactor: (health / 100.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: healthColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isLow ? [
                      BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 6),
                    ] : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text('${health.toInt()}',
          style: TextStyle(
            color: healthColor,
            fontSize: 9,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _staminaBar() {
    final staminaColor = stamina > 50
        ? Colors.green
        : stamina > 20
            ? Colors.yellow
            : Colors.red;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_run, color: Colors.white24, size: 12),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          height: 4,
          child: LinearProgressIndicator(
            value: stamina / 100.0,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(staminaColor),
          ),
        ),
      ],
    );
  }

  Widget _inventoryDisplay() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INVENTORY', style: TextStyle(color: Colors.white24, fontSize: 8, fontFamily: 'Courier')),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: inventory.map((item) {
              IconData icon;
              Color color;
              if (item.startsWith('key_')) {
                icon = Icons.vpn_key;
                color = const Color(0xFFFFD700);
              } else if (item == 'crowbar') {
                icon = Icons.build;
                color = const Color(0xFFFF8800);
              } else {
                icon = Icons.battery_charging_full;
                color = Colors.green;
              }
              return Icon(icon, color: color, size: 14);
            }).toList(),
          ),
        ],
      ),
    );
  }
}
