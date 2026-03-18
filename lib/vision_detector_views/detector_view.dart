//カメラ映像（リアルタイム）とギャラリー（静止画）の表示モードを切り替えるスイッチャー（切り替え器）

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'camera_view.dart';
import 'gallery_view.dart';

/*
liveFeed: カメラを使ってリアルタイムでポーズを検出するモード
gallery: スマホ内の写真を選択してポーズを検出するモード
*/
enum DetectorViewMode { liveFeed, gallery }

// どちらの画面を表示すべきかを判断し、必要なデータを各画面に橋渡しするようにするウィジェット
class DetectorView extends StatefulWidget {
  DetectorView({
    super.key,
    required this.title,
    required this.onImage,
    this.customPaint,
    this.text,
    this.initialDetectionMode = DetectorViewMode.liveFeed,
    this.initialCameraLensDirection = CameraLensDirection.back,
    this.onCameraFeedReady,
    this.onDetectorViewModeChanged,
    this.onCameraLensDirectionChanged,
  });

  final String title;
  final CustomPaint? customPaint;
  final String? text;
  final DetectorViewMode initialDetectionMode;
  final Function(InputImage inputImage) onImage;
  final Function()? onCameraFeedReady;
  final Function(DetectorViewMode mode)? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<DetectorView> createState() => _DetectorViewState();
}

class _DetectorViewState extends State<DetectorView> {
  late DetectorViewMode _mode;

  @override
  void initState() {
    _mode = widget.initialDetectionMode;
    super.initState();
  }

  // 画面の切り替えロジック
  @override
  Widget build(BuildContext context) {
    return _mode == DetectorViewMode.liveFeed
        ? CameraView(
            customPaint: widget.customPaint,
            onImage: widget.onImage,
            onCameraFeedReady: widget.onCameraFeedReady,
            onDetectorViewModeChanged: _onDetectorViewModeChanged,
            initialCameraLensDirection: widget.initialCameraLensDirection,
            onCameraLensDirectionChanged: widget.onCameraLensDirectionChanged,
          ) // ライブフィードならカメラビューを表示する
        : GalleryView(
            title: widget.title,
            text: widget.text,
            onImage: widget.onImage,
            onDetectorViewModeChanged: _onDetectorViewModeChanged,
          ); // そうでなければギャラリービューを表示する
  }

  /* onImage コールバックの橋渡し
PoseDetectorViewから渡された onImage（ポーズ解析を行う関数）を、そのまま CameraViewやGalleryViewに渡す
これにより、画像がカメラから来てもギャラリーから来ても、全く同じロジック（_processImage）で解析できるようになる
*/

  void _onDetectorViewModeChanged() {
    if (_mode == DetectorViewMode.liveFeed) {
      _mode = DetectorViewMode.gallery;
    } else {
      _mode = DetectorViewMode.liveFeed;
    }
    if (widget.onDetectorViewModeChanged != null) {
      widget.onDetectorViewModeChanged!(_mode);
    }
    setState(() {});
  }
}
