import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'screen_recognize_skelton.dart';

class ARCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ARCameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;

  // ★ 配線1：箱から出して、いつでも使えるように準備する
  final SkeletonRecognizer _recognizer = SkeletonRecognizer();
  List<Pose> _detectedPoses = []; // 見つけた骨格データをメモする場所

  @override
  void initState() {
    super.initState();
    // MVPやから、まずは一番目のカメラ（通常は背面カメラ）を決め打ちで初期化する
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high, // 画質は骨格検知のために高めに設定している
    ); // cameras[0]はスマホの背面カメラを指す
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;

          // ★ 配線2：カメラの映像（パラパラ漫画の1コマ）を、AIに渡し続ける
          _controller.startImageStream((image) async {
            final poses = await _recognizer.recognize(image, widget.cameras[0]);
            
            if (mounted && poses.isNotEmpty) {
              setState(() {
                _detectedPoses = poses; // AIが見つけた骨格をメモに上書きする
              });
              // 確認用：ターミナルに「33」とかの数字が出れば大成功！
              debugPrint('見つけた関節の数: ${poses.first.landmarks.length}');
            }
          });

          setState(() {
            _isInitialized = true;
          });
        })
        .catchError((e) {
          debugPrint("Camera Error: $e");
        });
  }

  @override
  void dispose() {
    // ★ 配線3：使い終わったらAIエンジンも片付ける
    _recognizer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中はローディングを表示
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // カメラ映像をフルスクリーンで表示
    // 被写体が縦に伸びて表示されてしまう理由は、CameraPreview を SizedBox.expand を使って画面全体に強制的に引き伸ばしているからだった
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          // カメラのアスペクト比に合わせて表示枠を決定する（縦画面の場合は 1 / aspectRatio）
          aspectRatio: 1 / _controller.value.aspectRatio,
          // ★ Stackを使ってカメラ映像の上にお絵かきキャンバスを重ねる
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1枚目（下）：いつものカメラ映像
              CameraPreview(_controller),
              
              // 2枚目（上）：AIが見つけた骨格の赤い点（お絵かき職人）
              if (_detectedPoses.isNotEmpty)
                CustomPaint(
                  painter: PosePainter(
                    _detectedPoses,
                    _controller.value.previewSize!, // カメラの解像度を渡す
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}