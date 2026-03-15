import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ARCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ARCameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;

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
          setState(() {
            _isInitialized = true;
          });

          // [Issue 1-2の伏線] 次のフェーズで、ここに以下のコードを追加します
          // _controller.startImageStream((image) => processImageForPoseDetection(image));
        })
        .catchError((e) {
          debugPrint("Camera Error: $e");
        });
  }

  @override
  void dispose() {
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
          child: CameraPreview(_controller),
        ),
      ),
    );
  }
}
