// 画面全体にカメラ映像を表示するためのコード

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_painter.dart';
import 'screen_recognize_skelton.dart';

class ARCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ARCameraScreen({super.key, required this.cameras});

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  late CameraController _controller;
  late CameraDescription _camera;
  final SkeletonRecognizer _skeletonRecognizer = SkeletonRecognizer();

  List<Pose> _poses = const [];
  Size _imageSize = Size.zero;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  bool _isInitialized = false; // カメラの準備が完了したかどうかを記録するフラグ

  // Android の回転補正で使う、端末向き -> 角度の対応表。
  final _orientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();

    _camera = widget.cameras.first;

    _controller = CameraController(
      _camera,
      ResolutionPreset.high,
      enableAudio: false,
      // ML Kit 公式サンプル準拠: Androidはnv21, iOSはbgra8888を指定する。
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _controller
        .initialize()
        .then((_) async {
          if (!mounted) return;

          // カメラ初期化完了後に画像ストリームを開始し、毎フレーム骨格推定を行う。
          await _controller.startImageStream((image) async {
            final deviceOrientation = _controller.value.deviceOrientation;

            final poses = await _skeletonRecognizer.recognize(
              image,
              _camera,
              deviceOrientation: deviceOrientation,
            );

            if (!mounted) return;

            setState(() {
              _poses = poses;
              _imageSize = Size(
                image.width.toDouble(),
                image.height.toDouble(),
              );
              _rotation = _resolveRotation(_camera, deviceOrientation);
            });
          });

          setState(() {
            _isInitialized = true;
          });
        })
        .catchError((e) {
          debugPrint('Camera Error: $e');
        });
  }

  @override
  void dispose() {
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream();
    }
    _controller.dispose();
    _skeletonRecognizer.dispose();
    super.dispose();
  }

  // PosePainterと同じ向きで描画するため、画像回転を算出する。
  InputImageRotation _resolveRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation = _orientations[deviceOrientation] ?? 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      return InputImageRotationValue.fromRawValue(rotationCompensation) ??
          InputImageRotation.rotation0deg;
    }

    return InputImageRotation.rotation0deg;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: 1 / _controller.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ベースとなるカメラ映像。
              CameraPreview(_controller),
              // 検出結果があるときだけ骨格を重ね描きする。
              if (_poses.isNotEmpty)
                CustomPaint(
                  painter: PosePainter(
                    _poses,
                    _imageSize,
                    _rotation,
                    _camera.lensDirection,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
