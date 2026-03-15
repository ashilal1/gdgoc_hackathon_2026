import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/ar_camera_screen.dart';

Future<void> main() async {
  // main関数内で非同期処理を呼び出すための設定
  WidgetsFlutterBinding.ensureInitialized();
  // ↑iOS/Androidのカメラハードウェア）」にアクセスする前にいるおまじない

  // デバイスで利用可能なカメラのリストを取得
  final cameras = await availableCameras();

  // 取得できているか確認
  print(cameras);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ARCameraScreen(cameras: cameras),
    ),
  );
}
