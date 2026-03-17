import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectorService {
  // MediaPipeのposedetectorのインスタンスを生成
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _isBusy = false;

  // Androidでは端末の向きによる回転補正が必要。
  // DeviceOrientationを角度へ変換するために使う。
  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  // カメラ画像を受け取り、両肩の座標(Offset)のリストを返す関数
  Future<List<Offset>?> processFrame(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    if (_isBusy) return null;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(
        image,
        camera,
        deviceOrientation,
      );
      if (inputImage == null) return null;

      final poses = await _poseDetector.processImage(
        inputImage,
      ); // processImage: ML Kitに画像を投げて、体中の関節（Landmarks）を探させる
      if (poses.isEmpty) return null;

      final pose = poses.first;
      // 左右の方の座標を取得
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

      if (leftShoulder == null || rightShoulder == null) return null;

      // 毎フレームのprintはパフォーマンスに影響するため抑制する。

      return [
        Offset(leftShoulder.x, leftShoulder.y),
        Offset(rightShoulder.x, rightShoulder.y),
      ];
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isBusy = false;
    }
    return null;
  }

  Future<void> dispose() async {
    await _poseDetector.close();
  }

  // ML Kit用の画像フォーマットに変換
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 公式サンプルと同じく、端末向きとカメラ向きを合成して補正する。
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final rawFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rawFormat == null) return null;

    if (image.planes.isEmpty) return null;

    late final Uint8List bytes;
    late final InputImageFormat inputImageFormat;
    late final int bytesPerRow;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (rawFormat == InputImageFormat.yuv_420_888 &&
          image.planes.length == 3) {
        bytes = _yuv420ToNv21(image);
        inputImageFormat = InputImageFormat.nv21;
        bytesPerRow = image.width;
      } else if (rawFormat == InputImageFormat.nv21) {
        bytes = image.planes.first.bytes;
        inputImageFormat = InputImageFormat.nv21;
        bytesPerRow = image.planes.first.bytesPerRow;
      } else {
        return null;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (rawFormat != InputImageFormat.bgra8888) return null;
      bytes = image.planes.first.bytes;
      inputImageFormat = InputImageFormat.bgra8888;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else {
      return null;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = ySize ~/ 2;

    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    var writeIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      for (var col = 0; col < width; col++) {
        nv21[writeIndex++] = yPlane.bytes[rowStart + col];
      }
    }

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;

    for (var row = 0; row < uvHeight; row++) {
      final rowStart = row * uvRowStride;
      for (var col = 0; col < uvWidth; col++) {
        final uvIndex = rowStart + col * uvPixelStride;
        nv21[writeIndex++] = vPlane.bytes[uvIndex];
        nv21[writeIndex++] = uPlane.bytes[uvIndex];
      }
    }

    return nv21;
  }
}
