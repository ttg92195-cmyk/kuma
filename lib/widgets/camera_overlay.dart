import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Camera Overlay UI - Found-Footage Style
/// REC indicator, battery level, timer, vignette, noise filter
class CameraOverlay extends StatelessWidget {
  final bool isRecording;
  final double batteryLevel;
  final String timestamp;
  final bool showCrosshair;

  const CameraOverlay({
    super.key,
    this.isRecording = true,
    this.batteryLevel = 100.0,
    this.timestamp = '00:00:00',
    this.showCrosshair = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left: REC indicator
        Positioned(
          top: 40,
          left: 20,
          child: _RecIndicator(isActive: isRecording),
        ),

        // Top-right: Battery & Timer
        Positioned(
          top: 40,
          right: 20,
          child: _CameraInfo(
            batteryLevel: batteryLevel,
            timestamp: timestamp,
          ),
        ),

        // Center: Crosshair
        if (showCrosshair)
          Center(
            child: _Crosshair(),
          ),

        // Bottom: Camera info bar
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: _CameraBottomBar(),
        ),

        // Corner frame markers
        _CornerFrame(),
      ],
    );
  }
}

/// REC indicator with blinking red dot
class _RecIndicator extends StatefulWidget {
  final bool isActive;
  const _RecIndicator({required this.isActive});

  @override
  State<_RecIndicator> createState() => _RecIndicatorState();
}

class _RecIndicatorState extends State<_RecIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _controller,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFFF0000),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'REC',
          style: TextStyle(
            color: Color(0xFFFF0000),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

/// Camera info display (battery + timestamp)
class _CameraInfo extends StatelessWidget {
  final double batteryLevel;
  final String timestamp;

  const _CameraInfo({
    required this.batteryLevel,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Battery indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: batteryLevel > 20 ? Colors.white30 : const Color(0xFFFF0000),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.battery_full,
                color: batteryLevel > 50
                    ? Colors.white54
                    : batteryLevel > 20
                        ? Colors.yellow
                        : const Color(0xFFFF0000),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${batteryLevel.toInt()}%',
                style: TextStyle(
                  color: batteryLevel > 20 ? Colors.white54 : const Color(0xFFFF0000),
                  fontSize: 12,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Timestamp
        Text(
          timestamp,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }
}

/// Center crosshair
class _Crosshair extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CrosshairPainter(),
      size: const Size(30, 30),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    // Small cross
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx - 3, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 3, center.dy),
      Offset(center.dx + 8, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy - 3),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + 3),
      Offset(center.dx, center.dy + 8),
      paint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom camera info bar
class _CameraBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'CAM 01',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontFamily: 'Courier',
            ),
          ),
          Text(
            'WARD-B ${DateTime.now().year}',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontFamily: 'Courier',
            ),
          ),
          const Text(
            'NIGHT VISION',
            style: TextStyle(
              color: Colors.white12,
              fontSize: 10,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner frame markers (like a camera viewfinder)
class _CornerFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left corner
        Positioned(
          top: 20,
          left: 10,
          child: _cornerBracket(Alignment.topLeft),
        ),
        // Top-right corner
        Positioned(
          top: 20,
          right: 10,
          child: _cornerBracket(Alignment.topRight),
        ),
        // Bottom-left corner
        Positioned(
          bottom: 80,
          left: 10,
          child: _cornerBracket(Alignment.bottomLeft),
        ),
        // Bottom-right corner
        Positioned(
          bottom: 80,
          right: 10,
          child: _cornerBracket(Alignment.bottomRight),
        ),
      ],
    );
  }

  Widget _cornerBracket(Alignment alignment) {
    return CustomPaint(
      painter: _CornerBracketPainter(alignment: alignment),
      size: const Size(25, 25),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Alignment alignment;

  _CornerBracketPainter({required this.alignment});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
