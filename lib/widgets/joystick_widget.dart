import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Virtual Joystick Widget for player movement
class JoystickWidget extends StatefulWidget {
  final void Function(double x, double y) onMove;
  final double size;
  final Color accentColor;

  const JoystickWidget({
    super.key,
    required this.onMove,
    this.size = 140,
    this.accentColor = const Color(0xFF8B0000),
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _offset = Offset.zero;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black26,
          border: Border.all(
            color: widget.accentColor.withOpacity(0.4),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Direction indicators
            _buildDirectionIndicators(),
            // Joystick knob
            Center(
              child: Transform.translate(
                offset: _offset,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPressed
                        ? widget.accentColor.withOpacity(0.6)
                        : widget.accentColor.withOpacity(0.3),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.circle,
                    color: Colors.white24,
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionIndicators() {
    return Center(
      child: SizedBox(
        width: widget.size - 20,
        height: widget.size - 20,
        child: CustomPaint(
          painter: _DirectionIndicatorPainter(
            color: widget.accentColor.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isPressed = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final center = Offset.zero;
    final maxRadius = (widget.size - 50) / 2;

    var dx = details.localPosition.dx - widget.size / 2;
    var dy = details.localPosition.dy - widget.size / 2;

    // Clamp to circle
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > maxRadius) {
      dx = dx / distance * maxRadius;
      dy = dy / distance * maxRadius;
    }

    setState(() {
      _offset = Offset(dx, dy);
    });

    // Normalize to -1.0 to 1.0
    final normalizedX = -dx / maxRadius; // Negative because left strafe
    final normalizedY = -dy / maxRadius; // Negative because forward

    widget.onMove(normalizedX, normalizedY);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _offset = Offset.zero;
      _isPressed = false;
    });
    widget.onMove(0, 0);
  }
}

/// Direction indicator painter (cross pattern)
class _DirectionIndicatorPainter extends CustomPainter {
  final Color color;

  _DirectionIndicatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);

    // Horizontal line
    canvas.drawLine(
      Offset(20, center.dy),
      Offset(size.width - 20, center.dy),
      paint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, 20),
      Offset(center.dx, size.height - 20),
      paint,
    );

    // Arrow indicators
    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    // Up arrow
    canvas.drawLine(
      Offset(center.dx - 5, 25),
      Offset(center.dx, 20),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 5, 25),
      Offset(center.dx, 20),
      arrowPaint,
    );

    // Down arrow
    canvas.drawLine(
      Offset(center.dx - 5, size.height - 25),
      Offset(center.dx, size.height - 20),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 5, size.height - 25),
      Offset(center.dx, size.height - 20),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
