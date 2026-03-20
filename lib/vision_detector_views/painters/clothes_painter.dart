import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'coordinates_translator.dart';

class ClothesPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final ui.Image clothesImage;
  final num clothesBaseShoulderWidthPx;

  ClothesPainter(
    this.poses,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
    this.clothesImage,
    this.clothesBaseShoulderWidthPx,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    final pose = poses.first;
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder != null && rightShoulder != null) {
      // ステップ2: 解像度ズレの補正 (画面座標への変換)
      final leftX = translateX(
        leftShoulder.x,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final leftY = translateY(
        leftShoulder.y,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final rightX = translateX(
        rightShoulder.x,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final rightY = translateY(
        rightShoulder.y,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );

      // ステップ3: 服の配置基準点「ネックライン」の算出
      final centerX = (leftX + rightX) / 2;
      // 首の付け根の高さに合わせる（以前は上にオフセットしていましたが、顔が隠れる原因になるため基準をそのまま使用）
      final centerY = (leftY + rightY) / 2;

      // ステップ4: 肩幅ピクセル距離と動的スケールの計算
      double dx = rightX - leftX;
      double dy = rightY - leftY;

      // フロントカメラ鏡面反射等で左右が反転している場合の補正（上下逆さま防止）
      if (leftX > rightX) {
        dx = leftX - rightX;
        dy = leftY - rightY;
      }

      final shoulderDistance = sqrt(dx * dx + dy * dy);

      // 服画像の本来の幅に対するスケール比率
      // baseShoulderWidthPx が0より大きければその値を使用、なければ画像幅で代用
      final baseWidth = clothesBaseShoulderWidthPx > 0
          ? clothesBaseShoulderWidthPx
          : clothesImage.width;

      // 骨格サイズ(関節間)と服の全体のサイズのギャップを埋めるための倍率補正
      // 2.2の部分を画面に合わせて調整してください
      final double scaleMultiplier = 0.7; // 服の見た目の大きさを調整するための定数
      final scale = (shoulderDistance / baseWidth) * scaleMultiplier;

      // ステップ5: ユーザーの傾きへの追従計算 (回転角)
      final angle = atan2(dy, dx);

      // ステップ6: 描画
      canvas.save();
      canvas.translate(centerX, centerY);
      if (cameraLensDirection == CameraLensDirection.front) {
        // フロントカメラの場合は鏡のように反転しているので、左右の角度と画像を合わせる調整が必要な場合があります。
        // 今回は単純な傾き反映
        canvas.rotate(angle);
      } else {
        canvas.rotate(angle);
      }

      canvas.scale(scale);

      // 画像の襟元が肩の高さに来るように、Y軸のオフセットを調整する
      // -clothesImage.height / 2 (中心) から、上から15%程度の位置に変更
      double neckOffsetY = clothesImage.height * 0.15;

      canvas.drawImage(
        clothesImage,
        Offset(-clothesImage.width / 2, -neckOffsetY),
        Paint(),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ClothesPainter oldDelegate) => true;
}
