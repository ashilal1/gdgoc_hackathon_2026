import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'vision_detector_views/pose_detector_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final userCredential = await FirebaseAuth.instance.signInAnonymously();
  final uid = userCredential.user?.uid;
  debugPrint('Signed in anonymously. uid=$uid');

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
