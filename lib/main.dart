import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// 元の画面は Bridge の中で使うので残しておきます
import 'screens/ar_camera_screen.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // カメラのリストを取得
  final cameras = await availableCameras();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
     
      home: ARCameraScreen(cameras: cameras),
    ),
  );
}