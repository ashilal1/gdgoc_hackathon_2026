import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'vision_detector_views/pose_detector_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }

  try {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    final user = userCredential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned null user.');
    }
    debugPrint('Signed in anonymously. uid=${user.uid}');
  } catch (e, st) {
    debugPrint('Anonymous sign-in failed: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }

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
