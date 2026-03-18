// 画像を受け取って AI に渡し、その結果を描画用に整形する

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'detector_view.dart';
import 'painters/pose_painter.dart';

class PoseDetectorView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  ); // ML Kitの姿勢検出（自分たちは骨格検出って言っているよ）エンジン本体
  bool _canProcess = true;
  bool _isBusy = false; // 前の画像の解析が終わっていないのに次の解析を始めないようにするためのフラグ
  CustomPaint? _customPaint; // 骨格検出の結果を描画するための情報が入る
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  @override
  void dispose() async {
    _canProcess = false; // ウィジェットが破棄された後に処理が走らないようにするためのフラグ
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Pose Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage, // 解析が必要な新しい画像が届いたときに実行する処理
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  // カメラやギャラリーから画像が届くたびに実行される非同期メソッド
  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final poses = await _poseDetector.processImage(
      inputImage,
    ); // AI が画像内のポーズ（関節の位置など）を検出する

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      ); // 解析結果（poses）を受け取ると、それを画面上の座標に正しく描画するためのPosePainterインスタンスを作成する
      _customPaint = CustomPaint(painter: painter);
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {}); // 作成した _customPaint（骨格の絵）がカメラ映像の上に重なって表示される
    }
  }
}
