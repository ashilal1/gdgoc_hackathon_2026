// 画面全体にカメラ映像を表示するためのコード

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/pose_detector_service.dart';
import 'shoulder_guide_painter.dart';

class ARCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ARCameraScreen({super.key, required this.cameras});

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;

  final PoseDetectorService _poseDetectorService = PoseDetectorService();

  Offset? _leftShoulderNorm;
  Offset? _rightShoulderNorm;
  double _filteredShoulderWidthNorm = 0.0;

  int _frameCounter = 0;
  static const int _uiUpdateEveryNFrames = 2; // UI更新間引き

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _isInitialized = true);

          _controller.startImageStream((image) async {
            final shoulders = await _poseDetectorService.processFrame(
              image,
              widget.cameras[0],
            );
            if (!mounted || shoulders == null) return;

            _frameCounter++;
            if (_frameCounter % _uiUpdateEveryNFrames != 0) return;

            final imageWidth = image.width.toDouble();
            final imageHeight = image.height.toDouble();
            if (imageWidth <= 0 || imageHeight <= 0) return;

            final left = Offset(
              (shoulders[0].dx / imageWidth).clamp(0.0, 1.0),
              (shoulders[0].dy / imageHeight).clamp(0.0, 1.0),
            );
            final right = Offset(
              (shoulders[1].dx / imageWidth).clamp(0.0, 1.0),
              (shoulders[1].dy / imageHeight).clamp(0.0, 1.0),
            );
            final shoulderWidthNorm = (left - right).distance;
            final nextFiltered = _filteredShoulderWidthNorm == 0
                ? shoulderWidthNorm
                : (_filteredShoulderWidthNorm * 0.8) +
                      (shoulderWidthNorm * 0.2);

            setState(() {
              _leftShoulderNorm = left;
              _rightShoulderNorm = right;
              _filteredShoulderWidthNorm = nextFiltered;
            });
          });
        })
        .catchError((e) {
          debugPrint('Camera Error: $e');
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _poseDetectorService.dispose();
    super.dispose();
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
              CameraPreview(_controller),
              CustomPaint(
                painter: ShoulderGuidePainter(
                  leftShoulderNorm: _leftShoulderNorm,
                  rightShoulderNorm: _rightShoulderNorm,
                  shoulderWidthNorm: _filteredShoulderWidthNorm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
