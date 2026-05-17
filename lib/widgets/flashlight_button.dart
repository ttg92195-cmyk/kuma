import 'package:flutter/material.dart';

/// Flashlight toggle button widget
class FlashlightButton extends StatelessWidget {
  final bool isOn;
  final double batteryLevel;
  final VoidCallback onToggle;

  const FlashlightButton({
    super.key,
    required this.isOn,
    required this.batteryLevel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = batteryLevel > 50
        ? Colors.yellow
        : batteryLevel > 20
            ? Colors.orange
            : const Color(0xFFFF0000);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? color.withOpacity(0.15) : Colors.black26,
          border: Border.all(
            color: isOn ? color.withOpacity(0.7) : Colors.white24,
            width: 2,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: isOn ? color : Colors.white24,
              size: 28,
            ),
            // Battery arc indicator
            if (isOn)
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: _BatteryArcPainter(
                    batteryLevel: batteryLevel,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Battery arc indicator painter
class _BatteryArcPainter extends CustomPainter {
  final double batteryLevel;
  final Color color;

  _BatteryArcPainter({
    required this.batteryLevel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 degrees (top)
      6.2832, // Full circle
      false,
      bgPaint,
    );

    // Battery arc
    final batteryPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      (batteryLevel / 100.0) * 6.2832,
      false,
      batteryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryArcPainter oldDelegate) {
    return oldDelegate.batteryLevel != batteryLevel;
  }
}
