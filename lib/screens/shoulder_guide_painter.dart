import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShoulderGuidePainter extends CustomPainter {
  final Offset? leftShoulderNorm;
  final Offset? rightShoulderNorm;
  final double shoulderWidthNorm;

  ShoulderGuidePainter({
    required this.leftShoulderNorm,
    required this.rightShoulderNorm,
    required this.shoulderWidthNorm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (leftShoulderNorm == null || rightShoulderNorm == null) return;

    final left = Offset(
      leftShoulderNorm!.dx * size.width,
      leftShoulderNorm!.dy * size.height,
    );
    final right = Offset(
      rightShoulderNorm!.dx * size.width,
      rightShoulderNorm!.dy * size.height,
    );

    final shoulderPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(left, 6, shoulderPaint);
    canvas.drawCircle(right, 6, shoulderPaint);
    canvas.drawLine(left, right, shoulderPaint);

    final center = Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);

    final shoulderWidthPx = math.max(40.0, shoulderWidthNorm * size.width);
    final guideWidth = (shoulderWidthPx * 1.35).clamp(80.0, size.width * 0.95);
    final guideHeight = (guideWidth * 1.25).clamp(120.0, size.height * 0.9);

    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + guideHeight * 0.25),
      width: guideWidth,
      height: guideHeight,
    );

    final guidePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.75)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, guidePaint);
  }

  @override
  bool shouldRepaint(covariant ShoulderGuidePainter oldDelegate) {
    return oldDelegate.leftShoulderNorm != leftShoulderNorm ||
        oldDelegate.rightShoulderNorm != rightShoulderNorm ||
        oldDelegate.shoulderWidthNorm != shoulderWidthNorm;
  }
}
