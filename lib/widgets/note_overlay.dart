import 'package:flutter/material.dart';

/// Note reading overlay - shows when player reads a note
class NoteOverlay extends StatelessWidget {
  final String? label;
  final String? content;
  final VoidCallback onClose;

  const NoteOverlay({
    super.key,
    required this.label,
    required this.content,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (content == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A14),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFF4A3A2A), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note title
                if (label != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.description,
                        color: Color(0xFFD4C5A9),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label!,
                        style: const TextStyle(
                          color: Color(0xFFD4C5A9),
                          fontSize: 16,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Divider
                  Container(
                    height: 1,
                    color: const Color(0xFF3A2A1A),
                  ),
                  const SizedBox(height: 16),
                ],
                // Note content
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      content!,
                      style: const TextStyle(
                        color: Color(0xFFC4B599),
                        fontSize: 14,
                        fontFamily: 'Courier',
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Close instruction
                Center(
                  child: Text(
                    '[ TAP TO CLOSE ]',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontFamily: 'Courier',
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
