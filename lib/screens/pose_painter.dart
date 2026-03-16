// 新しく作るファイル：pose_painter.dart

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize; // カメラ映像の元のサイズ

  PosePainter(this.poses, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    // 筆の設定（赤い点で、少し太めに描く）
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4.0
      ..color = Colors.red;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        // 【重要】カメラの解像度と、スマホの画面サイズのズレを補正する計算
        // これがないと、実際の体から赤い点がズレて表示されてしまいます
        final double scaleX = size.width / imageSize.height;
        final double scaleY = size.height / imageSize.width;

        final double x = landmark.x * scaleX;
        final double y = landmark.y * scaleY;

        // 計算した正しい位置に、半径5.0の丸を描く
        canvas.drawCircle(Offset(x, y), 5.0, paint);
      });
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true; // 人が動くたびに、点を描き直す
  }
}