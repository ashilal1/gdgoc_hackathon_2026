import 'package:flutter/material.dart';
import 'vision_detector_views/pose_detector_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PoseDetectorView(), // アプリ起動直後、ポーズ検出画面を表示する
    );
  }
}
