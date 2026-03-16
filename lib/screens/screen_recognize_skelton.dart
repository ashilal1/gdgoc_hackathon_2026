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

  /// カメラ映像を解析して、検出された骨格(Pose)のリストを返す
  Future<List<Pose>> recognize(CameraImage image, CameraDescription camera) async {
    // 処理中に新しいフレームが来たらスキップ（パフォーマンス確保）
    if (_isBusy) return [];
    _isBusy = true;

    try {
      final inputImage = _convertToInputImage(image, camera);
      final poses = await _poseDetector.processImage(inputImage);
      return poses;
    } catch (e) {
      print('骨格検出エラー: $e');
      return [];
    } finally {
      _isBusy = false;
    }
  }

  /// CameraImageをML Kitが読める形式に変換する内部メソッド
  InputImage _convertToInputImage(CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // デバイスの向き（90度など）をMediaPipeに伝える
    final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) 
                          ?? InputImageRotation.rotation0deg;
    
    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) 
                             ?? InputImageFormat.bgra8888;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  /// メモリ解放
  void dispose() {
    _poseDetector.close();
  }
}