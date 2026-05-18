import 'package:flutter/material.dart';

/// Message display widget for game messages
/// Positioned at TOP area (called from game_screen with top positioning)
class MessageOverlay extends StatelessWidget {
  final String? message;
  final Color color;

  const MessageOverlay({
    super.key,
    required this.message,
    this.color = const Color(0xFFFFD700),
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Text(
          message!,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
