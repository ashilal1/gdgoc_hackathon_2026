import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

export 'pose_painter.dart';

class SkeletonRecognizer {
  // MediaPipe (BlazePose) の高精度エンジンを初期化
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.accurate, // ここでMediaPipeのHeavyモデルを指定
      mode: PoseDetectionMode.stream,
    ),
  );

  bool _isBusy = false;

  // 端末の向き(DeviceOrientation)を角度へ変換するためのマップ。
  // Android の回転補正計算で使用する。
  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// カメラ映像を解析して、検出された骨格(Pose)のリストを返す
  Future<List<Pose>> recognize(
    CameraImage image,
    CameraDescription camera, {
    DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp,
  }) async {
    // 処理中に新しいフレームが来たらスキップ（パフォーマンス確保）
    if (_isBusy) return [];
    _isBusy = true;

    try {
      final inputImage = _convertToInputImage(image, camera, deviceOrientation);
      if (inputImage == null) {
        // 画像フォーマットやメタデータが不正なフレームは安全にスキップする。
        return [];
      }
      final poses = await _poseDetector.processImage(inputImage);
      return poses;
    } catch (e) {
      // 毎フレーム呼ばれる処理なので、debugPrintを使ってログ負荷を抑える。
      debugPrint('骨格検出エラー: $e');
      return [];
    } finally {
      _isBusy = false;
    }
  }

  /// CameraImageをML Kitが読める形式に変換する内部メソッド
  InputImage? _convertToInputImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    // 1) 回転情報を計算する。Androidは端末向きとカメラ向きを合成する必要がある。
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        // インカメラは向きが鏡像になるため、加算補正。
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // バックカメラは減算補正。
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    // 2) ML Kit が受け取れる画像フォーマットかを判定する。
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    const androidSupportedFormats = [
      InputImageFormat.nv21,
      InputImageFormat.yv12,
      InputImageFormat.yuv_420_888,
    ];

    if ((Platform.isAndroid && !androidSupportedFormats.contains(format)) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // 3) bytes と metadata を整形する。
    // AndroidでYUV_420_888/YV12の3planeを受けた場合はNV21へ変換する。
    late final Uint8List bytes;
    late final InputImageFormat resolvedFormat;
    late final int bytesPerRow;

    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
      resolvedFormat = format;
      bytesPerRow = image.planes.first.bytesPerRow;
    } else if (Platform.isAndroid &&
        (format == InputImageFormat.yuv_420_888 ||
            format == InputImageFormat.yv12) &&
        image.planes.length == 3) {
      bytes = _yuv420ToNv21(image);
      resolvedFormat = InputImageFormat.nv21;
      bytesPerRow = image.width;
    } else {
      return null;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: resolvedFormat,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  // YUV420(3plane)をNV21(1plane相当)に詰め直す。
  // ML KitのAndroid入力で扱いやすい形に揃えるための変換。
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

    // 先にY成分を書き込む。
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

    // NV21はVU順で並ぶため、V→Uの順で交互に書き込む。
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

  /// メモリ解放
  Future<void> dispose() async {
    await _poseDetector.close();
  }
}
