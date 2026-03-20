import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as _logger;
import 'package:crypto/crypto.dart';
import 'vision_detector_views/pose_detector_view.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SignInDemo(),
    );
  }
}

class SignInDemo extends StatefulWidget {
  const SignInDemo({super.key});

  @override
  State<SignInDemo> createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: []);
  User? _user;
  bool _loading = false;
  String? _error;

  Future<void> signInWithGoogle() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // // キャッシュされているアカウントをクリアする
      // await _googleSignIn.signOut(); // テスト用

      // googleのアカウント選択画面を表示して、ユーザーに選択してもらう
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      // ログイン成功直後に取得できるuserを使う
      final user = userCredential.user;
      if (user == null) throw StateError('user is null');

      final rawEmail = (user.email ?? '').trim().toLowerCase();
      if (rawEmail.isEmpty) {
        throw StateError('Googleアカウントのemailが取得できませんでした。');
      }

      final emailHash = sha256.convert(utf8.encode(rawEmail)).toString();

      // 既存のユーザー情報をFirestoreから取得してみる
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();

      // 今回が初回ログイン（= baseShoulderWidthPx が登録されていない）かどうか判定
      final bool isFirstLogin =
          data == null || !(data.containsKey('baseShoulderWidthPx'));

      // final bool isFirstLogin = true; // とりあえず常に初回ログイン扱いにする（肩幅の登録は後で実装する予定）

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'emailHash': emailHash,
        'provider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PoseDetectorView(isFirstLogin: isFirstLogin),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Google Sign In')),
      body: Center(
        child: _user == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _loading ? null : signInWithGoogle,
                    child: Text(_loading ? '処理中...' : 'Sign in with Google'),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Signed in as ${_user!.displayName ?? 'No name'}'),
                  Text('Email: ${_user!.email ?? '-'}'),
                  if (_user!.photoURL != null) Image.network(_user!.photoURL!),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
      ),
    );
  }
}
