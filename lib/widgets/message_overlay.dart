import 'package:flutter/material.dart';

/// Message display widget for game messages
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
      child: Padding(
        padding: const EdgeInsets.only(bottom: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Text(
            message!,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
